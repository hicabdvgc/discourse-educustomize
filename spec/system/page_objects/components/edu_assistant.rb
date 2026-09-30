# frozen_string_literal: true

module PageObjects
  module Components
    class EduAssistant < Base
      SELECTOR = ".educustomize__agent-editor form"

      def configure(name:, instructions:, model:)
        form = FormKit.new(SELECTOR)
        form.field("name").fill_in(name)
        form.field("description").fill_in("A teaching assistant for this course.")
        form.field("system_prompt").fill_in(instructions)
        form.field("default_llm_id").select(model.id)
        form.field("enabled").check
      end

      def change_instructions(instructions)
        FormKit.new(SELECTOR).field("system_prompt").fill_in(instructions)
      end

      def upload_material(path)
        within(SELECTOR) { attach_file("Knowledge materials", path) }
      end

      def has_material?(name)
        has_css?("#{SELECTOR} p", text: name)
      end

      def has_no_material?(name)
        has_no_css?("#{SELECTOR} p", text: name)
      end

      def remove_material(name)
        within("#{SELECTOR} p", text: name) { click_button("Remove material") }
      end

      def add_delegate(name)
        within("#{SELECTOR} [data-name='subagent_ids']") { check(name) }
      end

      def has_delegate?(name)
        within("#{SELECTOR} [data-name='subagent_ids']") { has_checked_field?(name) }
      end

      def add_skill(name:, description:, instructions:)
        within(SELECTOR) { click_button("Add skill") }
        within(all("#{SELECTOR} .educustomize__skill").last) do
          fill_in("Skill name", with: name)
          fill_in("Skill description", with: description)
          fill_in("Skill instructions", with: instructions)
        end
      end

      def has_skill?(name:, instructions:)
        within(SELECTOR) do
          has_field?("Skill name", with: name) &&
            has_field?("Skill instructions", with: instructions)
        end
      end

      def has_export_link?
        has_link?("Export JSON")
      end

      def has_unsaved_export_warning?
        has_css?(
          ".educustomize__agent-editor [role='status']",
          text: "You need to save your edits before exporting.",
        ) && has_button?("Export JSON", disabled: true) && has_no_link?("Export JSON")
      end

      def save
        FormKit.new(SELECTOR).submit
      end

      def has_instructions?(instructions)
        within(SELECTOR) { has_field?("Prompt", with: instructions) }
      end
    end
  end
end
