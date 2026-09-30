# frozen_string_literal: true

module PageObjects
  module Pages
    class EduAdmin < Base
      def open_from_plugin_navigation
        visit("/admin/plugins/discourse-educustomize")
        within(".admin-plugin-config-page") { click_link("Course setup") }
        self
      end

      def has_setup_links?
        has_link?("Plugin settings") && has_link?("Configure native AI models") &&
          has_link?("Manage teacher groups")
      end

      def prepare_workflow
        click_button("Prepare teaching workflow")
      end

      def has_prepared_notice?
        has_css?(
          "[role='status']",
          text: "The teaching workflow is ready, and courses are authorized to use it.",
        )
      end

      def has_teaching_workflow?
        has_css?("section.educustomize li", text: "Course teaching reply", count: 1)
      end
    end
  end
end
