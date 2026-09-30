# frozen_string_literal: true
module DiscourseEducustomize
  class CreateCourse
    include Service::Base

    params do
      attribute :name, :string
      attribute :description, :string
      attribute :color, :string, default: "0088CC"
      validates :name, presence: true, length: { maximum: 50 }
      validates :description, length: { maximum: 5000 }
      validates :color, format: { with: /\A[0-9a-fA-F]{6}\z/ }
    end

    policy :approved_teacher
    policy :moderation_enabled

    transaction do
      model :course, :create_resources
      step :log
    end

    private

    def approved_teacher(guardian:)
      Access.can_create?(guardian.user)
    end
    def moderation_enabled
      SiteSetting.enable_category_group_moderation
    end
    def create_resources(params:, guardian:)
      suffix = SecureRandom.hex(6)
      teachers =
        Group.create!(name: "edu_#{suffix}_t", visibility_level: Group.visibility_levels[:members])
      students =
        Group.create!(
          name: "edu_#{suffix}_s",
          visibility_level: Group.visibility_levels[:members],
          public_admission: true,
          public_exit: true,
        )
      teachers.add(guardian.user)
      students.add_owner(guardian.user)
      category =
        Category.new(
          name: params.name,
          color: params.color,
          text_color: "FFFFFF",
          user: guardian.user,
        )
      category.set_permissions(teachers.name => 1, students.name => 1)
      category.custom_fields["enable_accepted_answers"] = true
      category.save!
      CategoryModerationGroup.create!(category: category, group: teachers)
      course =
        Course.create!(
          category: category,
          teacher_group: teachers,
          student_group: students,
          created_by: guardian.user,
          description: params.description,
        )
      Group.refresh_automatic_groups_for_user!(guardian.user)
      course
    end
    def log(guardian:, course:)
      Access.audit(
        guardian.user,
        "course_created",
        course_id: course.id,
        category_id: course.category_id,
      )
    end
  end
end
