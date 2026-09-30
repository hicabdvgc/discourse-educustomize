# frozen_string_literal: true
module DiscourseEducustomize
  class AgentSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :description,
               :system_prompt,
               :skills,
               :default_llm_id,
               :enabled,
               :temperature,
               :top_p,
               :tools,
               :subagent_ids,
               :upload_ids
    def system_prompt
      @options[:link]&.prompt || object.system_prompt
    end
    def skills
      @options[:link]&.skills || []
    end
    def upload_ids
      object.uploads.pluck(:id)
    end
    attributes :uploads
    def uploads
      object.uploads.map { { id: _1.id, name: _1.original_filename } }
    end
  end
end
