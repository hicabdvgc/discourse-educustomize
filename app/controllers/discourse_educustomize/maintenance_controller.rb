# frozen_string_literal: true

module DiscourseEducustomize
  class MaintenanceController < BaseController
    before_action :authorize_course

    def show
      respond_to do |format|
        format.html { render "default/empty" }
        format.json { render json: MaintenanceSummary.new(@data).result }
      end
    end

    def runs
      result = CourseRuns.new(@data, params.permit(:topic_id, :status, :outcome, :page)).result
      render json: result.merge(runs: serialize_data(result[:runs], RunSerializer))
    end

    private

    def authorize_course
      @course = find_course
      @data = CourseData.new(@course, guardian)
    end
  end
end
