# frozen_string_literal: true
# name: discourse-educustomize
# about: This plugin provides course management and AI configuration through native Discourse resources.
# version: 0.3.1
# required_version: 2026.8.0

enabled_site_setting :educustomize_enabled
register_asset "stylesheets/educustomize.scss"
register_asset "stylesheets/educustomize-palettes.scss"
add_admin_route "educustomize.admin.title", "discourse-educustomize", use_new_show_route: true
module ::DiscourseEducustomize
  PLUGIN_NAME = "discourse-educustomize"
end
require_relative "lib/discourse_educustomize/engine"

after_initialize do
  on(:user_added_to_group) do |user, group, **|
    course = DiscourseEducustomize::Course.find_by(teacher_group_id: group.id)
    course.student_group.add_owner(user) if course
  end
  on(:user_removed_from_group) do |user, group, **|
    course = DiscourseEducustomize::Course.find_by(teacher_group_id: group.id)
    course.student_group.group_users.find_by(user: user)&.update!(owner: false) if course
  end
  Guardian.prepend(DiscourseEducustomize::GroupPermissions)
  GroupsController.include(DiscourseEducustomize::CourseGroupGuard)
  add_to_serializer(:current_user, :educustomize_course_ids) do
    courses = DiscourseEducustomize::Course.all
    courses = courses.where(teacher_group_id: object.group_ids) unless object.admin?
    courses.pluck(:id)
  end
  if defined?(DiscourseWorkflows) && defined?(DiscourseAi)
    register_discourse_workflows_node do
      require_relative "lib/discourse_educustomize/nodes/generate"
      require_relative "lib/discourse_educustomize/nodes/publish"
      [DiscourseEducustomize::Nodes::Generate, DiscourseEducustomize::Nodes::Publish]
    end
    DiscourseAi::Agents::Agent.prepend(DiscourseEducustomize::ScopedAgentTools)
    DiscourseAi::Agents::Bot.prepend(DiscourseEducustomize::ScopedAuditAttribution)
    DiscourseAi::Agents::Tools::RandomPicker.prepend(DiscourseEducustomize::RandomPickerOptions)
    DiscourseAi::Completions::Endpoints::Base.singleton_class.prepend(
      DiscourseEducustomize::DeepseekCompatibility::EndpointSelection,
    )
    DiscourseAi::Completions::Dialects::Dialect.singleton_class.prepend(
      DiscourseEducustomize::DeepseekCompatibility::DialectSelection,
    )
  end
  add_to_serializer(:current_user, :educustomize_can_create) do
    DiscourseEducustomize::Access.can_create?(object)
  end
  add_to_serializer(:basic_category, :educustomize_course_id) do
    DiscourseEducustomize::Course.find_by(category_id: object.id)&.id
  end
  add_to_serializer(:topic_view, :educustomize_course) do
    course = DiscourseEducustomize::Course.find_by(category_id: object.topic.category_id)
    if course && scope.user && scope.can_see?(course.category)
      { id: course.id, can_manage: DiscourseEducustomize::Access.teacher?(scope.user, course) }
    end
  end
end
