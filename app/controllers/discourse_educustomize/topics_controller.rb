# frozen_string_literal: true
module DiscourseEducustomize
  class TopicsController < BaseController
    before_action :authorize_topic
    def show
      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          policy = TopicPolicy.find_by(topic_id: @topic.id)
          render json: {
                   topic_id: @topic.id,
                   title: @topic.title,
                   course_id: @course.id,
                   policy_id: policy&.id,
                   policy:
                     policy&.attributes&.slice(
                       "ai_agent_id",
                       "workflow_id",
                       "reviewer_id",
                       "auto_reply",
                       "memory",
                       "require_review",
                     ) ||
                       {
                         reviewer_id: current_user.id,
                         auto_reply: false,
                         memory: false,
                         require_review: true,
                       },
                   agents:
                     @course
                       .agent_links
                       .includes(:ai_agent)
                       .map { { id: _1.ai_agent_id, name: _1.ai_agent.name } },
                   reviewers:
                     @course
                       .teacher_group
                       .users
                       .pluck(:id, :username)
                       .map { |id, name| { id: id, name: name } },
                   ready: policy && AiConfiguration.ready?(policy),
                   readiness_reasons: policy ? AiConfiguration.reasons(policy) : [],
                   workflows:
                     DiscourseWorkflows::Workflow
                       .where(id: Access.ids(:educustomize_workflow_ids))
                       .select { WorkflowTemplate.valid?(_1) }
                       .map { { id: _1.id, name: _1.name } },
                   posts:
                     @topic
                       .posts
                       .where(
                         user_id: @course.student_group.users.select(:id),
                         post_type: Post.types[:regular],
                       )
                       .order(:post_number)
                       .limit(200)
                       .map { { id: _1.id, name: "##{_1.post_number} #{_1.user.username}" } },
                 }
        end
      end
    end
    def update
      permitted =
        params.require(:policy).permit(
          :ai_agent_id,
          :workflow_id,
          :reviewer_id,
          :auto_reply,
          :memory,
          :require_review,
        )
      SaveTopicPolicy.call(
        service_params.deep_merge(params: permitted.to_h.merge(topic_id: @topic.id)),
      ) do
        on_success { head :no_content }
        on_failed_policy(:course_teacher) { raise Discourse::InvalidAccess }
        on_failed_policy(:references_authorized) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render_json_error contract.errors.full_messages, status: 400
        end
        on_failure { render_json_error I18n.t("educustomize.invalid"), status: 422 }
      end
    end

    private

    def authorize_topic
      @topic = Topic.find(params[:topic_id])
      @course = Course.find_by!(category_id: @topic.category_id)
      Access.ensure_teacher!(current_user, @course)
      guardian.ensure_can_see!(@topic)
    end
  end
end
