# frozen_string_literal: true
module DiscourseEducustomize
  class AgentLink < ActiveRecord::Base
    self.table_name = "educustomize_agent_links"
    belongs_to :course
    belongs_to :ai_agent, class_name: "::AiAgent"
    validates :ai_agent_id, uniqueness: true
  end
end

# == Schema Information
#
# Table name: educustomize_agent_links
#
#  id          :bigint           not null, primary key
#  prompt      :text
#  skills      :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  ai_agent_id :bigint           not null
#  course_id   :bigint           not null
#
# Indexes
#
#  index_educustomize_agent_links_on_ai_agent_id  (ai_agent_id) UNIQUE
#  index_educustomize_agent_links_on_course_id    (course_id)
#
