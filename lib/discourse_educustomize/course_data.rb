# frozen_string_literal: true

module DiscourseEducustomize
  class CourseData
    attr_reader :course, :guardian

    def initialize(course, guardian)
      @course = course
      @guardian = guardian
      Access.ensure_teacher!(guardian.user, course)
    end

    def topics
      Topic
        .secured(guardian)
        .where(category_id: course.category_id, archetype: Archetype.default)
        .where(deleted_at: nil)
        .order(:id)
    end

    def posts
      records =
        Post
          .secured(guardian)
          .where(topic_id: topics.reorder(nil).select(:id))
          .where(post_type: Post.types[:regular])
      guardian.filter_hidden_posts(records, category: course.category)
    end

    def topic_options
      topics.select(:id, :title).map { |topic| { id: topic.id, title: topic.title } }
    end

    def ensure_topic!(topic_id)
      return if topic_id.blank?
      topic = topics.find(topic_id)
      guardian.ensure_can_see!(topic)
    end

    def runs
      Run
        .joins(:topic_policy)
        .where(
          educustomize_topic_policies: {
            course_id: course.id,
            topic_id: topics.reorder(nil).select(:id),
          },
        )
        .where(post_id: posts.select(:id))
    end

    def self.retention
      {
        workflow_days: SiteSetting.workflow_executions_retention_days,
        ai_days: SiteSetting.ai_audit_logs_purge_after_days,
      }
    end
  end
end
