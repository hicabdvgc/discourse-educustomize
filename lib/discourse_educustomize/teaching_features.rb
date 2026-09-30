# frozen_string_literal: true

module DiscourseEducustomize
  module TeachingFeatures
    KINDS = %w[discussion announcement material question feedback].freeze
    SWITCHES = %i[
      poll_enabled
      assign_enabled
      policy_enabled
      discourse_templates_enabled
      solved_enabled
      discourse_events_enabled
      discourse_post_event_enabled
      tagging_enabled
    ].freeze
    GROUP_SETTINGS = %i[
      assign_allowed_on_groups
      create_policy_allowed_groups
      discourse_post_event_allowed_on_groups
    ].freeze
    EXTENSIONS = %w[pdf txt md docx pptx xlsx csv].freeze
    TEMPLATE_FIELD = "educustomize_teaching_templates"

    def self.tag(kind)
      "edu-#{kind}"
    end

    def self.template_category
      Category.joins(:_custom_fields).find_by(
        category_custom_fields: {
          name: TEMPLATE_FIELD,
          value: "t",
        },
      )
    end

    def self.settings(teacher_group)
      SWITCHES
        .to_h { |name| [name, true] }
        .merge(
          GROUP_SETTINGS.to_h { |name| [name, (Access.ids(name) | [teacher_group.id]).join("|")] },
          authorized_extensions:
            (SiteSetting.authorized_extensions.split("|") | EXTENSIONS).join("|"),
        )
    end

    def self.status
      group = Group.find_by(id: SiteSetting.educustomize_teacher_group.to_i, automatic: false)
      {
        teacher_group_url: group && "/g/#{group.name}",
        teacher_group_admin_url: group && "/g/#{group.name}/manage/interaction",
        teacher_requests_ready: group && group.allow_membership_requests && !group.public_admission,
        features: SWITCHES.to_h { |name| [name, SiteSetting.public_send(name)] },
        teacher_permissions_ready:
          group && GROUP_SETTINGS.all? { |name| Access.ids(name).include?(group.id) },
        files_ready: (EXTENSIONS - SiteSetting.authorized_extensions.split("|")).empty?,
        templates_ready: template_category.present?,
      }
    end
  end
end
