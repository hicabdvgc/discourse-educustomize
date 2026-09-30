# frozen_string_literal: true
module DiscourseEducustomize
  class Run < ActiveRecord::Base
    self.table_name = "educustomize_runs"
    belongs_to :topic_policy
    belongs_to :post
    belongs_to :actor, class_name: "User"
    belongs_to :execution, class_name: "DiscourseWorkflows::Execution", optional: true
    belongs_to :published_post, class_name: "Post", optional: true

    def execution_status
      execution&.status || (execution_id ? "unavailable" : "pending")
    end
    def validate_current!
      policy = topic_policy.reload
      course = policy.course
      unless SiteSetting.educustomize_enabled && !superseded &&
               policy.topic.category_id == course.category_id && post.topic_id == policy.topic_id &&
               Access.teacher?(actor, course) && Access.teacher?(policy.reviewer, course) &&
               policy.reviewer.in_any_groups?([course.teacher_group_id]) &&
               actor.guardian.can_see?(post) && policy.reviewer.guardian.can_see?(post) &&
               AiConfiguration.ready?(policy) &&
               configuration_digest == AiConfiguration.digest(policy) &&
               Access.ids(:educustomize_workflow_ids).include?(policy.workflow_id)
        raise Discourse::InvalidAccess
      end
      workflow = DiscourseWorkflows::Workflow.find_by(id: policy.workflow_id)
      raise Discourse::InvalidAccess unless WorkflowTemplate.valid?(workflow)
      true
    end
    def draft
      data = execution&.execution_data&.context_data
      data&.dig("Edit", 0, "json", "draft") || data&.dig("Generate", 0, "json", "draft")
    end

    def outcome
      return "superseded" if superseded
      return "published" if published_post_id
      if execution&.execution_data&.context_data&.dig("Review", 0, "json", "button") == "reject"
        "rejected"
      end
    end
  end
end

# == Schema Information
#
# Table name: educustomize_runs
#
#  id                   :bigint           not null, primary key
#  configuration_digest :string           not null
#  request_key          :string           not null
#  superseded           :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  actor_id             :bigint           not null
#  execution_id         :bigint
#  post_id              :bigint           not null
#  published_post_id    :bigint
#  topic_policy_id      :bigint           not null
#
# Indexes
#
#  index_educustomize_runs_on_execution_id                     (execution_id) UNIQUE
#  index_educustomize_runs_on_topic_policy_id_and_request_key  (topic_policy_id,request_key) UNIQUE
#
