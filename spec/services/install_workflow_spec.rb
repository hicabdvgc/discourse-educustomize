# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::InstallWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:acting_user, :admin)
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      SiteSetting.educustomize_enabled = true
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.enable_discourse_workflows = true
      SiteSetting.enable_category_group_moderation = true
    end

    context "when the actor is an ordinary user" do
      fab!(:acting_user, :user)
      it { is_expected.to fail_a_policy(:administrator) }
    end

    context "when a dependency is disabled" do
      before { SiteSetting.enable_discourse_workflows = false }
      it { is_expected.to fail_a_policy(:dependencies_available) }
    end

    context "when dependencies are enabled" do
      it "installs and authorizes the native published teaching workflow" do
        expect(result).to run_successfully
        expect(DiscourseEducustomize::WorkflowTemplate.valid?(result.workflow)).to eq(true)
        expect(DiscourseEducustomize::Access.ids(:educustomize_workflow_ids)).to include(
          result.workflow.id,
        )
      end

      it "preserves an existing authorized teaching template" do
        existing = DiscourseEducustomize::WorkflowTemplate.install!(acting_user)
        expect { result }.not_to change(DiscourseWorkflows::Workflow, :count)
        expect(result).to run_successfully
        expect(result.workflow.id).to eq(existing.id)
      end
    end
  end
end
