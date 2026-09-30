# frozen_string_literal: true
module DiscourseEducustomize
  module Nodes
    class Generate < DiscourseWorkflows::NodeType
      description(
        name: "action:educustomize_generate",
        version: "1.0",
        defaults: {
          icon: "robot",
        },
        properties: {
        },
      )
      def execute(exec_ctx)
        execution = DiscourseWorkflows::Execution.find(exec_ctx.execution_id)
        run = resolve_run(execution)
        return [[]] unless run
        run.update!(execution_id: execution.id) if run.execution_id.nil?
        run.validate_current!
        policy = run.topic_policy
        posts =
          if policy.memory
            policy
              .topic
              .posts
              .where(post_type: Post.types[:regular])
              .order(:post_number)
              .to_a
              .select { policy.reviewer.guardian.can_see?(_1) }
          else
            [run.post]
          end
        agent = policy.ai_agent
        bot =
          DiscourseAi::Agents::Bot.as(
            policy.reviewer,
            agent: agent.class_instance.new,
            model: agent.default_llm,
          )
        context =
          DiscourseAi::Agents::BotContext.new(
            post: run.post,
            user: policy.reviewer,
            guardian: policy.reviewer.guardian,
            messages: discussion_messages(posts, run.post, memory: policy.memory),
            feature_name: "workflow",
            feature_context: {
              "educustomize_run_id" => run.id,
            },
          )
        replies = bot.reply(context)
        # Native Bot stores tool traffic separately and adds the completed answer last.
        draft = replies.reverse.find { |reply| reply[2].nil? }&.first
        raise_node_error!(I18n.t("educustomize.empty_reply")) if draft.blank?
        run.validate_current!
        [
          [
            wrap(
              {
                "run_id" => run.id,
                "draft" => draft,
                "topic_id" => policy.topic_id,
                "post_number" => run.post.post_number,
                "reviewer" => policy.reviewer.username,
                "require_review" => policy.require_review,
                "review_url" => "#{Discourse.base_url}/educustomize/topics/#{policy.topic_id}",
              },
            ),
          ],
        ]
      end

      private

      def discussion_messages(posts, selected_post, memory:)
        messages = []
        if memory
          # Preserve individual turns so native context compression can summarize history.
          posts
            .reject { |post| post.id == selected_post.id }
            .each do |post|
              messages << {
                type: :user,
                content:
                  "Discussion reference, Post ##{post.post_number}, #{post.user.username}:\n#{post.raw}",
              }
            end
        end
        messages << {
          type: :user,
          content:
            "Reply to this selected post by #{selected_post.user.username}:\n#{selected_post.raw}",
        }
        messages
      end

      def resolve_run(execution)
        if execution.trigger_node_id == "manual"
          run = Run.find_by(id: execution.trigger_data["run_id"])
          return unless run && run.topic_policy.workflow_id == execution.workflow_id
          return if run.execution_id && run.execution_id != execution.id
          run
        else
          post = Post.find_by(id: execution.trigger_data.dig("post", "id"))
          unless post && post.post_type == Post.types[:regular] && post.user_id.positive? &&
                   !post.user.staged? && !post.user.bot?
            return
          end
          policy =
            TopicPolicy.find_by(
              topic_id: post.topic_id,
              auto_reply: true,
              workflow_id: execution.workflow_id,
            )
          unless policy && post.user.in_any_groups?([policy.course.student_group_id]) &&
                   !Access.teacher?(post.user, policy.course)
            return
          end
          Run
            .find_or_create_by!(topic_policy: policy, request_key: "post-#{post.id}") do |record|
              record.post = post
              record.actor = policy.reviewer
              record.configuration_digest = AiConfiguration.digest(policy)
            end
            .then { |run| run.execution_id.nil? || run.execution_id == execution.id ? run : nil }
        end
      end
    end
  end
end
