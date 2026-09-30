# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teaching audit attribution" do
  fab!(:admin)
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:model, :fake_model)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:topic) { Fabricate(:topic, category: course.category, user: teacher) }
  fab!(:student_post) { Fabricate(:post, topic: topic, user: student) }

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.educustomize_model_ids = model.id.to_s
    course.student_group.add(student)
    @agent =
      Fabricate(:ai_agent, default_llm_id: model.id, allowed_group_ids: [course.teacher_group_id])
    course.agent_links.create!(ai_agent: @agent)
    @workflow = DiscourseEducustomize::WorkflowTemplate.install!(admin)
    @policy =
      DiscourseEducustomize::TopicPolicy.create!(
        topic: topic,
        course: course,
        ai_agent: @agent,
        reviewer: teacher,
        workflow_id: @workflow.id,
      )
  end

  after { AiAgent.agent_cache.flush! }

  def create_run
    DiscourseEducustomize::Run.create!(
      topic_policy: @policy,
      post: student_post,
      actor: teacher,
      request_key: SecureRandom.uuid,
      configuration_digest: DiscourseEducustomize::AiConfiguration.digest(@policy),
    )
  end

  def execute(run)
    DiscourseWorkflows::Executor.new(
      @workflow,
      "manual",
      { "run_id" => run.id },
      DiscourseWorkflows::Executor::ExecutionOptions.new(user: teacher),
    ).run
    expect(run.reload.execution.status).to eq("waiting"), run.execution.execution_data.data.inspect
  end

  it "attributes a normal teaching call to the run, course, agent and source post" do
    run = create_run
    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["Teaching reply."],
    ) do |_, _, prompts, options|
      execute(run)
      expect(prompts.first.topic_id).to eq(topic.id)
      expect(prompts.first.post_id).to eq(student_post.id)
      expect(options.first[:feature_context]).to include(
        "educustomize_run_id" => run.id,
        "educustomize_course_id" => course.id,
        "educustomize_agent_id" => @agent.id,
      )
    end
  end

  it "preserves run attribution across native Delegate calls" do
    child =
      Fabricate(:ai_agent, default_llm_id: model.id, allowed_group_ids: [course.teacher_group_id])
    course.agent_links.create!(ai_agent: child)
    @agent.update!(subagent_ids: [child.id])
    run = create_run
    call =
      DiscourseAi::Completions::ToolCall.new(
        id: "delegate-audit",
        name: "spawn_agent",
        parameters: {
          agent_id: child.id,
          prompt: "Analyze this response.",
        },
      )
    DiscourseAi::Completions::Llm.with_prepared_responses(
      [call, "Delegate analysis.", "Dais reply."],
    ) do |_, _, prompts, options|
      execute(run)
      expect(options.size).to eq(3)
      expect(options.map { |option| option[:feature_context]["educustomize_run_id"] }).to eq(
        [run.id] * 3,
      )
      expect(options.map { |option| option[:feature_context]["educustomize_agent_id"] }).to eq(
        [@agent.id, child.id, @agent.id],
      )
      expect(options[1][:feature_context]["subagent_parent_agent_id"]).to eq(@agent.id)
      expect(prompts.map(&:topic_id)).to eq([topic.id] * 3)
      expect(prompts.map(&:post_id)).to eq([student_post.id] * 3)
    end
  end

  it "executes the native random picker and continues to a reviewable answer" do
    SiteSetting.educustomize_tool_names = "Time|RandomPicker"
    @agent.update!(tools: ["RandomPicker"])
    run = create_run
    call =
      DiscourseAi::Completions::ToolCall.new(
        id: "random-choice",
        name: "random_picker",
        parameters: {
          options: ["red"],
        },
      )
    DiscourseAi::Completions::Llm.with_prepared_responses(
      [call, "The choice is red."],
    ) do |_, _, prompts|
      execute(run)
      result = prompts.last.messages.find { |message| message[:type] == :tool }
      expect(JSON.parse(result[:content])).to include("result" => "red")
      expect(run.draft).to eq("The choice is red.")
    end
  end

  it "retains teaching metadata on native context compression calls" do
    model.update!(max_prompt_tokens: 1000)
    run = create_run
    messages =
      12.times.map do |index|
        {
          type: index.even? ? :user : :model,
          content: "Historical teaching discussion #{index}. " * 40,
        }
      end
    messages << { type: :user, content: "Summarize the learning objective." }
    context =
      DiscourseAi::Agents::BotContext.new(
        user: teacher,
        guardian: teacher.guardian,
        messages: messages,
        feature_name: "workflow",
        feature_context: {
          "educustomize_run_id" => run.id,
        },
      )
    bot = DiscourseAi::Agents::Bot.as(teacher, agent: @agent.class_instance.new, model: model)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["Concise history.", "Teaching answer."],
    ) do |_, _, prompts, options|
      bot.reply(context)
      compression_index = options.index { |option| option[:feature_name] == "context_compression" }
      expect(compression_index).to be_present
      expect(options[compression_index][:feature_context]["educustomize_run_id"]).to eq(run.id)
      expect(prompts[compression_index].topic_id).to eq(topic.id)
      expect(prompts[compression_index].post_id).to eq(student_post.id)
    end
  end

  it "keeps normal forum calls free of teaching attribution" do
    context =
      DiscourseAi::Agents::BotContext.new(
        user: teacher,
        guardian: teacher.guardian,
        messages: [{ type: :user, content: "Ordinary forum question." }],
      )
    bot = DiscourseAi::Agents::Bot.as(teacher, agent: @agent.class_instance.new, model: model)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["Ordinary answer."],
    ) do |_, _, _, options|
      bot.reply(context)
      expect(options.first[:feature_context].keys.grep(/educustomize/)).to be_empty
    end
  end

  it "persists attribution, native token counts and estimated cost in the audit log" do
    provider_model = Fabricate(:llm_model)
    SiteSetting.educustomize_model_ids = provider_model.id.to_s
    @agent.update!(default_llm_id: provider_model.id)
    run = create_run
    chunks = [
      { choices: [{ delta: { content: "Audited teaching answer." }, index: 0 }] },
      {
        choices: [{ delta: {}, finish_reason: "stop", index: 0 }],
        usage: {
          prompt_tokens: 20,
          completion_tokens: 10,
          total_tokens: 30,
        },
      },
    ]
    stream = chunks.map { |chunk| "data: #{chunk.to_json}\n\n" }.join + "data: [DONE]\n\n"
    stub_request(:post, provider_model.url).to_return(
      status: 200,
      body: stream,
      headers: {
        "Content-Type" => "text/event-stream",
      },
    )
    execute(run)
    audit = AiApiAuditLog.order(:id).last
    expect(audit).to have_attributes(
      topic_id: topic.id,
      post_id: student_post.id,
      request_tokens: 20,
      response_tokens: 10,
    )
    expect(audit.feature_context).to include(
      "educustomize_run_id" => run.id,
      "educustomize_course_id" => course.id,
      "educustomize_agent_id" => @agent.id,
    )
    expect(audit.estimated_cost).to be > 0
  end

  [401, 429, :timeout, :empty].each do |failure|
    it "keeps a #{failure} provider failure unpublished and marks the execution failed" do
      provider_model = Fabricate(:llm_model)
      SiteSetting.educustomize_model_ids = provider_model.id.to_s
      @agent.update!(default_llm_id: provider_model.id)
      run = create_run
      request = stub_request(:post, provider_model.url)
      if failure == :timeout
        request.to_timeout
      elsif failure == :empty
        request.to_return(
          status: 200,
          body: "data: [DONE]\n\n",
          headers: {
            "Content-Type" => "text/event-stream",
          },
        )
      else
        request.to_return(
          status: failure,
          body: { error: { message: "Acceptance failure fixture" } }.to_json,
        )
      end
      expect do
        DiscourseWorkflows::Executor.new(
          @workflow,
          "manual",
          { "run_id" => run.id },
          DiscourseWorkflows::Executor::ExecutionOptions.new(user: teacher),
        ).run
      end.not_to change { topic.posts.count }
      expect(run.reload.execution.status).to eq("error")
      expect(run.published_post_id).to be_nil
      expect(run.draft).to be_blank
    end
  end

  it "leaves other OpenAI-compatible models and endpoints on the native adapter" do
    [
      { name: "gpt-4.1", url: "https://api.openai.com/v1/chat/completions" },
      { name: "deepseek-flash", url: "https://example.com/chat/completions" },
      { name: "other-model", url: "https://api.deepseek.com/chat/completions" },
    ].each do |attributes|
      provider_model = Fabricate.build(:llm_model, provider: "open_ai", **attributes)
      expect(DiscourseAi::Completions::Endpoints::Base.endpoint_for(provider_model)).to eq(
        DiscourseAi::Completions::Endpoints::OpenAi,
      )
      expect(DiscourseAi::Completions::Dialects::Dialect.dialect_for(provider_model)).to eq(
        DiscourseAi::Completions::Dialects::ChatGpt,
      )
    end
  end

  it "round-trips DeepSeek thinking and grouped tool calls without publishing reasoning" do
    provider_model =
      Fabricate(
        :llm_model,
        name: "deepseek-flash",
        provider: "open_ai",
        url: "https://api.deepseek.com/chat/completions",
        provider_params: {
          "reasoning_effort" => "low",
        },
      )
    SiteSetting.educustomize_model_ids = provider_model.id.to_s
    SiteSetting.educustomize_tool_names = "Time|RandomPicker"
    @agent.update!(default_llm_id: provider_model.id, tools: %w[Time RandomPicker])
    run = create_run
    deltas = [
      { reasoning_content: "Check the authorized tools." },
      {
        tool_calls: [
          {
            index: 0,
            id: "time-one",
            type: "function",
            function: {
              name: "time",
              arguments: { timezone: "UTC" }.to_json,
            },
          },
        ],
      },
      {
        tool_calls: [
          {
            index: 1,
            id: "random-two",
            type: "function",
            function: {
              name: "random_picker",
              arguments: { options: ["red"] }.to_json,
            },
          },
        ],
      },
    ]
    chunks = deltas.map { |delta| { id: "thinking-batch", choices: [{ index: 0, delta: delta }] } }
    chunks << {
      id: "thinking-batch",
      choices: [{ index: 0, delta: {}, finish_reason: "tool_calls" }],
      usage: {
        prompt_tokens: 20,
        completion_tokens: 10,
        prompt_cache_hit_tokens: 5,
      },
    }
    first = chunks.map { |chunk| "data: #{chunk.to_json}\n\n" }.join + "data: [DONE]\n\n"
    final =
      "data: #{{ id: "answer", choices: [{ delta: { content: "Selected red." }, finish_reason: "stop" }], usage: { prompt_tokens: 30, completion_tokens: 5 } }.to_json}\n\ndata: [DONE]\n\n"
    payloads = []
    responses = [first, final]
    stub_request(:post, provider_model.url).to_return do |request|
      payloads << JSON.parse(request.body)
      { status: 200, body: responses.shift, headers: { "Content-Type" => "text/event-stream" } }
    end
    execute(run)
    expect(run.draft).to eq("Selected red.")
    expect(payloads.length).to eq(2)
    expect(payloads.first).to include("reasoning_effort" => "low")
    expect(payloads.first).not_to have_key("chat_template_kwargs")
    assistant = payloads.last["messages"].find { |message| message["tool_calls"] }
    expect(assistant["reasoning_content"]).to eq("Check the authorized tools.")
    expect(assistant["tool_calls"].map { |call| call["id"] }).to eq(%w[time-one random-two])
    expect(payloads.last["messages"].count { |message| message["role"] == "tool" }).to eq(2)
    audits = AiApiAuditLog.where(llm_id: provider_model.id).order(:id)
    expect(audits.first).to have_attributes(
      request_tokens: 15,
      cache_read_tokens: 5,
      response_tokens: 10,
    )
    expect(audits.map { |audit| audit.feature_context["educustomize_run_id"] }).to eq(
      [run.id, run.id],
    )
  end
end
