# frozen_string_literal: true

RSpec.describe Jobs::EducustomizeRun do
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
    agent =
      Fabricate(:ai_agent, default_llm_id: model.id, allowed_group_ids: [course.teacher_group_id])
    course.agent_links.create!(ai_agent: agent)
    workflow = DiscourseEducustomize::WorkflowTemplate.install!(admin)
    @policy =
      DiscourseEducustomize::TopicPolicy.create!(
        topic:,
        course:,
        ai_agent: agent,
        reviewer: teacher,
        workflow_id: workflow.id,
      )
    @run =
      DiscourseEducustomize::Run.create!(
        topic_policy: @policy,
        post: student_post,
        actor: teacher,
        request_key: SecureRandom.uuid,
        configuration_digest: DiscourseEducustomize::AiConfiguration.digest(@policy),
      )
    @execution =
      DiscourseWorkflows::Execution.create_pending_manual!(
        workflow:,
        trigger_node_id: "manual",
        trigger_data: {
          "run_id" => @run.id,
        },
      )
    @run.update!(execution: @execution)
  end

  after { AiAgent.agent_cache.flush! }

  describe "#execute" do
    it "finishes revoked queued work as a native error without generating or retrying" do
      course.teacher_group.remove(teacher)
      channel = DiscourseWorkflows::ExecutionProgressPublisher.execution_channel(@execution.id)
      DiscourseAi::Completions::Llm.with_prepared_responses([]) do |_, _, prompts|
        messages =
          MessageBus.track_publish(channel) do
            2.times { described_class.new.execute(run_id: @run.id) }
          end
        expect(prompts).to be_empty
        expect(messages.size).to eq(1)
        expect(messages.first.data[:execution][:status]).to eq("error")
      end
      expect(@execution.reload).to have_attributes(status: "error", run_time_ms: 0)
      expect(@execution.finished_at).to be_present
      expect(@execution.error).to be_present
      expect(@run.reload.published_post_id).to eq(nil)
    end

    it "finishes queued work invalidated by a policy change" do
      @policy.update!(revision: @policy.revision + 1)
      described_class.new.execute(run_id: @run.id)
      expect(@execution.reload).to be_error
      expect(@execution.finished_at).to be_present
    end

    it "preserves failures unrelated to an authorization revocation" do
      @policy.delete
      expect { described_class.new.execute(run_id: @run.id) }.to raise_error(NoMethodError)
      expect(@execution.reload).to be_pending
      expect(@execution.finished_at).to eq(nil)
    end
  end
end
