# frozen_string_literal: true
module DiscourseEducustomize
  class Course < ActiveRecord::Base
    self.table_name = "educustomize_courses"
    belongs_to :category
    belongs_to :teacher_group, class_name: "Group"
    belongs_to :student_group, class_name: "Group"
    belongs_to :created_by, class_name: "User"
    has_many :agent_links, dependent: :destroy
    validates :category_id, uniqueness: true
  end
end

# == Schema Information
#
# Table name: educustomize_courses
#
#  id               :bigint           not null, primary key
#  description      :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  category_id      :bigint           not null
#  created_by_id    :bigint           not null
#  student_group_id :bigint           not null
#  teacher_group_id :bigint           not null
#
# Indexes
#
#  index_educustomize_courses_on_category_id  (category_id) UNIQUE
#
