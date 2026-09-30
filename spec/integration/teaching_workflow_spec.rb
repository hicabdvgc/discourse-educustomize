# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Course teaching workflow" do
  fab!(:admin)
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:model, :fake_model)
  after { AiAgent.agent_cache.flush! }

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.educustomize_model_ids = model.id.to_s
    @course =
      DiscourseEducustomize::CreateCourse.call(
        guardian: admin.guardian,
        params: {
          name: "Workflow course",
          color: "0088CC",
        },
      )[
        :course
      ]
    @course.teacher_group.add(teacher)
    @course.student_group.add(student)
    @agent =
      Fabricate(
        :ai_agent,
        name: "Course helper",
        default_llm_id: model.id,
        allowed_group_ids: [@course.teacher_group_id],
      )
    @course.agent_links.create!(ai_agent: @agent)
    @topic = Fabricate(:topic, category: @course.category, user: teacher)
    Fabricate(
      :post,
      topic: @topic,
      user: teacher,
      raw: "Historical teacher context that should stay isolated.",
    )
    @post =
      Fabricate(
        :post,
        topic: @topic,
        user: student,
        raw: "Current student response about the teaching question.",
      )
    @workflow = DiscourseEducustomize::WorkflowTemplate.install!(admin)
    @policy =
      DiscourseEducustomize::TopicPolicy.create!(
        topic: @topic,
        course: @course,
        ai_agent: @agent,
        reviewer: teacher,
        workflow_id: @workflow.id,
      )
  end

  def generate(responses: ["This is the simulated teaching response."])
    run =
      DiscourseEducustomize::Run.create!(
        topic_policy: @policy,
        post: @post,
        actor: teacher,
        request_key: SecureRandom.uuid,
        configuration_digest: DiscourseEducustomize::AiConfiguration.digest(@policy),
      )
    DiscourseAi::Completions::Llm.with_prepared_responses(responses) do |_, _, prompts|
      @execution =
        DiscourseWorkflows::Executor.new(
          @workflow,
          "manual",
          { "run_id" => run.id },
          DiscourseWorkflows::Executor::ExecutionOptions.new(user: teacher),
        ).run
      @prompts = prompts
    end
    run.reload
    run
  end

  it "saves a native workflow and pauses for review with isolated discussion input" do
    expect(DiscourseEducustomize::WorkflowTemplate.valid?(@workflow.reload)).to eq(true)
    run = generate
    expect(@execution.reload.status).to eq("waiting"), @execution.execution_data.data.inspect
    expect(run.draft).to include("simulated teaching")
    expect(@prompts.first.to_json).to include("Current student response")
    expect(@prompts.first.to_json).not_to include("Historical teacher context")
    expect(run.published_post_id).to be_nil
  end

  it "includes the current Topic discussion when memory is enabled" do
    @policy.update!(memory: true)
    generate
    expect(@prompts.first.to_json).to include(
      "Historical teacher context",
      "Current student response",
    )
  end

  it "keeps the selected question last when later replies already exist" do
    @policy.update!(memory: true)
    Fabricate(
      :post,
      topic: @policy.topic,
      raw: "A later answer that must remain discussion context.",
    )
    generate
    expect(@prompts.first.messages.last[:content]).to include("Current student response")
    expect(@prompts.first.messages.last[:content]).not_to include("A later answer")
    expect(@prompts.first.to_json).to include("A later answer")
  end

  it "allows native compression of a long course discussion before generation" do
    @policy.update!(memory: true)
    model.update!(max_prompt_tokens: 1000)
    8.times do |index|
      Fabricate(
        :post,
        topic: @topic,
        user: teacher,
        raw: "Discussion evidence #{index}: explain language ambiguity. " * 40,
      )
    end
    run =
      generate(
        responses: ["Earlier posts discuss language ambiguity.", "A concise teaching answer."],
      )
    expect(run.draft).to eq("A concise teaching answer.")
    expect(@prompts.length).to eq(2)
    expect(@prompts.first.to_json).to include("compress the conversation")
    expect(@prompts.last.messages.map { |message| message[:content] }.join).to include(
      "<compressed_context>",
      "Current student response",
    )
    expect(@prompts.map(&:topic_id)).to eq([@topic.id, @topic.id])
  end

  it "publishes automatically through the native post node when review is disabled" do
    @policy.update!(require_review: false)
    run = generate
    expect(@execution.reload.status).to eq("success"), @execution.attributes.inspect
    expect(Post.find(run.published_post_id).raw).to include("simulated teaching")
  end
  it "executes two native Delegates with saved Skills and returns both answers to the Dais for review" do
    delegates =
      %w[Tutor Critic].map do |name|
        saved =
          DiscourseEducustomize::SaveAgent.call(
            guardian: teacher.guardian,
            params: {
              course_id: @course.id,
              name: "Skills #{name}",
              description: "#{name} teaching role",
              system_prompt: "#{name} original prompt.",
              skills: [
                {
                  name: "#{name} skill",
                  description: "",
                  instructions: "#{name} unique instructions.",
                },
              ],
              default_llm_id: model.id,
              enabled: true,
            },
          )
        expect(saved).to run_successfully
        saved.agent
      end
    saved_dais =
      DiscourseEducustomize::SaveAgent.call(
        guardian: teacher.guardian,
        params: {
          course_id: @course.id,
          agent_id: @agent.id,
          name: @agent.name,
          description: @agent.description,
          system_prompt: "Dais original prompt.",
          skills: [
            {
              name: "Synthesis",
              description: "",
              instructions: "Combine the independent analyses.",
            },
          ],
          default_llm_id: model.id,
          enabled: true,
          subagent_ids: delegates.map(&:id),
        },
      )
    expect(saved_dais).to run_successfully
    calls =
      delegates.map do |delegate|
        DiscourseAi::Completions::ToolCall.new(
          id: "delegate-#{delegate.id}",
          name: "spawn_agent",
          parameters: {
            agent_id: delegate.id,
            prompt: "Analyze the current student response.",
          },
        )
      end
    run =
      generate(
        responses: [
          calls.first,
          "Tutor analysis.",
          calls.last,
          "Critic analysis.",
          "Dais synthesis.",
        ],
      )
    expect(@execution.reload.status).to eq("waiting"), @execution.execution_data.data.inspect
    expect(@prompts.size).to eq(5)
    expect(@prompts.flat_map { |prompt| prompt.tools.map(&:name) }.uniq).to contain_exactly(
      "spawn_agent",
    )
    expect(@prompts.first.to_json).to include(
      "Dais original prompt.",
      "Combine the independent analyses.",
    )
    expect(@prompts[1].to_json).to include(
      "Analyze the current student response.",
      "Tutor original prompt.",
      "Tutor unique instructions.",
    )
    expect(@prompts[3].to_json).to include("Critic original prompt.", "Critic unique instructions.")
    expect(@prompts.last.to_json).to include("Tutor analysis.", "Critic analysis.")
    expect(@prompts.map(&:to_json).join).not_to include("Historical teacher context")
    expect(run.draft).to include("Dais synthesis.")
    expect(run.published_post_id).to be_nil
  end

  it "includes another student's replies only when memory is enabled" do
    another_student = Fabricate(:user)
    @course.student_group.add(another_student)
    other_post =
      Fabricate(
        :post,
        topic: @topic,
        user: another_student,
        raw: "A second student's independent historical answer.",
      )
    generate
    expect(@prompts.first.to_json).not_to include(other_post.raw)
    @policy.update!(memory: true)
    generate
    expect(@prompts.first.to_json).to include(other_post.raw)
  end

  it "refuses generation when a Delegate acquires an unsafe discussion-reading tool" do
    child =
      Fabricate(
        :ai_agent,
        default_llm_id: model.id,
        allowed_group_ids: [@course.teacher_group_id],
        tools: ["Search"],
      )
    @course.agent_links.create!(ai_agent: child)
    @agent.update!(subagent_ids: [child.id])
    generate
    expect(@execution.reload.status).to eq("error")
    expect(@prompts).to be_empty
  end

  it "refuses generation when the parent acquires an unsafe discussion-reading tool" do
    @agent.update!(tools: ["Read"])
    generate
    expect(@execution.reload.status).to eq("error")
    expect(@prompts).to be_empty
  end

  it "handles automatic student posts once and ignores teachers and system replies" do
    @policy.update!(auto_reply: true, require_review: false)
    system_post = Fabricate(:post, topic: @topic, user: Discourse.system_user)
    teacher_post = Fabricate(:post, topic: @topic, user: teacher)
    @course.student_group.add(teacher)
    events = [@post, @post, teacher_post, system_post]
    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["One automatic student response."],
    ) do |_, _, prompts|
      events.each do |post|
        trigger_data =
          DiscourseWorkflows::Nodes::PostCreated::V1.new(post).output.deep_stringify_keys
        execution =
          DiscourseWorkflows::Executor.new(
            @workflow,
            "event",
            trigger_data,
            DiscourseWorkflows::Executor::ExecutionOptions.new(user: post.user),
          ).run
        expect(execution.reload.status).to eq("success"), execution.execution_data.data.inspect
      end
      expect(prompts.size).to eq(1)
    end
    runs = DiscourseEducustomize::Run.where(topic_policy: @policy)
    expect(runs.count).to eq(1)
    expect(Post.find(runs.first.published_post_id).raw).to eq("One automatic student response.")
  end

  it "keeps an unconfigured Topic outside the automatic generation path" do
    trigger_data = DiscourseWorkflows::Nodes::PostCreated::V1.new(@post).output.deep_stringify_keys
    DiscourseAi::Completions::Llm.with_prepared_responses([]) do |_, _, prompts|
      execution = DiscourseWorkflows::Executor.new(@workflow, "event", trigger_data).run
      expect(execution.reload.status).to eq("success")
      expect(prompts).to be_empty
    end
    expect(DiscourseEducustomize::Run.count).to eq(0)
  end
  it "dispatches a real post-created event through the published native workflow job" do
    @policy.update!(auto_reply: true)
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear
    DiscourseEvent.trigger(:post_created, @post)
    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |job|
        job["args"].first["workflow_id"] == @workflow.id
      end
    expect(jobs.size).to eq(1)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["Event-driven teaching draft."],
    ) do |_, _, prompts|
      Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(
        jobs.first["args"].first.deep_symbolize_keys,
      )
      expect(prompts.size).to eq(1)
    end
    run = DiscourseEducustomize::Run.find_by!(topic_policy: @policy, post: @post)
    expect(run.execution.status).to eq("waiting")
    expect(run.draft).to eq("Event-driven teaching draft.")
  end
end
