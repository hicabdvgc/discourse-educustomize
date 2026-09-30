# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::SaveTopicPolicy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:course) { Fabricate(:educustomize_course, created_by: acting_user) }
    fab!(:topic) { Fabricate(:topic, category: course.category) }
    let(:params) { { topic_id: topic.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      SiteSetting.educustomize_enabled = true
      SiteSetting.enable_category_group_moderation = true
    end

    context "when the contract is invalid" do
      let(:params) { {} }
      it { is_expected.to fail_a_contract }
    end

    context "when the topic is missing" do
      let(:params) { { topic_id: -1 } }
      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the topic is outside a course" do
      fab!(:topic)
      it { is_expected.to fail_to_find_a_model(:course) }
    end

    context "when the teacher assignment is revoked" do
      before { course.teacher_group.remove(acting_user) }
      it { is_expected.to fail_a_policy(:course_teacher) }
    end

    context "when the selected reviewer is a student" do
      fab!(:student, :user)
      before { course.student_group.add(student) }
      let(:params) { super().merge(reviewer_id: student.id) }
      it { is_expected.to fail_a_policy(:references_authorized) }
    end

    context "when the agent belongs to another course" do
      fab!(:foreign_link, :educustomize_agent_link)
      let(:params) { super().merge(ai_agent_id: foreign_link.ai_agent_id) }
      it { is_expected.to fail_a_policy(:references_authorized) }
    end

    context "when the workflow is outside the allowlist" do
      let(:params) { super().merge(workflow_id: 12_345) }
      it { is_expected.to fail_a_policy(:references_authorized) }
    end

    context "when the Topic has no binding yet" do
      it "persists the selected defaults without requiring a model" do
        expect(result).to run_successfully
        expect(result.topic_policy).to have_attributes(
          topic_id: topic.id,
          course_id: course.id,
          reviewer_id: acting_user.id,
          auto_reply: false,
          memory: false,
          require_review: true,
          ai_agent_id: nil,
        )
      end
    end

    context "when a course assistant is selected" do
      fab!(:delegate_link) { Fabricate(:educustomize_agent_link, course:) }
      let(:params) do
        super().merge(
          ai_agent_id: delegate_link.ai_agent_id,
          auto_reply: true,
          memory: true,
          require_review: false,
        )
      end
      it "stores the policy for the whole Topic" do
        expect(result).to run_successfully
        expect(result.topic_policy).to have_attributes(
          ai_agent_id: delegate_link.ai_agent_id,
          auto_reply: true,
          memory: true,
          require_review: false,
        )
        expect(DiscourseEducustomize::TopicPolicy.where(topic:).count).to eq(1)
      end
    end
  end
end
