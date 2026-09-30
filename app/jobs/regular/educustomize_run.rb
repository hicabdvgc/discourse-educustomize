# frozen_string_literal: true
module Jobs
  class EducustomizeRun < ::Jobs::Base
    def execute(args)
      run = DiscourseEducustomize::Run.find_by(id: args[:run_id])
      return unless run && run.execution&.pending?
      failed_execution = nil
      DistributedMutex.synchronize("educustomize-run-#{run.id}") do
        return unless run.execution.reload.pending?
        execution = run.execution
        begin
          run.validate_current!
        rescue Discourse::InvalidAccess => error
          execution.update!(
            status: :error,
            error: error.message.to_s.truncate(1000),
            finished_at: Time.current,
            run_time_ms: 0,
          )
          failed_execution = execution
          next
        end
        options =
          ::DiscourseWorkflows::Executor::ExecutionOptions.new(
            user: run.actor,
            existing_execution: execution,
          )
        ::DiscourseWorkflows::Executor.new(
          execution.workflow,
          "manual",
          { "run_id" => run.id },
          options,
        ).run
      end
      if failed_execution
        ::DiscourseWorkflows::ExecutionProgressPublisher.publish(failed_execution, refresh: true)
      end
    end
  end
end
