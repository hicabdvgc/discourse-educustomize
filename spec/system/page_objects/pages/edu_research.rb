# frozen_string_literal: true

require "csv"

module PageObjects
  module Pages
    class EduResearch < Base
      def open_from_course(course)
        visit("/educustomize/courses/#{course.id}")
        click_link("Data export")
        self
      end

      def preview(view: nil)
        select(view, from: "Report view") if view
        click_button("Preview")
        self
      end

      def has_post?(post)
        has_css?("table.educustomize__table td", text: post.raw, exact_text: true)
      end

      def has_column?(label)
        has_css?("table.educustomize__table th", text: label, exact_text: true)
      end

      def has_empty_result?
        has_css?(
          "[role='status']",
          text: "There are no records that match your filters and access permissions.",
        )
      end

      def download_csv
        path =
          page.driver.with_playwright_page do |browser|
            browser.expect_download { click_button("Download") }.path
          end
        CSV.read(path, headers: true)
      end

      def has_download_notice?
        has_css?("[role='status']", text: "The platform has prepared the file for download.")
      end

      def has_disabled_notice?
        has_css?("[role='status']", text: "The Data Explorer plugin is disabled or unavailable.") &&
          has_no_button?("Preview") && has_no_button?("Download")
      end

      def has_no_management_links?
        has_no_link?("Data export") && has_no_link?("Runtime and maintenance")
      end
    end

    class EduOperations < Base
      def open_from_course(course)
        visit("/educustomize/courses/#{course.id}")
        click_link("Runtime and maintenance")
        self
      end

      def filter(status:, outcome: "All")
        select(status, from: "Execution status")
        select(outcome, from: "Review outcome")
        click_button("Refresh")
        self
      end

      def has_run?(run, status:, outcome:)
        has_css?(
          "article.educustomize__card",
          text: "##{run.id} · #{run.topic_policy.topic.title}",
        ) && has_css?("article.educustomize__card", text: "#{status} / #{outcome}")
      end

      def has_no_matching_runs?
        has_text?("There are no run records that match the selected filters.")
      end

      def open_run(run)
        find(
          "a[href='/educustomize/topics/#{run.topic_policy.topic_id}?run_id=#{run.id}#run-#{run.id}']",
        ).click
      end

      def has_review_record?(run)
        has_css?("#run-#{run.id}") { |record| record.evaluate_script(<<~JS) }
            (() => {
              const rect = this.getBoundingClientRect();
              return rect.top >= 0 && rect.bottom <= window.innerHeight;
            })()
          JS
      end

      def has_no_retention_controls?
        has_no_field?("Workflow retention days (0 disables timed cleanup)") &&
          has_no_link?("Native AI logs and retention")
      end
    end

    class EduResearchAdmin < Base
      def open
        visit("/admin/plugins/discourse-educustomize/courses")
        self
      end

      def has_course_tools?(course)
        has_link?("Data export", href: "/educustomize/courses/#{course.id}/reports") &&
          has_link?(
            "Runtime and maintenance",
            href: "/educustomize/courses/#{course.id}/maintenance",
          )
      end

      def set_retention(days)
        within("section.educustomize form", text: "Workflow retention days") do
          fill_in("Workflow retention days (0 disables timed cleanup)", with: days)
          click_button("Save")
        end
      end

      def has_retention?(days)
        has_field?("Workflow retention days (0 disables timed cleanup)", with: days.to_s)
      end

      def has_saved_notice?
        has_css?("[role='status']", text: "Saved")
      end
    end
  end
end
