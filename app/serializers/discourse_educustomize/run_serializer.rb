# frozen_string_literal: true

module DiscourseEducustomize
  class RunSerializer < ApplicationSerializer
    attributes :id,
               :post_id,
               :status,
               :outcome,
               :draft,
               :published_post_id,
               :superseded,
               :can_review,
               :can_regenerate,
               :topic_id,
               :topic_title,
               :created_at,
               :review_url

    def status
      object.execution_status
    end

    def topic_id
      object.topic_policy.topic_id
    end

    def topic_title
      object.topic_policy.topic.title
    end

    def review_url
      "/educustomize/topics/#{topic_id}?run_id=#{object.id}#run-#{object.id}"
    end

    def published_post_id
      post = object.published_post
      post.id if post && scope.can_see?(post)
    end

    def can_review
      scope.user.id == object.topic_policy.reviewer_id && !object.superseded &&
        object.execution&.waiting?
    end

    def can_regenerate
      scope.user.id == object.topic_policy.reviewer_id && !object.superseded && object.execution &&
        !object.execution.pending? && !object.execution.running?
    end
  end
end
