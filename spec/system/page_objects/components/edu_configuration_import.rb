# frozen_string_literal: true

module PageObjects
  module Components
    class EduConfigurationImport < Base
      SELECTOR = ".educustomize__import"

      def preview_file(path)
        find("[data-area='migration']").click
        within(SELECTOR) do
          attach_file("Configuration file (.json)", path)
          click_button("Validate and preview")
        end
      end

      def has_root_name?(name)
        has_field?("agents.0.name", with: name)
      end

      def edit_root(name:, prompt:, skill_instructions:)
        form = FormKit.new("#{SELECTOR} form")
        form.collection_field("agents", 0, "name").fill_in(name)
        form.collection_field("agents", 0, "system_prompt").fill_in(prompt)
        form.field("agents.0.skills.0.instructions").fill_in(skill_instructions)
      end

      def create_copies
        within(SELECTOR) { click_button("Create copies") }
      end

      def has_import_notice?
        has_css?(
          "[role='status']",
          text:
            "The platform has created the assistant copies. You will need to upload their knowledge materials again.",
        )
      end
    end
  end
end
