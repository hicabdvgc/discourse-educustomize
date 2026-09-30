# frozen_string_literal: true

module PageObjects
  module Components
    class EduReply < Base
      def initialize(selector)
        @selector = selector
      end

      def has_draft?(text)
        within(@selector) { has_field?("Draft", with: text) }
      end

      def has_published_draft?(draft)
        within(@selector) do
          has_text?("Published") && has_css?(".educustomize__draft", text: draft) &&
            has_link?("View published reply in Topic") && has_no_button?("Approve and publish")
        end
      end

      def has_rejected_status?
        within(@selector) { has_text?("Rejected") && has_no_button?("Approve and publish") }
      end

      def approve(draft:)
        within(@selector) do
          fill_in("Draft", with: draft)
          click_button("Approve and publish")
        end
      end

      def reject
        within(@selector) { click_button("Reject") }
      end

      def regenerate
        within(@selector) { click_button("Regenerate") }
      end
    end
  end
end
