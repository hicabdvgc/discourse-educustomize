# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::SaveAgent do
  describe described_class::Contract, type: :model do
    it do
      is_expected.to validate_numericality_of(:temperature)
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(2)
        .allow_nil
    end
    it do
      is_expected.to validate_numericality_of(:top_p)
        .is_greater_than(0)
        .is_less_than_or_equal_to(1)
        .allow_nil
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:course) { Fabricate(:educustomize_course, created_by: acting_user) }
    let(:params) do
      {
        course_id: course.id,
        name: "Sampling assistant",
        description: "Teaching",
        system_prompt: "Ask for evidence.",
        temperature: 0.7,
        top_p: 0.9,
      }
    end
    let(:dependencies) { { guardian: acting_user.guardian } }
    before { SiteSetting.educustomize_enabled = true }

    context "when sampling parameters are outside the supported range" do
      let(:params) { super().merge(top_p: 0) }
      it { is_expected.to fail_a_contract }
    end

    context "when the teacher selects sampling parameters" do
      it "persists both native model sampling values" do
        expect(result).to run_successfully
        expect(result.agent.reload).to have_attributes(temperature: 0.7, top_p: 0.9)
      end
    end

    context "when the teacher clears sampling overrides" do
      fab!(:link) do
        Fabricate(
          :educustomize_agent_link,
          course: course,
          ai_agent: Fabricate(:ai_agent, temperature: 0.7, top_p: 0.9),
        )
      end
      let(:params) { super().merge(agent_id: link.ai_agent_id, temperature: nil, top_p: nil) }
      it "restores native model defaults" do
        expect(result).to run_successfully
        expect(result.agent.reload).to have_attributes(temperature: nil, top_p: nil)
      end
    end
  end
end
