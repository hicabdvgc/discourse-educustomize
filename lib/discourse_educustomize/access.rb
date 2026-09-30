# frozen_string_literal: true
module DiscourseEducustomize
  module Access
    def self.can_create?(user)
      group_id = SiteSetting.educustomize_teacher_group.to_i
      user &&
        (
          user.admin? ||
            (
              group_id.positive? && Group.exists?(id: group_id, automatic: false) &&
                user.in_any_groups?([group_id])
            )
        )
    end
    def self.teacher?(user, course)
      user && (user.admin? || user.in_any_groups?([course.teacher_group_id])) &&
        user.guardian.can_see?(course.category)
    end
    def self.ensure_teacher!(user, course)
      raise Discourse::InvalidAccess unless teacher?(user, course)
    end
    def self.ensure_visible!(guardian, course)
      raise Discourse::InvalidAccess unless guardian.can_see?(course.category)
    end
    def self.ids(setting)
      SiteSetting.public_send(setting).split("|").filter_map { Integer(_1, exception: false) }
    end
    def self.dependencies
      {
        ai: defined?(::AiAgent).present? && SiteSetting.discourse_ai_enabled,
        workflows:
          defined?(::DiscourseWorkflows::Workflow).present? &&
            SiteSetting.enable_discourse_workflows,
        category_moderation: SiteSetting.enable_category_group_moderation,
      }
    end
    def self.audit(user, action, details)
      StaffActionLogger.new(user).log_custom("educustomize_#{action}", details)
    end
  end
end
