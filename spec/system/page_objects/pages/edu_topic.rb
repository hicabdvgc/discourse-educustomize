# frozen_string_literal: true

module PageObjects
  module Pages
    class EduTopic < Base
      def visit_settings(topic)
        visit("/educustomize/topics/#{topic.id}")
        self
      end

      def configure(assistant:, workflow:)
        form = Components::FormKit.new("main.educustomize > section:first-of-type form")
        form.field("ai_agent_id").select(assistant.id)
        form.field("workflow_id").select(workflow.id)
        form.submit
      end

      def has_selected_assistant?(assistant)
        has_select?("Assistant or Bloc", selected: assistant.name)
      end

      def enable_automatic_discussion_context
        form = Components::FormKit.new("main.educustomize > section:first-of-type form")
        form.field("auto_reply").check
        form.field("memory").check
        form.field("require_review").uncheck
        form.submit
      end

      def has_automatic_discussion_context?
        has_checked_field?("Automatically respond to student replies", visible: :all) &&
          has_checked_field?("Use the current Topic discussion as context", visible: :all) &&
          has_unchecked_field?("Require teacher approval", visible: :all)
      end

      def has_saved_notice?
        has_css?("[role='status']", text: "Saved", exact_text: true)
      end

      def has_ready_notice?
        has_css?(".educustomize__notice", text: "Ready to generate", exact_text: true)
      end

      def generate_reply(post)
        form = Components::FormKit.new("main.educustomize > section:nth-of-type(2) form")
        form.field("post_id").select(post.id)
        form.submit
      end

      def has_no_native_post?(number)
        has_no_css?(".topic-post:not(.staged) #post_#{number}")
      end

      def latest_reply
        Components::EduReply.new("main.educustomize > article:first-of-type")
      end
    end
  end
end
