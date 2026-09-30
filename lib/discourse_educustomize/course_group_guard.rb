# frozen_string_literal: true

module DiscourseEducustomize
  module CourseGroupGuard
    extend ActiveSupport::Concern

    included do
      before_action :protect_course_group_administration,
                    only: %i[
                      update
                      add_owners
                      add_members
                      remove_member
                      handle_membership_request
                      join
                      leave
                    ]
    end

    private

    def protect_course_group_administration
      return unless SiteSetting.educustomize_enabled
      return if current_user&.admin?

      group_id = params[:id].to_i
      course =
        Course.where(student_group_id: group_id).or(Course.where(teacher_group_id: group_id)).first
      return unless course

      if course.teacher_group_id == group_id || %w[update add_owners].include?(action_name)
        raise Discourse::InvalidAccess
      end
    end
  end
end
