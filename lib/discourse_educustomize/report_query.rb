# frozen_string_literal: true

module DiscourseEducustomize
  class ReportQuery
    COLUMNS = {
      "discussions" => %w[
        course_id
        course_name
        topic_id
        topic_title
        post_id
        post_number
        user_id
        username
        text
        created_at_utc
        updated_at_utc
        reply_to_post_number
        ai_run_id
      ],
      "participation" => %w[
        course_id
        course_name
        user_id
        username
        post_count
        reply_count
        topic_count
        first_post_at_utc
        last_post_at_utc
      ],
      "reviews" => %w[
        course_id
        course_name
        topic_id
        source_post_id
        student_user_id
        student_username
        actor_id
        actor_username
        run_id
        execution_id
        created_at_utc
        original_draft
        edited_draft
        reviewer_username
        execution_status
        outcome
        superseded
        published_post_id
        published_text
      ],
      "usage" => %w[
        course_id
        course_name
        log_id
        run_id
        topic_id
        source_post_id
        agent_id
        parent_agent_id
        subagent_depth
        feature_name
        llm_id
        language_model
        created_at_utc
        request_tokens
        response_tokens
        cache_read_tokens
        cache_write_tokens
        duration_msecs
        response_status
        outcome
        estimated_cost
      ],
      "usage_summary" => %w[
        course_id
        course_name
        llm_id
        language_model
        call_count
        success_count
        failure_count
        request_tokens
        response_tokens
        cache_read_tokens
        cache_write_tokens
        estimated_cost
        missing_cost_count
      ],
      "polls" => %w[
        course_id
        course_name
        topic_id
        post_id
        poll_id
        poll_name
        poll_title
        poll_type
        option_id
        option_html
        vote_count
        status
        created_at_utc
      ],
      "poll_votes" => %w[
        course_id
        course_name
        topic_id
        post_id
        poll_id
        poll_name
        poll_type
        option_id
        option_html
        user_id
        username
      ],
      "feedback" => %w[
        course_id
        course_name
        topic_id
        topic_title
        post_id
        post_number
        user_id
        username
        text
        created_at_utc
        updated_at_utc
        reply_to_post_number
        ai_run_id
      ],
    }.freeze
    GROUPS = {
      "discussions" => "discussion",
      "participation" => "discussion",
      "reviews" => "review",
      "usage" => "usage",
      "usage_summary" => "usage",
      "polls" => "feedback",
      "poll_votes" => "feedback",
      "feedback" => "feedback",
    }.freeze

    attr_reader :data, :key, :filters

    def initialize(data, key, filters)
      @data = data
      @key = key.to_s
      raise Discourse::InvalidParameters.new(:report) unless GROUPS.key?(@key)
      @filters = filters.to_h.symbolize_keys
      data.ensure_topic!(@filters[:topic_id])
      @timezone = ActiveSupport::TimeZone[@filters[:timezone].presence || "UTC"]
      raise Discourse::InvalidParameters.new(:timezone) unless @timezone
      @start = boundary(:start_date, 29.days.ago.in_time_zone(@timezone).to_date)
      @finish = boundary(:end_date, Time.current.in_time_zone(@timezone).to_date) + 1.day
      raise Discourse::InvalidParameters.new(:end_date) if @finish <= @start
    end

    def query
      DiscourseDataExplorer::Query.new(
        name: "educustomize_#{key}",
        sql: "-- [params]\n-- current_user_id :viewer\n" + sql,
      )
    end

    def sql
      <<~SQL
        WITH visible_posts AS (#{data.posts.to_sql}),
        eligible_runs AS (
          SELECT r.* FROM educustomize_runs r
          JOIN educustomize_topic_policies policy ON policy.id = r.topic_policy_id
          JOIN visible_posts source ON source.id = r.post_id AND source.topic_id = policy.topic_id
          WHERE policy.course_id = #{data.course.id.to_i}
        )
        #{body}
      SQL
    end

    private

    def boundary(name, default)
      date = filters[name].present? ? Date.iso8601(filters[name].to_s) : default
      @timezone.local(date.year, date.month, date.day)
    rescue ArgumentError
      raise Discourse::InvalidParameters.new(name)
    end

    def quote(value)
      ActiveRecord::Base.connection.quote(value)
    end

    def utc(column)
      "to_char(#{column}, 'YYYY-MM-DD\"T\"HH24:MI:SS.US\"Z\"')"
    end

    def range(column, topic_column = "p.topic_id")
      clauses = [
        ":viewer = #{data.guardian.user.id.to_i}",
        "#{column} >= #{quote(@start.utc)}",
        "#{column} < #{quote(@finish.utc)}",
      ]
      clauses << "#{topic_column} = #{Integer(filters[:topic_id])}" if filters[:topic_id].present?
      clauses.join(" AND ")
    end

    def common
      "#{data.course.id.to_i} AS course_id, #{quote(data.course.category.name)} AS course_name"
    end

    def body
      case key
      when "discussions", "feedback"
        <<~SQL
          SELECT #{common}, p.topic_id, t.title AS topic_title, p.id AS post_id,
            p.post_number, p.user_id, u.username, p.raw AS text,
            #{utc("p.created_at")} AS created_at_utc, #{utc("p.updated_at")} AS updated_at_utc,
            p.reply_to_post_number, r.id AS ai_run_id
          FROM visible_posts p JOIN topics t ON t.id = p.topic_id
          LEFT JOIN users u ON u.id = p.user_id
          LEFT JOIN eligible_runs r ON r.published_post_id = p.id
          WHERE #{range("p.created_at")}
          ORDER BY p.created_at, p.id
        SQL
      when "participation"
        <<~SQL
          SELECT #{common}, p.user_id, u.username, COUNT(*) AS post_count,
            COUNT(*) FILTER (WHERE p.post_number > 1) AS reply_count,
            COUNT(DISTINCT p.topic_id) AS topic_count,
            #{utc("MIN(p.created_at)")} AS first_post_at_utc,
            #{utc("MAX(p.created_at)")} AS last_post_at_utc
          FROM visible_posts p LEFT JOIN users u ON u.id = p.user_id
          WHERE #{range("p.created_at")}
          GROUP BY p.user_id, u.username ORDER BY p.user_id
        SQL
      when "reviews"
        <<~SQL
          SELECT #{common}, p.topic_id, r.post_id AS source_post_id,
            p.user_id AS student_user_id, student.username AS student_username,
            r.actor_id, actor.username AS actor_username, r.id AS run_id, r.execution_id,
            #{utc("r.created_at")} AS created_at_utc,
            d.data #>> '{context,Generate,0,json,draft}' AS original_draft,
            d.data #>> '{context,Edit,0,json,draft}' AS edited_draft,
            d.data #>> '{context,Generate,0,json,reviewer}' AS reviewer_username,
            #{execution_status} AS execution_status,
            #{outcome} AS outcome, r.superseded, published.id AS published_post_id,
            published.raw AS published_text
          FROM eligible_runs r JOIN visible_posts p ON p.id = r.post_id
          LEFT JOIN users student ON student.id = p.user_id
          LEFT JOIN users actor ON actor.id = r.actor_id
          LEFT JOIN discourse_workflows_executions e ON e.id = r.execution_id
          LEFT JOIN discourse_workflows_execution_data d ON d.execution_id = e.id
          LEFT JOIN visible_posts published ON published.id = r.published_post_id
          WHERE #{range("r.created_at")} ORDER BY r.created_at, r.id
        SQL
      when "usage", "usage_summary"
        usage
      when "polls", "poll_votes"
        polls
      end
    end

    def execution_status
      cases =
        DiscourseWorkflows::Execution
          .statuses
          .map { |name, value| "WHEN #{value} THEN #{quote(name)}" }
          .join(" ")
      "CASE WHEN r.execution_id IS NULL THEN 'pending' WHEN e.id IS NULL THEN 'unavailable' ELSE CASE e.status #{cases} END END"
    end

    def outcome
      "CASE WHEN r.superseded THEN 'superseded' WHEN r.published_post_id IS NOT NULL THEN 'published' " \
        "WHEN d.data #>> '{context,Review,0,json,button}' = 'reject' THEN 'rejected' END"
    end

    def usage
      from = <<~SQL
        FROM ai_api_audit_logs l
        JOIN eligible_runs r ON l.feature_context ->> 'educustomize_run_id' = r.id::text
        JOIN visible_posts p ON p.id = r.post_id
        WHERE #{range("l.created_at")}
      SQL
      if key == "usage_summary"
        <<~SQL
          SELECT #{common}, l.llm_id, l.language_model, COUNT(*) AS call_count,
            COUNT(*) FILTER (WHERE #{AiApiAuditLog::SUCCESS_CONDITION}) AS success_count,
            COUNT(*) FILTER (WHERE #{AiApiAuditLog::FAILURE_CONDITION}) AS failure_count,
            SUM(l.request_tokens) AS request_tokens, SUM(l.response_tokens) AS response_tokens,
            SUM(l.cache_read_tokens) AS cache_read_tokens, SUM(l.cache_write_tokens) AS cache_write_tokens,
            SUM(l.estimated_cost) AS estimated_cost, COUNT(*) FILTER (WHERE l.estimated_cost IS NULL) AS missing_cost_count
          #{from}
          GROUP BY l.llm_id, l.language_model ORDER BY l.llm_id
        SQL
      else
        <<~SQL
          SELECT #{common}, l.id AS log_id, r.id AS run_id, p.topic_id, p.id AS source_post_id,
            l.feature_context ->> 'educustomize_agent_id' AS agent_id,
            l.feature_context ->> 'subagent_parent_agent_id' AS parent_agent_id,
            l.feature_context ->> 'subagent_depth' AS subagent_depth,
            l.feature_name, l.llm_id, l.language_model,
            #{utc("l.created_at")} AS created_at_utc, l.request_tokens, l.response_tokens,
            l.cache_read_tokens, l.cache_write_tokens, l.duration_msecs, l.response_status,
            CASE WHEN #{AiApiAuditLog::SUCCESS_CONDITION} THEN 'successful' ELSE 'failed' END AS outcome,
            l.estimated_cost
          #{from} ORDER BY l.created_at, l.id
        SQL
      end.gsub("ai_api_audit_logs.", "l.")
    end

    def polls
      raise Discourse::InvalidAccess unless defined?(::Poll) && SiteSetting.poll_enabled
      allowed =
        Poll
          .where(post_id: data.posts.select(:id))
          .includes(:post)
          .select do |poll|
            if key == "poll_votes"
              poll.can_see_voters?(data.guardian.user)
            else
              poll.can_see_results?(data.guardian.user)
            end
          end
          .map(&:id)
      ids = allowed.presence || [0]
      if key == "poll_votes"
        <<~SQL
          SELECT #{common}, p.topic_id, p.id AS post_id, poll.id AS poll_id,
            poll.name AS poll_name, poll.type AS poll_type, option.id AS option_id,
            option.html AS option_html, vote.user_id, voter.username
          FROM polls poll JOIN visible_posts p ON p.id = poll.post_id
          JOIN poll_options option ON option.poll_id = poll.id
          JOIN poll_votes vote ON vote.poll_option_id = option.id
          LEFT JOIN users voter ON voter.id = vote.user_id
          WHERE poll.id IN (#{ids.join(",")}) AND #{range("poll.created_at")}
          ORDER BY poll.id, option.id, vote.user_id
        SQL
      else
        <<~SQL
          SELECT #{common}, p.topic_id, p.id AS post_id, poll.id AS poll_id,
            poll.name AS poll_name, poll.title AS poll_title, poll.type AS poll_type,
            option.id AS option_id, option.html AS option_html,
            COUNT(vote.user_id) + COALESCE(option.anonymous_votes, 0) AS vote_count,
            CASE WHEN poll.status = 1 OR poll.close_at <= CURRENT_TIMESTAMP THEN 'closed' ELSE 'open' END AS status,
            #{utc("poll.created_at")} AS created_at_utc
          FROM polls poll JOIN visible_posts p ON p.id = poll.post_id
          JOIN poll_options option ON option.poll_id = poll.id
          LEFT JOIN poll_votes vote ON vote.poll_option_id = option.id
          WHERE poll.id IN (#{ids.join(",")}) AND #{range("poll.created_at")}
          GROUP BY p.topic_id, p.id, poll.id, option.id ORDER BY poll.id, option.id
        SQL
      end
    end
  end
end
