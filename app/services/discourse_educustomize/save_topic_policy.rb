# frozen_string_literal: true
module DiscourseEducustomize
  class SaveTopicPolicy
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :ai_agent_id, :integer
      attribute :workflow_id, :integer
      attribute :reviewer_id, :integer
      attribute :auto_reply, :boolean, default: false
      attribute :memory, :boolean, default: false
      attribute :require_review, :boolean, default: true
      validates :topic_id, presence: true
    end

    model :topic
    model :course
    policy :course_teacher
    policy :references_authorized

    transaction do
      model :topic_policy, :save_topic_policy
      step :log
    end

    private

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end
    def fetch_course(topic:)
      Course.find_by(category_id: topic.category_id)
    end
    def course_teacher(guardian:, course:, topic:)
      Access.teacher?(guardian.user, course) && guardian.can_see?(topic)
    end
    def references_authorized(params:, course:, guardian:)
      reviewer = User.find_by(id: params.reviewer_id || guardian.user.id)
      return false unless reviewer && reviewer.in_any_groups?([course.teacher_group_id])
      if params.ai_agent_id && !course.agent_links.exists?(ai_agent_id: params.ai_agent_id)
        return false
      end
      if params.workflow_id && !Access.ids(:educustomize_workflow_ids).include?(params.workflow_id)
        return false
      end
      !params.workflow_id ||
        WorkflowTemplate.valid?(DiscourseWorkflows::Workflow.find_by(id: params.workflow_id))
    end
    def save_topic_policy(params:, course:, topic:, guardian:)
      policy = TopicPolicy.find_or_initialize_by(topic_id: topic.id)
      policy.assign_attributes(
        course: course,
        ai_agent_id: params.ai_agent_id,
        workflow_id: params.workflow_id,
        reviewer_id: params.reviewer_id || guardian.user.id,
        auto_reply: params.auto_reply,
        memory: params.memory,
        require_review: params.require_review,
      )
      policy.revision = policy.revision.to_i + 1
      policy.save!
      policy
    end
    def log(guardian:, topic_policy:)
      Access.audit(
        guardian.user,
        "topic_policy_saved",
        topic_id: topic_policy.topic_id,
        revision: topic_policy.revision,
      )
    end
  end
end
