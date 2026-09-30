# frozen_string_literal: true
module DiscourseEducustomize
  class UpdateCourse
    include Service::Base

    params do
      attribute :course_id, :integer
      attribute :name, :string
      attribute :description, :string
      attribute :color, :string
      attribute :uploaded_logo_id, :integer
      attribute :uploaded_background_id, :integer
      validates :course_id, :name, presence: true
      validates :name, length: { maximum: 50 }
      validates :description, length: { maximum: 5000 }
      validates :color, format: { with: /\A[0-9a-fA-F]{6}\z/ }
    end

    model :course
    policy :course_teacher
    policy :owns_images

    transaction do
      step :update
      step :log
    end

    private

    def fetch_course(params:)
      Course.find_by(id: params.course_id)
    end
    def course_teacher(guardian:, course:)
      Access.teacher?(guardian.user, course)
    end
    def owns_images(params:, guardian:, course:)
      ids = [params.uploaded_logo_id, params.uploaded_background_id].compact
      existing = [course.category.uploaded_logo_id, course.category.uploaded_background_id].compact
      (ids - existing - Upload.where(user_id: guardian.user.id, id: ids).pluck(:id)).empty?
    end
    def update(params:, course:)
      course.update!(description: params.description)
      course.category.update!(
        name: params.name,
        color: params.color,
        uploaded_logo_id: params.uploaded_logo_id,
        uploaded_background_id: params.uploaded_background_id,
      )
    end
    def log(guardian:, course:)
      Access.audit(guardian.user, "course_updated", course_id: course.id)
    end
  end
end
