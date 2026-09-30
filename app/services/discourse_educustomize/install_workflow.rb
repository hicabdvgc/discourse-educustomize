# frozen_string_literal: true
module DiscourseEducustomize
  class InstallWorkflow
    include Service::Base

    policy :administrator
    policy :dependencies_available
    model :workflow, :install_course_workflow
    step :log

    private

    def administrator(guardian:)
      guardian.user&.admin?
    end

    def dependencies_available
      Access.dependencies.values.all?
    end

    def install_course_workflow(guardian:)
      DistributedMutex.synchronize("educustomize-install-workflow") do
        DiscourseWorkflows::Workflow
          .where(id: Access.ids(:educustomize_workflow_ids))
          .find { WorkflowTemplate.valid?(_1) } || WorkflowTemplate.install!(guardian.user)
      end
    end

    def log(guardian:, workflow:)
      Access.audit(guardian.user, "workflow_prepared", workflow_id: workflow.id)
    end
  end
end
