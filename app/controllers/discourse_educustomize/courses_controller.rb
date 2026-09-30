# frozen_string_literal: true
module DiscourseEducustomize
  class CoursesController < BaseController
    def index
      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          teaching = TeachingFeatures.status
          render json: {
                   courses:
                     Course.includes(:category, :student_group).order(:id).map { course_json(_1) },
                   can_create: Access.can_create?(current_user),
                   dependencies: Access.dependencies,
                   teacher_application_url:
                     (
                       if teaching[:teacher_requests_ready]
                         teaching[:teacher_group_url]
                       else
                         nil
                       end
                     ),
                 }
        end
      end
    end
    def show
      course = find_course
      Access.ensure_teacher!(current_user, course)
      respond_to do |format|
        format.html { render "default/empty" }
        format.json { render json: { course: course_json(course) } }
      end
    end
    def create
      CreateCourse.call(service_params.deep_merge(params: course_params.to_h)) do
        on_success { |course:| render json: { course: course_json(course) }, status: :created }
        on_failed_policy(:approved_teacher) { raise Discourse::InvalidAccess }
        on_failed_policy(:moderation_enabled) do
          render_json_error I18n.t("educustomize.moderation_required"), status: 422
        end
        on_failed_contract do |contract|
          render_json_error contract.errors.full_messages, status: 400
        end
        on_failure { render_json_error I18n.t("educustomize.invalid"), status: 422 }
      end
    end
    def update
      UpdateCourse.call(
        service_params.deep_merge(params: course_params.to_h.merge(course_id: params[:id])),
      ) do
        on_success { |course:| render json: { course: course_json(course) } }
        on_model_not_found(:course) { raise Discourse::NotFound }
        on_failed_policy(:course_teacher) { raise Discourse::InvalidAccess }
        on_failed_policy(:owns_images) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render_json_error contract.errors.full_messages, status: 400
        end
        on_failure { render_json_error I18n.t("educustomize.invalid"), status: 422 }
      end
    end
    def join
      course = find_course
      raise Discourse::InvalidAccess unless course.student_group.public_admission
      course.student_group.add(current_user)
      Access.audit(current_user, "course_joined", course_id: course.id)
      render json: { course: course_json(course) }
    end

    private

    def course_params
      params.require(:course).permit(
        :name,
        :description,
        :color,
        :uploaded_logo_id,
        :uploaded_background_id,
      )
    end
  end
end
