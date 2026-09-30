# frozen_string_literal: true

module PageObjects
  module Pages
    class EduCourses < Base
      def visit_catalog
        visit("/educustomize")
        self
      end

      def create_course(name:, introduction:)
        click_button("Create course")
        within("main.educustomize form") do
          fill_in("Name", with: name)
          fill_in("Introduction", with: introduction)
          click_button("Create course")
        end
      end

      def enter_named_course(name)
        within("article.educustomize__card", text: name) { click_link("Enter course") }
      end

      def join_course(course)
        within("article.educustomize__card", text: course.category.name) do
          click_button("Join course")
        end
      end

      def enter_course(course)
        within("article.educustomize__card", text: course.category.name) do
          click_link("Enter course")
        end
      end

      def has_joinable_course?(course)
        has_css?("article.educustomize__card", text: course.description) &&
          has_button?("Join course") && has_no_link?("Enter course")
      end

      def has_joined_course?(course)
        has_css?("article.educustomize__card", text: course.category.name) &&
          has_link?("Enter course", href: "/educustomize/courses/#{course.id}/learning") &&
          has_no_button?("Join course")
      end
    end

    class EduCourse < Base
      def visit_course(course)
        visit("/educustomize/courses/#{course.id}")
        self
      end

      def upload_image(path)
        attach_file("Course image", path)
      end

      def has_completed_image_upload?
        has_field?("Course image", with: "", disabled: false)
      end

      def has_category_image?
        has_css?(".category-heading__logo img")
      end

      def back_to_catalog
        click_link("Back to courses")
      end

      def has_category_management_links?
        has_css?("nav.educustomize__actions a", text: "Course management", exact_text: true)
      end

      def has_no_category_management_links?
        has_no_link?("Course management") && has_no_link?("Data export")
      end

      def open_all_discussions
        click_link("All discussions")
      end

      def open_from_category
        find("nav.educustomize__actions a", text: "Course management", exact_text: true).click
      end

      def update_introduction(introduction)
        within("main.educustomize > form") do
          fill_in("Introduction", with: introduction)
          click_button("Save course")
        end
      end

      def has_course_name?(name)
        has_css?("main.educustomize h1", text: name, exact_text: true)
      end

      def has_introduction?(introduction)
        has_field?("Introduction", with: introduction)
      end

      def has_saved_notice?
        has_css?("[role='status']", text: "Saved")
      end

      def new_assistant
        find("[data-area='ai']").click
        click_button("New assistant")
        Components::EduAssistant.new
      end

      def edit_assistant(name)
        find("[data-area='ai']").click
        if has_button?("Back to assistant list", wait: 0)
          click_button("Back to assistant list", match: :first)
        end
        within("div.educustomize__agent-summary", text: name) { click_button("Edit assistant") }
        Components::EduAssistant.new
      end

      def has_assistant?(name)
        has_css?("div.educustomize__agent-summary h3", text: name, exact_text: true)
      end
    end
  end
end
