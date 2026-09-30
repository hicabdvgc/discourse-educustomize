# frozen_string_literal: true
module DiscourseEducustomize
  class RunsController < BaseController
    before_action :authorize_policy
    def index
      runs =
        Run
          .includes(:published_post, topic_policy: :topic, execution: :execution_data)
          .where(topic_policy: @policy)
          .order(id: :desc)
          .limit(50)
      runs = runs.to_a
      if params[:run_id].present?
        selected = @policy_runs.find(params[:run_id])
        guardian.ensure_can_see!(selected.post)
        runs.unshift(selected) unless runs.any? { |run| run.id == selected.id }
      end
      render json: { runs: runs.map { |run| present(run) } }
    end
    def create
      raise Discourse::InvalidAccess unless AiConfiguration.ready?(@policy)
      post = Post.find(params.require(:post_id))
      unless post.topic_id == @policy.topic_id && post.post_type == Post.types[:regular] &&
               post.user.in_any_groups?([@policy.course.student_group_id]) &&
               guardian.can_see?(post)
        raise Discourse::InvalidAccess
      end
      key = params.require(:request_key).to_s
      unless key.match?(/\A[a-zA-Z0-9-]{10,80}\z/)
        raise Discourse::InvalidParameters.new(:request_key)
      end
      run =
        Run.find_or_create_by!(topic_policy: @policy, request_key: key) do |record|
          record.post = post
          record.actor = current_user
          record.configuration_digest = AiConfiguration.digest(@policy)
        end
      run.with_lock do
        if run.execution_id.nil?
          run.validate_current!
          execution =
            DiscourseWorkflows::Execution.create_pending_manual!(
              workflow: DiscourseWorkflows::Workflow.find(@policy.workflow_id),
              trigger_node_id: "manual",
              trigger_data: {
                "run_id" => run.id,
              },
            )
          run.update!(execution_id: execution.id)
        end
      end
      Jobs.enqueue(:educustomize_run, run_id: run.id)
      Access.audit(current_user, "reply_requested", run_id: run.id)
      render json: { run: present(run) }, status: :created
    end
    def update
      run = @policy_runs.find(params[:id])
      raise Discourse::InvalidAccess unless @policy.reviewer_id == current_user.id
      run.validate_current!
      action = params.require(:decision)
      if %w[approve reject regenerate].exclude?(action)
        raise Discourse::InvalidParameters.new(:decision)
      end
      execution = run.execution
      if action == "regenerate"
        run.update!(superseded: true)
        Access.audit(current_user, "reply_superseded", run_id: run.id)
        return head :no_content
      end
      if execution&.waiting?
        if execution.waiting_node_id == "edit"
          draft = params.require(:draft).to_s
          if draft.blank? || draft.length > SiteSetting.max_post_length
            raise Discourse::InvalidParameters.new(:draft)
          end
          signature =
            DiscourseWorkflows::WaitingExecution.resume_signature(
              execution_id: execution.id,
              resume_token: execution.resume_token,
            )
          DiscourseWorkflows::WaitingWebhookRunner.call(
            execution_id: execution.id,
            signature: signature,
            http_method: "POST",
            path: "",
            node_type: "form",
            params: {
              form_data: {
                draft: draft,
              },
            },
            service_params: service_params,
          )
          execution.reload
        end
        if execution.waiting? && execution.waiting_node_id == "review"
          token =
            DiscourseWorkflows::InteractiveResume.action_id(
              execution_id: execution.id,
              resume_token: execution.resume_token,
              action: action,
              target_user_id: current_user.id,
            )
          DiscourseWorkflows::Modal::Respond.call(
            guardian: guardian,
            params: {
              action_id: token,
              modal_id: review_modal_id(token),
            },
          )
        end
      end
      Access.audit(current_user, "reply_#{action}", run_id: run.id)
      render json: { run: present(run.reload) }
    end

    private

    def review_modal_id(action_id)
      # The native modal exists in the user's MessageBus backlog. Match the exact
      # signed action so completing this review closes its copies in every tab.
      channel = DiscourseWorkflows::Nodes::Modal::V1.user_channel(current_user.id)
      message =
        MessageBus
          .backlog(channel, 0)
          .reverse
          .find do |entry|
            data = entry.data.with_indifferent_access
            data[:type] == "show_modal" &&
              Array(data[:buttons]).any? { |button| button["action_id"] == action_id }
          end
      message&.data&.with_indifferent_access&.dig(:modal_id)
    end

    def authorize_policy
      @policy = TopicPolicy.find_by!(topic_id: params[:topic_id])
      Access.ensure_teacher!(current_user, @policy.course)
      guardian.ensure_can_see!(@policy.topic)
      raise Discourse::InvalidAccess unless @policy.topic.category_id == @policy.course.category_id
      @policy_runs = Run.where(topic_policy: @policy)
    end
    def present(run)
      RunSerializer.new(run, scope: guardian, root: false).as_json
    end
  end
end
