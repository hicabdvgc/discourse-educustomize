# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::RunsController do
  fab!(:admin)
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:model, :fake_model)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:topic) { Fabricate(:topic, category: course.category, user: teacher) }
  fab!(:opening_post) { Fabricate(:post, topic:, user: teacher) }
  fab!(:student_post) { Fabricate(:post, topic:, user: student) }

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
        topic:,
        course:,
        ai_agent: @agent,
        reviewer: teacher,
        workflow_id: @workflow.id,
      )
  end

  after { AiAgent.agent_cache.flush! }

  def request_generation(key: SecureRandom.uuid)
    post "/educustomize/topics/#{topic.id}/runs.json",
         params: {
           post_id: student_post.id,
           request_key: key,
         }
    expect(response.status).to eq(201), response.body
    DiscourseEducustomize::Run.find(response.parsed_body["run"]["id"])
  end

  def generate_draft
    run = request_generation
    DiscourseAi::Completions::Llm.with_prepared_responses(["Initial simulated teaching draft."]) do
      Jobs::EducustomizeRun.new.execute(run_id: run.id)
    end
    expect(run.reload.execution.status).to eq("waiting")
    run
  end

  def decide(run, decision:, draft: "Teacher edited teaching response.")
    put "/educustomize/topics/#{topic.id}/runs/#{run.id}.json", params: { decision:, draft: }
  end

  describe "#create" do
    before { sign_in(teacher) }

    it "queues native execution and deduplicates both HTTP retries and job deliveries" do
      key = SecureRandom.uuid
      run = request_generation(key:)
      expect(Jobs::EducustomizeRun.jobs.pluck("args").flatten.pluck("run_id")).to include(run.id)
      expect { request_generation(key:) }.not_to change(DiscourseEducustomize::Run, :count)
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Only one teaching draft."],
      ) do |_, _, prompts|
        2.times { Jobs::EducustomizeRun.new.execute(run_id: run.id) }
        expect(prompts.size).to eq(1)
      end
      expect(run.reload.execution.status).to eq("waiting")
    end

    it "rejects a post from another course" do
      other_post = Fabricate(:post)
      post "/educustomize/topics/#{topic.id}/runs.json",
           params: {
             post_id: other_post.id,
             request_key: SecureRandom.uuid,
           }
      expect(response.status).to eq(403)
      expect(DiscourseEducustomize::Run.count).to eq(0)
    end
  end

  describe "#update" do
    before { sign_in(teacher) }

    it "publishes the edited draft once through native approval and post nodes" do
      run = generate_draft
      expect { decide(run, decision: "approve") }.to change { topic.posts.count }.by(1)
      expect(response.status).to eq(200), response.body
      expect(Post.find(run.reload.published_post_id).raw).to eq("Teacher edited teaching response.")
      expect(response.parsed_body["run"]).to include(
        "outcome" => "published",
        "draft" => "Teacher edited teaching response.",
      )
      expect { decide(run, decision: "approve") }.not_to change { topic.posts.count }
      expect(response.status).to eq(200)
    end

    it "closes the consumed native review modal while leaving unrelated modals untouched" do
      run = generate_draft
      channel = DiscourseWorkflows::Nodes::Modal::V1.user_channel(teacher.id)
      unrelated_id = "unrelated-review-notification"
      MessageBus.publish(
        channel,
        {
          type: "show_modal",
          modal_id: unrelated_id,
          buttons: [{ "action_id" => "different-signed-action" }],
        },
        user_ids: [teacher.id],
      )
      messages = MessageBus.track_publish(channel) { decide(run, decision: "approve") }
      expect(response.status).to eq(200)
      payloads = messages.map { |message| message.data.with_indifferent_access }
      shown_review = payloads.find { |payload| payload[:type] == "show_modal" }
      expect(shown_review).to be_present
      closed_ids = payloads.select { |payload| payload[:type] == "close_modal" }.pluck(:modal_id)
      expect(closed_ids).to eq([shown_review[:modal_id]])
      expect(closed_ids).not_to include(unrelated_id)
    end

    it "finishes a rejected draft without publishing" do
      run = generate_draft
      expect { decide(run, decision: "reject") }.not_to change { topic.posts.count }
      expect(response.status).to eq(200), response.body
      expect(run.reload.execution.status).to eq("success")
      expect(response.parsed_body["run"]["outcome"]).to eq("rejected")
      expect(run.published_post_id).to eq(nil)
    end

    it "invalidates the old approval when regeneration is requested" do
      run = generate_draft
      decide(run, decision: "regenerate")
      expect(response.status).to eq(204)
      expect(run.reload).to be_superseded
      decide(run, decision: "approve")
      expect(response.status).to eq(403)
      replacement = generate_draft
      expect(replacement.id).not_to eq(run.id)
      expect(replacement.execution.status).to eq("waiting")
    end

    it "rejects review after a course teacher assignment is revoked" do
      run = generate_draft
      course.teacher_group.remove(teacher)
      decide(run, decision: "approve")
      expect(response.status).to eq(403)
      expect(run.reload.published_post_id).to eq(nil)
    end

    it "rejects review after the Topic moves to another category" do
      run = generate_draft
      topic.update!(category: Fabricate(:category))
      decide(run, decision: "approve")
      expect(response.status).to eq(403)
      expect(run.reload.published_post_id).to eq(nil)
    end

    it "rejects a stale draft after policy revision changes" do
      run = generate_draft
      @policy.update!(revision: @policy.revision + 1)
      decide(run, decision: "approve")
      expect(response.status).to eq(403)
      expect(run.reload.published_post_id).to eq(nil)
    end

    it "rejects another course teacher who is not the appointed reviewer" do
      run = generate_draft
      other_teacher = Fabricate(:user)
      course.teacher_group.add(other_teacher)
      sign_in(other_teacher)
      decide(run, decision: "approve")
      expect(response.status).to eq(403)
      expect(run.reload.published_post_id).to eq(nil)
    end
  end
end
