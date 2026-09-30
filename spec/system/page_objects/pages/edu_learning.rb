# frozen_string_literal: true

module PageObjects
  module Pages
    class EduLearning < Base
      def visit_course(course)
        visit("/educustomize/courses/#{course.id}/learning")
        self
      end

      def has_sections?
        has_css?(".educustomize__sections section", count: 5) &&
          has_text?("Discussion assignments") && has_text?("Learning materials") &&
          has_text?("Feedback and questionnaires")
      end

      def create_activity(name)
        within(".educustomize__sections section", text: name) { click_link("Create topic") }
      end

      def browse_activity(name)
        within(".educustomize__sections section", text: name) { click_link("Browse") }
      end

      def has_teacher_controls?
        has_link?("Course management") && has_link?("Data export") &&
          has_link?("Runtime and maintenance") && has_link?("Teaching templates")
      end

      def has_student_controls?
        has_no_link?("Course management") && has_no_link?("Data export") &&
          has_no_link?("Teaching templates") &&
          has_css?(".educustomize__sections a", text: "Create topic", count: 2)
      end

      def open_topic(title)
        click_link(title, exact: true)
      end

      def open_templates
        within("main.educustomize") { click_link("Teaching templates") }
      end

      def has_activity?(title)
        has_css?(".topic-list a.title", text: title)
      end

      def has_no_activity?(title)
        has_no_css?(".topic-list a.title", text: title)
      end

      def new_template
        click_button("New Topic")
      end
    end

    class EduTeachingSetup < Base
      def visit_setup
        visit("/admin/plugins/discourse-educustomize/courses")
        self
      end

      def prepare
        click_button("Prepare teaching features")
      end

      def has_prepared_features?
        has_text?("Teacher applications: Configured") &&
          has_text?("Native teacher permissions: Configured") &&
          has_text?("Learning file attachments: Configured")
      end

      def request_teacher_access(reason)
        visit("/educustomize")
        click_link("Apply for teacher access")
        click_button("Request", exact: true)
        within(".request-group-membership-form") do
          find("textarea").fill_in(with: reason)
          click_button("Submit Request")
        end
      end

      def approve_teacher(group, user)
        visit("/g/#{group.name}/requests")
        within(".directory-table__row", text: user.username) { click_button("Accept", exact: true) }
      end

      def has_accepted_teacher?(user)
        has_css?(".directory-table__row", text: user.username) && has_text?("accepted")
      end

      def has_course_creation?
        has_button?("Create course")
      end
    end
  end

  module Components
    class EduNativeComposer < Composer
      def has_activity_tag?(tag)
        has_css?("#reply-control .mini-tag-chooser", text: tag)
      end

      def upload_file(path)
        attach_file("file-uploader", path, make_visible: true)
      end

      def open_insertions
        find("#reply-control button.options").click
      end

      def has_native_teaching_tools?
        has_button?("Create Policy") && has_button?("Create event") &&
          has_button?("Insert template")
      end

      def insert_saved_template(title)
        click_button("Insert template")
        within(".template-item", text: title) { find(".templates-apply").click }
      end

      def insert_event
        open_insertions
        click_button("Create event")
      end

      def insert_policy(group)
        open_insertions
        click_button("Create Policy")
        chooser = PageObjects::Components::SelectKit.new(".policy-builder .groups .group-chooser")
        chooser.expand
        chooser.select_row_by_name(group.name)
        chooser.collapse
        within(".policy-builder") { click_button("Insert", exact: true) }
      end
    end

    class EduNativeActivity < Base
      def has_pdf_attachment?
        has_css?(".cooked a.attachment", text: "small.pdf")
      end

      def open_pdf
        attachment = find(".cooked a.attachment", text: "small.pdf")
        @pdf_url = attachment[:href]
        attachment.click
      end

      def has_pdf_document?
        has_current_path?(@pdf_url, url: true) &&
          has_css?("link[href$='/pdf_embedder.css']", visible: false)
      end

      def vote(option)
        find(".poll li button", text: option, exact_text: true).click
      end

      def has_vote?
        has_css?(".poll .info-number", text: "1", exact_text: true)
      end

      def accept_policy
        click_button("Accept Policy")
      end

      def has_accepted_policy?
        has_button?("Revoke Policy")
      end

      def has_assignment?(user)
        has_css?("#topic .assigned-to", text: user.username)
      end
    end
  end
end
