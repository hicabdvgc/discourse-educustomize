# frozen_string_literal: true
module DiscourseEducustomize
  class SaveAgent
    include Service::Base

    params do
      attribute :course_id, :integer
      attribute :agent_id, :integer
      attribute :name, :string
      attribute :description, :string
      attribute :system_prompt, :string
      attribute :skills, default: -> { [] }

      before_validation do
        self.skills =
          skills.map do |skill|
            skill.is_a?(Hash) ? skill.deep_stringify_keys : skill
          end if skills.is_a?(Array)
      end

      validate :valid_skills
      attribute :default_llm_id, :integer
      attribute :enabled, :boolean, default: false
      attribute :temperature, :string
      attribute :top_p, :string
      validates :temperature,
                numericality: {
                  greater_than_or_equal_to: 0,
                  less_than_or_equal_to: 2,
                },
                allow_blank: true
      validates :top_p,
                numericality: {
                  greater_than: 0,
                  less_than_or_equal_to: 1,
                },
                allow_blank: true
      attribute :tools, default: -> { [] }
      attribute :subagent_ids, default: -> { [] }
      attribute :upload_ids, default: -> { [] }
      validates :course_id, :name, :description, :system_prompt, presence: true
      validates :name, length: { maximum: 100 }
      validates :description, length: { maximum: 2000 }
      validates :system_prompt, length: { maximum: 100_000 }

      def valid_skills
        schema =
          AgentConfiguration
            .schema
            .fetch("properties")
            .fetch("agents")
            .fetch("items")
            .fetch("properties")
            .fetch("skills")
        if !JSONSchemer.schema(schema).valid?(skills)
          errors.add(:skills, I18n.t("educustomize.invalid_skills"))
        elsif AgentInstructions.compose(system_prompt.to_s, skills).length >
              AgentInstructions::MAX_LENGTH
          errors.add(:system_prompt, :too_long, count: AgentInstructions::MAX_LENGTH)
        end
      end
    end

    model :course
    policy :course_teacher
    policy :references_authorized

    transaction do
      model :agent, :save_agent
      step :log
    end

    private

    def fetch_course(params:)
      Course.find_by(id: params.course_id)
    end
    def course_teacher(guardian:, course:)
      Access.teacher?(guardian.user, course)
    end
    def references_authorized(params:, course:, guardian:)
      return false if params.agent_id && !course.agent_links.exists?(ai_agent_id: params.agent_id)
      if params.default_llm_id && !AiConfiguration.models.exists?(id: params.default_llm_id)
        return false
      end
      return false unless params.tools.is_a?(Array) && (params.tools - AiConfiguration.tools).empty?
      ids = Array(params.subagent_ids).map(&:to_i)
      if ids.include?(params.agent_id) || (ids - course.agent_links.pluck(:ai_agent_id)).any?
        return false
      end
      return false if AiAgent.where(id: ids).any? { _1.subagent_ids.present? }
      # A Delegate already assigned to a Dais cannot itself become a Dais.
      return false if ids.any? && AiAgent.where("? = ANY(subagent_ids)", params.agent_id).exists?
      upload_ids = Array(params.upload_ids).map(&:to_i)
      own_ids = Upload.where(id: upload_ids, user_id: guardian.user.id).pluck(:id)
      attached_ids = params.agent_id ? AiAgent.find(params.agent_id).uploads.pluck(:id) : []
      (upload_ids - own_ids - attached_ids).empty?
    end
    def save_agent(params:, course:, guardian:)
      agent =
        params.agent_id ? AiAgent.find(params.agent_id) : AiAgent.new(created_by: guardian.user)
      agent.assign_attributes(
        name: params.name,
        description: params.description,
        system_prompt: AgentInstructions.compose(params.system_prompt, params.skills),
        default_llm_id: params.default_llm_id,
        force_default_llm: params.default_llm_id.present?,
        enabled: params.enabled,
        temperature: params.temperature,
        top_p: params.top_p,
        tools: params.tools,
        subagent_ids: Array(params.subagent_ids).map(&:to_i),
        allowed_group_ids: [course.teacher_group_id],
        require_approval: false,
      )
      agent.save!
      link = course.agent_links.find_or_initialize_by(ai_agent_id: agent.id)
      link.update!(prompt: params.system_prompt, skills: params.skills)
      upload_ids = Array(params.upload_ids).map(&:to_i)
      UploadReference.where(target: agent).where.not(upload_id: upload_ids).destroy_all
      UploadReference.ensure_exist!(upload_ids: upload_ids, target: agent)
      RagDocumentFragment.update_target_uploads(agent, upload_ids)
      agent
    end
    def log(guardian:, course:, agent:)
      Access.audit(guardian.user, "agent_saved", course_id: course.id, agent_id: agent.id)
    end
  end
end
