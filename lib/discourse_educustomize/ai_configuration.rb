# frozen_string_literal: true
module DiscourseEducustomize
  module AiConfiguration
    # These native tools cannot retrieve forum discussions or execute arbitrary code.
    SAFE_TOOLS = %w[Time RandomPicker SearchUploadedDocuments].freeze
    def self.tools
      SiteSetting.educustomize_tool_names.split("|") & SAFE_TOOLS
    end
    def self.models
      LlmModel.where(id: Access.ids(:educustomize_model_ids))
    end
    def self.digest(policy)
      records = policy.course.agent_links.includes(:ai_agent).map(&:ai_agent)
      Digest::SHA256.hexdigest(
        [
          policy.attributes.except("created_at", "updated_at"),
          records.map { [_1.id, _1.updated_at.to_f, _1.uploads.pluck(:id).sort] },
          SiteSetting.educustomize_model_ids,
          SiteSetting.educustomize_tool_names,
          SiteSetting.educustomize_workflow_ids,
        ].to_json,
      )
    end
    def self.ready?(policy)
      reasons(policy).empty?
    end
    def self.reasons(policy)
      issues =
        Access.dependencies.filter_map { |name, enabled| "dependency_#{name}" unless enabled }
      return issues << "assistant_missing" unless policy.ai_agent
      unless Access.ids(:educustomize_workflow_ids).include?(policy.workflow_id) &&
               WorkflowTemplate.valid?(DiscourseWorkflows::Workflow.find_by(id: policy.workflow_id))
        issues << "workflow_invalid"
      end
      records = [policy.ai_agent] + AiAgent.where(id: policy.ai_agent.subagent_ids).to_a
      records.each do |agent|
        unless policy.course.agent_links.exists?(ai_agent_id: agent.id)
          issues << "assistant_unauthorized"
        end
        issues << "assistant_disabled" unless agent.enabled
        issues << "model_unauthorized" unless models.exists?(id: agent.default_llm_id)
        unless (agent.tools.map { _1.is_a?(Array) ? _1.first : _1 } - tools).empty? &&
                 agent.ai_agent_mcp_servers.empty?
          issues << "tools_unauthorized"
        end
        issues << "knowledge_pending" unless knowledge_ready?(agent)
      end
      issues.uniq
    end
    def self.knowledge_ready?(agent)
      knowledge_status(agent).all? { |material| material[:status] == "ready" }
    end
    def self.knowledge_status(agent)
      uploads = agent.uploads.to_a
      return [] if uploads.empty?
      enabled = DiscourseAi::Embeddings.enabled?
      statuses = enabled ? RagDocumentFragment.indexing_status(agent, uploads) : {}
      uploads.map do |upload|
        progress = statuses[upload.id]
        state =
          if !enabled
            "disabled"
          elsif !progress || progress[:total].to_i.zero?
            "unknown"
          elsif progress[:left].to_i.zero?
            "ready"
          else
            "indexing"
          end
        {
          id: upload.id,
          name: upload.original_filename,
          status: state,
          total: progress&.dig(:total),
          indexed: progress&.dig(:indexed),
          left: progress&.dig(:left),
        }
      end
    end
  end
end
