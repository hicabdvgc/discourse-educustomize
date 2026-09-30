# frozen_string_literal: true

module DiscourseEducustomize
  class PrepareTeaching
    include Service::Base

    policy :administrator
    model :teacher_group
    policy :reviewed_membership
    step :enable_native_features
    step :open_teacher_applications
    step :prepare_activity_tags
    model :template_category, :prepare_template_category
    step :enable_templates
    step :enable_course_questions
    step :log

    private

    def administrator(guardian:)
      guardian.user&.admin?
    end

    def fetch_teacher_group
      Group.find_by(id: SiteSetting.educustomize_teacher_group.to_i, automatic: false)
    end

    def reviewed_membership(teacher_group:)
      !teacher_group.public_admission &&
        teacher_group
          .group_users
          .where(owner: true)
          .joins(:user)
          .where(users: { admin: false })
          .none?
    end

    def enable_native_features(teacher_group:, guardian:)
      result =
        SiteSetting::Update.call(
          guardian: guardian,
          params: {
            settings:
              TeachingFeatures
                .settings(teacher_group)
                .map { |name, value| { setting_name: name, value: value } },
          },
        )
      fail! if result.failure?
    end

    def open_teacher_applications(teacher_group:, guardian:)
      teacher_group.add_owner(guardian.user)
      teacher_group.update!(
        allow_membership_requests: true,
        visibility_level: Group.visibility_levels[:public],
      )
      GroupActionLogger.new(guardian.user, teacher_group).log_change_group_settings
    end

    def prepare_activity_tags
      TeachingFeatures::KINDS.each do |kind|
        Tag.find_or_create_by!(name: TeachingFeatures.tag(kind))
      end
    end

    def prepare_template_category(teacher_group:, guardian:)
      DistributedMutex.synchronize("educustomize-prepare-templates") do
        TeachingFeatures.template_category ||
          Category.create(
            name: I18n.t("educustomize.template_category"),
            user: guardian.user,
          ) do |category|
            category.set_permissions(teacher_group.name => CategoryGroup.permission_types[:full])
            category.custom_fields[TeachingFeatures::TEMPLATE_FIELD] = true
          end
      end
    end

    def enable_templates(template_category:, guardian:)
      result =
        SiteSetting::Update.call(
          guardian: guardian,
          params: {
            settings: [
              {
                setting_name: :discourse_templates_categories,
                value:
                  (Access.ids(:discourse_templates_categories) | [template_category.id]).join("|"),
              },
            ],
          },
        )
      fail! if result.failure?
    end

    def enable_course_questions
      Course
        .includes(:category)
        .find_each do |course|
          course.category.custom_fields["enable_accepted_answers"] = true
          course.category.save_custom_fields
        end
    end

    def log(guardian:, teacher_group:, template_category:)
      Access.audit(
        guardian.user,
        "teaching_prepared",
        teacher_group_id: teacher_group.id,
        template_category_id: template_category.id,
      )
    end
  end
end
