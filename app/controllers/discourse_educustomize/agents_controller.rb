# frozen_string_literal: true
module DiscourseEducustomize
  class AgentsController < BaseController
    before_action :authorize_course
    def index
      render json: {
               agents:
                 @course
                   .agent_links
                   .includes(ai_agent: :uploads)
                   .map { |link|
                     AgentSerializer.new(
                       link.ai_agent,
                       scope: guardian,
                       root: false,
                       link: link,
                     ).as_json
                   },
               models:
                 AiConfiguration
                   .models
                   .pluck(:id, :display_name, :provider, :name)
                   .map { |id, name, provider, model_name|
                     { id: id, name: name, provider: provider, model_name: model_name }
                   },
               tools: AiConfiguration.tools,
               topics:
                 @course
                   .category
                   .topics
                   .secured(guardian)
                   .order(:id)
                   .pluck(:id, :title)
                   .map { |id, title| { id: id, title: title } },
               dependencies: Access.dependencies,
             }
    end
    def create
      save_agent
    end
    def upload
      file = params[:file] || params[:files]&.first
      unless file.respond_to?(:tempfile) &&
               %w[txt md pdf].include?(
                 File.extname(file.original_filename).delete_prefix(".").downcase,
               ) && file.size <= 20.megabytes
        raise Discourse::InvalidParameters.new(:file)
      end
      upload =
        UploadCreator.new(
          file.tempfile,
          file.original_filename,
          type: "discourse_ai_rag_upload",
          skip_validations: true,
        ).create_for(current_user.id)
      if upload.persisted?
        Access.audit(
          current_user,
          "knowledge_uploaded",
          course_id: @course.id,
          upload_id: upload.id,
        )
        render json: UploadSerializer.new(upload, root: false), status: :created
      else
        render_json_error upload, status: 422
      end
    end
    def update
      save_agent
    end

    private

    def authorize_course
      @course = find_course
      Access.ensure_teacher!(current_user, @course)
    end
    def serialize_agent(agent)
      AgentSerializer.new(
        agent,
        scope: guardian,
        root: false,
        link: @course.agent_links.find_by!(ai_agent_id: agent.id),
      ).as_json
    end
    def save_agent
      permitted =
        params.require(:agent).permit(
          :name,
          :description,
          :system_prompt,
          :default_llm_id,
          :enabled,
          :temperature,
          :top_p,
          tools: [],
          subagent_ids: [],
          upload_ids: [],
          skills: %i[name description instructions],
        )
      SaveAgent.call(
        service_params.deep_merge(
          params: permitted.to_h.merge(course_id: @course.id, agent_id: params[:id]),
        ),
      ) do
        on_success do |agent:|
          render json: { agent: serialize_agent(agent) }, status: params[:id] ? 200 : 201
        end
        on_model_not_found(:course) { raise Discourse::NotFound }
        on_failed_policy(:course_teacher) { raise Discourse::InvalidAccess }
        on_failed_policy(:references_authorized) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render_json_error contract.errors.full_messages, status: 400
        end
        on_failure { render_json_error I18n.t("educustomize.invalid"), status: 422 }
      end
    end
  end
end
