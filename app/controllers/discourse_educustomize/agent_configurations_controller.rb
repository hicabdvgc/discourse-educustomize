# frozen_string_literal: true

module DiscourseEducustomize
  class AgentConfigurationsController < BaseController
    before_action :authorize_course
    rescue_from AgentConfiguration::Invalid do |error|
      render_json_error error.message, status: 422
    end

    def show
      root =
        @course
          .agent_links
          .includes(ai_agent: :default_llm)
          .find_by!(ai_agent_id: params[:agent_id])
      ids = [root.ai_agent_id, *root.ai_agent.subagent_ids]
      links =
        @course
          .agent_links
          .includes(ai_agent: :default_llm)
          .where(ai_agent_id: ids)
          .index_by(&:ai_agent_id)
      raise Discourse::InvalidAccess unless links.size == ids.uniq.size
      document = {
        "format" => "discourse-educustomize/agent-config",
        "schema_version" => 1,
        "root" => "agent-#{root.ai_agent_id}",
        "agents" =>
          ids.map do |id|
            AgentConfigurationSerializer.new(links.fetch(id), root: false).as_json.stringify_keys
          end,
      }
      AgentConfiguration.new(document).validate!
      send_data JSON.pretty_generate(document),
                type: "application/json; charset=utf-8",
                disposition: "attachment",
                filename: "assistant-#{root.ai_agent_id}.json"
    end

    def preview
      render json: AgentConfiguration.new(configuration_document).preview
    end

    def create
      ImportAgentConfiguration.call(
        service_params.deep_merge(
          params: {
            course_id: @course.id,
            document: configuration_document,
            model_mappings:
              (
                if params[:model_mappings].is_a?(ActionController::Parameters)
                  params[:model_mappings].to_unsafe_h
                else
                  params[:model_mappings]
                end
              ),
          },
        ),
      ) do
        on_success do |agents:|
          root = agents.fetch(configuration_document.fetch("root"))
          render json: {
                   agent_id: root.id,
                   agent_ids: agents.transform_values(&:id),
                 },
                 status: :created
        end
        on_model_not_found(:course) { raise Discourse::NotFound }
        on_failed_policy(:course_teacher) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render_json_error contract.errors.full_messages, status: 422
        end
        on_model_not_found(:agents) do |result|
          message =
            (
              if result.exception.is_a?(AgentConfiguration::Invalid)
                result.exception.message
              else
                I18n.t("educustomize.invalid")
              end
            )
          render_json_error message, status: 422
        end
        on_failure { render_json_error I18n.t("educustomize.invalid"), status: 422 }
      end
    end

    private

    def authorize_course
      @course = find_course
      Access.ensure_teacher!(current_user, @course)
    end

    def configuration_document
      # The versioned JSON Schema validates every field, including unknown keys.
      value = params.require(:document)
      value.is_a?(ActionController::Parameters) ? value.to_unsafe_h : value
    end
  end
end
