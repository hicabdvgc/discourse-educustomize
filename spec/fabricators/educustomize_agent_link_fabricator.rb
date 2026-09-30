# frozen_string_literal: true

Fabricator(:educustomize_agent_link, class_name: "DiscourseEducustomize::AgentLink") do
  course { Fabricate(:educustomize_course) }
  ai_agent { Fabricate(:ai_agent) }
end
