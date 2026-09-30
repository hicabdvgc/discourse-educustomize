# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::RunsController do
  fab!(:admin)
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:model, :fake_model)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:question) { Fabricate(:topic_with_op, category: course.category, user: student) }

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.educustomize_model_ids = model.id.to_s
    course.student_group.add(student)
    question.first_post.update!(user: student)
    agent =
      Fabricate(:ai_agent, default_llm_id: model.id, allowed_group_ids: [course.teacher_group_id])
    course.agent_links.create!(ai_agent: agent)
    workflow = DiscourseEducustomize::WorkflowTemplate.install!(admin)
    DiscourseEducustomize::TopicPolicy.create!(
      topic: question,
      course: course,
      ai_agent: agent,
      reviewer: teacher,
      workflow_id: workflow.id,
    )
  end

  after { AiAgent.agent_cache.flush! }

  describe "#create" do
    before { sign_in(teacher) }

    it "generates a reviewable answer to a student's opening question with the fake model" do
      post "/educustomize/topics/#{question.id}/runs.json",
           params: {
             post_id: question.first_post.id,
             request_key: SecureRandom.uuid,
           }
      expect(response.status).to eq(201), response.body
      run = DiscourseEducustomize::Run.find(response.parsed_body["run"]["id"])
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Consider the evidence in your question."],
      ) { Jobs::EducustomizeRun.new.execute(run_id: run.id) }
      expect(run.reload.execution.status).to eq("waiting")
      expect(run.draft).to eq("Consider the evidence in your question.")
    end

    it "rejects system event posts" do
      event = Fabricate(:post, topic: question, post_type: Post.types[:small_action])
      expect do
        post "/educustomize/topics/#{question.id}/runs.json",
             params: {
               post_id: event.id,
               request_key: SecureRandom.uuid,
             }
      end.not_to change(DiscourseEducustomize::Run, :count)
      expect(response.status).to eq(403)
    end
  end
end
