# frozen_string_literal: true

module DiscourseEducustomize
  module AgentInstructions
    MAX_LENGTH = 100_000

    def self.compose(prompt, skills)
      return prompt if skills.empty?
      [
        prompt,
        "## Skills",
        *skills.map do |skill|
          [
            "### #{skill.fetch("name")}",
            skill.fetch("description"),
            skill.fetch("instructions"),
          ].join("\n\n")
        end,
      ].join("\n\n")
    end
  end
end
