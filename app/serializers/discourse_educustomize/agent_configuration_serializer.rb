# frozen_string_literal: true

module DiscourseEducustomize
  class AgentConfigurationSerializer < ApplicationSerializer
    attributes :key,
               :name,
               :description,
               :system_prompt,
               :skills,
               :model,
               :enabled,
               :temperature,
               :top_p,
               :tools,
               :delegates

    def key
      "agent-#{object.ai_agent_id}"
    end
    def name
      object.ai_agent.name
    end
    def description
      object.ai_agent.description
    end
    def system_prompt
      object.prompt || object.ai_agent.system_prompt
    end
    def skills
      object.skills
    end
    def model
      object.ai_agent.default_llm&.attributes&.slice("provider", "name", "display_name")
    end
    def enabled
      object.ai_agent.enabled
    end
    def temperature
      object.ai_agent.temperature
    end
    def top_p
      object.ai_agent.top_p
    end
    def tools
      object.ai_agent.tools
    end
    def delegates
      object.ai_agent.subagent_ids.map { |id| "agent-#{id}" }
    end
  end
end
