# frozen_string_literal: true
module DiscourseEducustomize
  class AdminController < BaseController
    before_action :ensure_admin

    def show
      render html: "", layout: "admin"
    end

    def index
      render json: {
               courses:
                 Course
                   .includes(:category)
                   .map { |course| { id: course.id, name: course.category.name } },
               retention: CourseData.retention,
               sampling_enabled: SiteSetting.ai_llm_temperature_top_p_enabled,
               teaching: TeachingFeatures.status,
               explorer_available: ReportRunner.available?,
               dependencies: Access.dependencies,
               models:
                 (
                   if defined?(::LlmModel)
                     LlmModel
                       .order(:id)
                       .pluck(:id, :display_name)
                       .map { |id, name| { id: id, name: name } }
                   else
                     []
                   end
                 ),
               workflows:
                 (
                   if defined?(::DiscourseWorkflows::Workflow)
                     DiscourseWorkflows::Workflow
                       .where(id: Access.ids(:educustomize_workflow_ids))
                       .select { WorkflowTemplate.valid?(_1) }
                       .map { { id: _1.id, name: _1.name } }
                   else
                     []
                   end
                 ),
             }
    end

    def install_workflow
      InstallWorkflow.call(service_params) do
        on_success do |workflow:|
          render json: { workflow: { id: workflow.id, name: workflow.name } }
        end
        on_failed_policy(:administrator) { raise Discourse::InvalidAccess }
        on_failed_policy(:dependencies_available) do
          render_json_error I18n.t("educustomize.dependencies_required"), status: 422
        end
        on_failure { render_json_error I18n.t("educustomize.invalid"), status: 422 }
      end
    end

    def workflow_retention
      days = Integer(params[:days].to_s, exception: false)
      raise Discourse::InvalidParameters.new(:days) unless days && days.between?(0, 36_500)
      previous = SiteSetting.workflow_executions_retention_days
      SiteSetting::Update.call(
        service_params.deep_merge(
          params: {
            settings: [{ setting_name: :workflow_executions_retention_days, value: days }],
          },
          options: {
            allow_changing_hidden: [:workflow_executions_retention_days],
          },
        ),
      ) do
        on_success do
          if previous != days
            StaffActionLogger.new(current_user).log_site_setting_change(
              :workflow_executions_retention_days,
              previous,
              days,
            )
          end
          render json: { days: SiteSetting.workflow_executions_retention_days }
        end
        on_failure { render_json_error I18n.t("educustomize.invalid"), status: 422 }
      end
    end

    def prepare_teaching
      PrepareTeaching.call(service_params) do
        on_success { render json: { teaching: TeachingFeatures.status } }
        on_model_not_found(:teacher_group) do
          render_json_error I18n.t("educustomize.teacher_group_required"), status: 422
        end
        on_failed_policy(:reviewed_membership) do
          render_json_error I18n.t("educustomize.teacher_group_unsafe"), status: 422
        end
        on_failure { render_json_error I18n.t("educustomize.invalid"), status: 422 }
      end
    end

    def sampling
      value = params[:enabled].to_s
      raise Discourse::InvalidParameters.new(:enabled) if %w[true false].exclude?(value)
      name = :ai_llm_temperature_top_p_enabled
      previous = SiteSetting.public_send(name)
      SiteSetting::Update.call(
        service_params.deep_merge(
          params: {
            settings: [{ setting_name: name, value: value }],
          },
          options: {
            allow_changing_hidden: [name],
          },
        ),
      ) do
        on_success do
          current = SiteSetting.public_send(name)
          if previous != current
            StaffActionLogger.new(current_user).log_site_setting_change(name, previous, current)
          end
          render json: { enabled: current }
        end
        on_failure { render_json_error I18n.t("educustomize.invalid"), status: 422 }
      end
    end
  end
end
