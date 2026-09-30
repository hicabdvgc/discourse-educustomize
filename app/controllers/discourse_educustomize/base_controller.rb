# frozen_string_literal: true
module DiscourseEducustomize
  class BaseController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in
    before_action :limit_writes
    rescue_from ActiveRecord::RecordInvalid do |error|
      render_json_error(error.record, status: :unprocessable_entity)
    end

    private

    def limit_writes
      unless request.get?
        RateLimiter.new(current_user, "educustomize-write", 60, 1.minute).performed!
      end
    end
    def find_course
      Course.includes(:category, :teacher_group, :student_group).find(
        params[:course_id] || params[:id],
      )
    end
    def course_json(course)
      CourseSerializer.new(course, scope: guardian, root: false).as_json
    end
  end
end
