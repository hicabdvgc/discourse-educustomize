# frozen_string_literal: true
class AddEducustomizePublishedPost < ActiveRecord::Migration[8.0]
  def change
    add_column :educustomize_runs, :published_post_id, :bigint
  end
end
