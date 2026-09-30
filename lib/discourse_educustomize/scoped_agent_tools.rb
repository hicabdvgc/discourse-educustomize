# frozen_string_literal: true
module DiscourseEducustomize
  module ScopedAgentTools
    def runtime_tools(llm: nil, context: nil)
      tools = super
      run_id = context&.feature_context&.[]("educustomize_run_id")
      return tools unless run_id
      run = Run.find(run_id)
      run.validate_current!
      unless run.topic_policy.course.agent_links.exists?(ai_agent_id: id)
        raise Discourse::InvalidAccess
      end
      allowed = AiConfiguration.tools + %w[SearchUploadedDocuments SpawnAgent]
      tools.select do |tool|
        allowed.include?(tool.to_s.demodulize) || tool <= DiscourseAi::Agents::Tools::SpawnAgent
      end
    end
  end
end
