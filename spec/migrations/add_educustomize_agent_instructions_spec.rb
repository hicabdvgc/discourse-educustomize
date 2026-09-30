# frozen_string_literal: true

require_relative "../../db/migrate/20260929073918_add_educustomize_agent_instructions"

RSpec.describe AddEducustomizeAgentInstructions do
  fab!(:link, :educustomize_agent_link)

  it "backfills the exact original prompt with empty Skills and preserves native instructions" do
    original = "Original prompt.\n\n  Preserve whitespace and Unicode: 教学。  "
    link.ai_agent.update!(system_prompt: original)
    connection = ActiveRecord::Base.connection
    connection.remove_column(:educustomize_agent_links, :prompt)
    connection.remove_column(:educustomize_agent_links, :skills)

    described_class.new.up

    DiscourseEducustomize::AgentLink.reset_column_information
    expect(link.reload).to have_attributes(prompt: original, skills: [])
    expect(link.ai_agent.reload.system_prompt).to eq(original)
  ensure
    DiscourseEducustomize::AgentLink.reset_column_information
  end
end
