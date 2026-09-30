# frozen_string_literal: true

module DiscourseEducustomize
  module ScopedAuditAttribution
    def reply(context, llm_args: {}, **kwargs, &block)
      run_id = context.feature_context["educustomize_run_id"]
      if run_id
        run = Run.find(run_id)
        run.validate_current!
        unless run.topic_policy.course.agent_links.exists?(ai_agent_id: agent.id)
          raise Discourse::InvalidAccess
        end
        context.topic_id = run.topic_policy.topic_id
        context.post_id = run.post_id
        context.feature_context =
          context.feature_context.merge(
            "educustomize_course_id" => run.topic_policy.course_id,
            "educustomize_agent_id" => agent.id,
          )
        llm_args =
          llm_args.merge(
            feature_context: llm_args[:feature_context].to_h.merge(context.feature_context),
          )
      end
      super(context, llm_args: llm_args, **kwargs, &block)
    end
  end
end
