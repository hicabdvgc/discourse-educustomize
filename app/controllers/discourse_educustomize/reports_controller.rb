# frozen_string_literal: true

module DiscourseEducustomize
  class ReportsController < BaseController
    before_action :authorize_course
    before_action :ensure_explorer, only: %i[preview download]
    skip_before_action :check_xhr, only: :download

    rescue_from ReportRunner::LimitExceeded do
      render_json_error I18n.t("educustomize.export_limit"), status: 422
    end
    rescue_from ActiveRecord::StatementInvalid, PG::Error do |error|
      Rails.logger.warn("educustomize report query failed: #{error.class}")
      render_json_error I18n.t("educustomize.report_failed"), status: 422
    end

    def index
      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          render json: {
                   course: {
                     id: @course.id,
                     name: @course.category.name,
                   },
                   available: ReportRunner.available?,
                   reports:
                     ReportQuery::GROUPS.map { |key, group|
                       { key: key, group: group, columns: ReportQuery::COLUMNS.fetch(key) }
                     },
                   topics: @data.topic_options,
                   retention: CourseData.retention,
                 }
        end
      end
    end

    def preview
      render json: runner.preview
    end

    def download
      format = params[:file_format].presence || request.format.symbol.to_s
      raise Discourse::InvalidParameters.new(:file_format) if %w[csv json].exclude?(format)
      output = runner.download(format.to_sym)
      send_data(
        format == "json" ? JSON.generate(output) : output,
        filename: "course-#{@course.id}-#{params[:key]}-#{Date.current}.#{format}",
        type: format == "csv" ? "text/csv; charset=utf-8" : "application/json",
      )
    end

    private

    def authorize_course
      @course = find_course
      @data = CourseData.new(@course, guardian)
    end

    def ensure_explorer
      unless ReportRunner.available?
        render_json_error I18n.t("educustomize.explorer_required"), status: 422
      end
    end

    def runner
      ReportRunner.new(
        @data,
        params[:key],
        params.permit(:topic_id, :start_date, :end_date, :timezone).to_h,
      )
    end
  end
end
