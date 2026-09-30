# frozen_string_literal: true
class CreateEducustomizeResources < ActiveRecord::Migration[8.0]
  def change
    create_table :educustomize_courses do |t|
      t.bigint :category_id, null: false
      t.bigint :teacher_group_id, null: false
      t.bigint :student_group_id, null: false
      t.bigint :created_by_id, null: false
      t.text :description
      t.timestamps
    end
    add_index :educustomize_courses, :category_id, unique: true
    create_table :educustomize_agent_links do |t|
      t.bigint :course_id, null: false
      t.bigint :ai_agent_id, null: false
      t.timestamps
    end
    add_index :educustomize_agent_links, :ai_agent_id, unique: true
    add_index :educustomize_agent_links, :course_id
    create_table :educustomize_topic_policies do |t|
      t.bigint :course_id, null: false
      t.bigint :topic_id, null: false
      t.bigint :ai_agent_id
      t.bigint :workflow_id
      t.bigint :reviewer_id, null: false
      t.boolean :auto_reply, null: false, default: false
      t.boolean :memory, null: false, default: false
      t.boolean :require_review, null: false, default: true
      t.integer :revision, null: false, default: 1
      t.timestamps
    end
    add_index :educustomize_topic_policies, :topic_id, unique: true
    add_index :educustomize_topic_policies, :course_id
    create_table :educustomize_runs do |t|
      t.bigint :topic_policy_id, null: false
      t.bigint :post_id, null: false
      t.bigint :actor_id, null: false
      t.bigint :execution_id
      t.string :configuration_digest, null: false
      t.string :request_key, null: false
      t.boolean :superseded, null: false, default: false
      t.timestamps
    end
    add_index :educustomize_runs, %i[topic_policy_id request_key], unique: true
    add_index :educustomize_runs, :execution_id, unique: true
  end
end
