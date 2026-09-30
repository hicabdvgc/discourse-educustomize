# frozen_string_literal: true

module DiscourseEducustomize
  class CourseRuns
    PAGE_SIZE = 25

    def initialize(data, params)
      @data = data
      @params = params
    end

    def result
      @data.ensure_topic!(@params[:topic_id])
      page = Integer(@params[:page].presence || 1, exception: false)
      raise Discourse::InvalidParameters.new(:page) unless page && page.between?(1, 10_000)
      scope = @data.runs.left_joins(execution: :execution_data)
      scope = scope.where(educustomize_topic_policies: { topic_id: @params[:topic_id] }) if @params[
        :topic_id
      ].present?
      if @params[:status].present?
        status = @params[:status]
        if status == "unavailable"
          scope =
            scope.where.not(execution_id: nil).where(discourse_workflows_executions: { id: nil })
        elsif DiscourseWorkflows::Execution.statuses.key?(status)
          scope =
            if status == "pending"
              scope.where(
                "educustomize_runs.execution_id IS NULL OR discourse_workflows_executions.status = ?",
                DiscourseWorkflows::Execution.statuses[status],
              )
            else
              scope.where(
                discourse_workflows_executions: {
                  status: DiscourseWorkflows::Execution.statuses[status],
                },
              )
            end
        else
          raise Discourse::InvalidParameters.new(:status)
        end
      end
      if @params[:outcome].present?
        scope =
          case @params[:outcome]
          when "superseded"
            scope.where(superseded: true)
          when "published"
            scope.where(superseded: false).where.not(published_post_id: nil)
          when "rejected"
            scope.where(superseded: false, published_post_id: nil).where(
              "discourse_workflows_execution_data.data #>> '{context,Review,0,json,button}' = 'reject'",
            )
          else
            raise Discourse::InvalidParameters.new(:outcome)
          end
      end
      records =
        scope
          .includes(:published_post, :post, topic_policy: :topic, execution: :execution_data)
          .order(id: :desc)
          .offset((page - 1) * PAGE_SIZE)
          .limit(PAGE_SIZE + 1)
          .to_a
      { runs: records.first(PAGE_SIZE), has_more: records.size > PAGE_SIZE, page: page }
    end
  end
end
