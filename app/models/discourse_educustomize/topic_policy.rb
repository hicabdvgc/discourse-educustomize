# frozen_string_literal: true
module DiscourseEducustomize
  class TopicPolicy < ActiveRecord::Base
    self.table_name = "educustomize_topic_policies"
    belongs_to :course
    belongs_to :topic
    belongs_to :ai_agent, class_name: "::AiAgent", optional: true
    belongs_to :reviewer, class_name: "User"
    validates :topic_id, uniqueness: true
  end
end

# == Schema Information
#
# Table name: educustomize_topic_policies
#
#  id             :bigint           not null, primary key
#  auto_reply     :boolean          default(FALSE), not null
#  memory         :boolean          default(FALSE), not null
#  require_review :boolean          default(TRUE), not null
#  revision       :integer          default(1), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  ai_agent_id    :bigint
#  course_id      :bigint           not null
#  reviewer_id    :bigint           not null
#  topic_id       :bigint           not null
#  workflow_id    :bigint
#
# Indexes
#
#  index_educustomize_topic_policies_on_course_id  (course_id)
#  index_educustomize_topic_policies_on_topic_id   (topic_id) UNIQUE
#
