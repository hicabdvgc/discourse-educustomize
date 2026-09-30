# frozen_string_literal: true
module DiscourseEducustomize
  module GroupPermissions
    def can_edit_group?(group)
      if SiteSetting.educustomize_enabled && Course.exists?(teacher_group_id: group.id)
        return is_admin?
      end
      if SiteSetting.educustomize_enabled && (course = Course.find_by(student_group_id: group.id))
        return Access.teacher?(user, course) && can_see?(course.category)
      end
      super
    end
  end
end
