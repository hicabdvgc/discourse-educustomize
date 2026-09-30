# frozen_string_literal: true
class AddEducustomizeAgentInstructions < ActiveRecord::Migration[8.0]
  def up
    add_column :educustomize_agent_links, :prompt, :text
    add_column :educustomize_agent_links, :skills, :jsonb, default: [], null: false
    execute <<~SQL
      UPDATE educustomize_agent_links AS links
      SET prompt = agents.system_prompt
      FROM ai_agents AS agents
      WHERE agents.id = links.ai_agent_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
