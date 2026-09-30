# frozen_string_literal: true

module PageObjects
  module Pages
    class EduMembers < Base
      def open_from_course(course)
        visit("/educustomize/courses/#{course.id}")
        click_link("Manage students")
      end

      def add_student(student)
        Group.new.add_users
        within(".modal-container") do
          find(".user-chooser .select-kit-header").click
          find(".user-chooser .filter-input").set(student.username)
          find(".select-kit-row", text: student.username).click
          find("button.add.btn-primary").click
        end
      end

      def has_student?(student)
        has_css?(".directory-table__row .username", text: student.username, exact_text: true)
      end

      def has_no_student?(student)
        has_no_css?(".directory-table__row .username", text: student.username, exact_text: true)
      end

      def remove_student(student)
        row = find(".directory-table__row", text: student.username)
        row.find(".group-member-dropdown .select-kit-header").click
        find(".select-kit-row[data-value='removeMember']").click
      end
    end
  end
end
