# frozen_string_literal: true
module DiscourseEducustomize
  module Nodes
    class Publish < DiscourseWorkflows::Nodes::Post::V1
      description(
        **DiscourseWorkflows::Nodes::Post::V1.description.merge(
          name: "action:educustomize_publish",
        ),
      )
      def execute(exec_ctx)
        run = Run.find_by!(execution_id: exec_ctx.execution_id)
        run.with_lock do
          run.validate_current!
          policy = run.topic_policy
          if policy.require_review
            raise Discourse::InvalidAccess unless exec_ctx.user&.id == policy.reviewer_id
          end
          if run.published_post_id
            [[wrap({ "post" => { "id" => run.published_post_id } })]]
          else
            output = super
            post_id = output.dig(0, 0, "json", "post", "id") || output.dig(0, 0, :json, :post, :id)
            raise "Native post node did not return a post ID" unless post_id
            run.update!(published_post_id: post_id)
            Access.audit(
              policy.reviewer,
              "reply_published",
              run_id: run.id,
              post_id: post_id,
              requested_by_id: run.actor_id,
            )
            output
          end
        end
      end
    end
  end
end
