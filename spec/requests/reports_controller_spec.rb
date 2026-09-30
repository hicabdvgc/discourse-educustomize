# frozen_string_literal: true

require "csv"

RSpec.describe DiscourseEducustomize::ReportsController do
  fab!(:admin)
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:topic) { Fabricate(:topic, category: course.category) }
  fab!(:student_post) { Fabricate(:post, topic: topic, user: student) }

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.data_explorer_enabled = true
    SiteSetting.enable_category_group_moderation = true
    course.student_group.add(student)
  end

  def preview(key = "discussions", **params)
    post "/educustomize/courses/#{course.id}/reports/#{key}/preview.json", params: params
  end

  def result_rows
    response
      .parsed_body
      .fetch("rows")
      .map { |row| response.parsed_body.fetch("columns").zip(row).to_h }
  end

  describe "#index" do
    it "requires login" do
      get "/educustomize/courses/#{course.id}/reports.json"
      expect(response.status).to eq(403)
    end

    it "returns the complete report catalog to the assigned teacher" do
      sign_in(teacher)
      get "/educustomize/courses/#{course.id}/reports.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["available"]).to eq(true)
      expect(response.parsed_body["reports"].pluck("key")).to contain_exactly(
        "discussions",
        "participation",
        "reviews",
        "usage",
        "usage_summary",
        "polls",
        "poll_votes",
        "feedback",
      )
    end

    it "exposes dependency unavailability while preserving the catalog" do
      SiteSetting.data_explorer_enabled = false
      sign_in(teacher)
      get "/educustomize/courses/#{course.id}/reports.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["available"]).to eq(false)
      expect(response.parsed_body["reports"]).to be_present
    end

    it "rejects enrolled students and teachers of another course" do
      [student, Fabricate(:educustomize_course).created_by].each do |actor|
        sign_in(actor)
        get "/educustomize/courses/#{course.id}/reports.json"
        expect(response.status).to eq(403)
      end
    end
  end

  describe "#preview" do
    before { sign_in(teacher) }

    it "returns only visible course posts through the native query engine" do
      other_post = Fabricate(:post, raw: "Another course discussion")
      hidden_post = Fabricate(:post, topic: topic, hidden: true)
      deleted_post =
        Fabricate(:post, topic: topic, deleted_at: Time.current, raw: "Deleted research text")
      preview
      expect(response.status).to eq(200), response.body
      expect(result_rows.pluck("post_id")).to contain_exactly(student_post.id, hidden_post.id)
      expect(response.body).not_to include(other_post.raw, deleted_post.raw)
    end

    it "filters hidden posts when course category moderation is disabled" do
      SiteSetting.enable_category_group_moderation = false
      Fabricate(:post, topic: topic, user: student, hidden: true)
      preview
      expect(response.status).to eq(200), response.body
      expect(result_rows.pluck("post_id")).to eq([student_post.id])
    end
    it "permits administrators to export a course without membership" do
      sign_in(admin)
      preview
      expect(response.status).to eq(200), response.body
      expect(result_rows.pluck("post_id")).to include(student_post.id)
    end

    it "rechecks teacher authorization after revocation" do
      course.teacher_group.remove(teacher)
      preview
      expect(response.status).to eq(403)
    end

    it "rejects a requested Topic outside the course" do
      preview(topic_id: Fabricate(:topic).id)
      expect(response.status).to eq(404)
    end

    it "excludes a Topic that has moved outside the course" do
      topic.update!(category: Fabricate(:category))
      preview
      expect(response.status).to eq(200), response.body
      expect(result_rows).to be_empty
    end

    it "interprets date boundaries in the requested timezone" do
      student_post.update_columns(created_at: Time.utc(2026, 9, 19, 16, 0, 0))
      Fabricate(:post, topic: topic, created_at: Time.utc(2026, 9, 19, 15, 59, 59))
      Fabricate(:post, topic: topic, created_at: Time.utc(2026, 9, 20, 16, 0, 0))
      preview(start_date: "2026-09-20", end_date: "2026-09-20", timezone: "Asia/Shanghai")
      expect(response.status).to eq(200), response.body
      expect(result_rows.pluck("post_id")).to eq([student_post.id])
    end

    it "rejects invalid dates and reversed ranges" do
      [
        { start_date: "invalid" },
        { start_date: "2026-09-21", end_date: "2026-09-20" },
        { timezone: "Invalid/Timezone" },
      ].each do |params|
        preview(**params)
        expect(response.status).to eq(400), response.body
      end
    end

    it "returns a dependency error when Data Explorer is disabled" do
      SiteSetting.data_explorer_enabled = false
      preview
      expect(response.status).to eq(422)
    end

    it "uses fixed server templates despite supplied SQL and course identifiers" do
      preview(sql: "SELECT 'injected'", course_id: Fabricate(:educustomize_course).id)
      expect(response.status).to eq(200), response.body
      expect(result_rows.pluck("post_id")).to eq([student_post.id])
    end

    it "limits previews to fifty records and indicates truncation" do
      Fabricate.times(50, :post, topic: topic, user: student)
      preview
      expect(response.status).to eq(200), response.body
      expect(result_rows.size).to eq(50)
      expect(response.parsed_body["truncated"]).to eq(true)
    end

    it "uses native poll result visibility independently from voter identity visibility" do
      public_poll = Fabricate(:poll, post: student_post, visibility: "everyone")
      secret_poll = Fabricate(:poll, post: student_post, visibility: "secret")
      closed_results =
        Fabricate(
          :poll,
          post: student_post,
          results: "on_close",
          status: "open",
          visibility: "everyone",
        )
      [public_poll, secret_poll, closed_results].each do |poll|
        option = Fabricate(:poll_option, poll: poll)
        Fabricate(:poll_vote, poll: poll, poll_option: option, user: student)
      end
      preview("polls")
      expect(response.status).to eq(200), response.body
      expect(result_rows.pluck("poll_id")).to contain_exactly(public_poll.id, secret_poll.id)
      preview("poll_votes")
      expect(response.status).to eq(200), response.body
      expect(result_rows.pluck("poll_id")).to eq([public_poll.id])
      expect(result_rows.pluck("user_id")).to eq([student.id])
    end

    it "separates original, edited and published text and retains expired run references" do
      workflow = Fabricate(:discourse_workflows_workflow)
      policy =
        DiscourseEducustomize::TopicPolicy.create!(
          topic: topic,
          course: course,
          reviewer: teacher,
          workflow_id: workflow.id,
        )
      execution = Fabricate(:discourse_workflows_completed_execution, workflow: workflow)
      Fabricate(
        :discourse_workflows_execution_data,
        execution: execution,
        data: {
          "context" => {
            "Generate" => [
              {
                "json" => {
                  "draft" => "Original research draft",
                  "reviewer" => teacher.username,
                },
              },
            ],
            "Edit" => [{ "json" => { "draft" => "Teacher edited text" } }],
          },
        },
      )
      published_post = Fabricate(:post, topic: topic, raw: "Published teaching answer")
      run =
        DiscourseEducustomize::Run.create!(
          topic_policy: policy,
          post: student_post,
          actor: teacher,
          execution: execution,
          configuration_digest: "report-fixture",
          request_key: SecureRandom.uuid,
          published_post_id: published_post.id,
        )
      preview("reviews")
      expect(response.status).to eq(200), response.body
      expect(result_rows.first).to include(
        "run_id" => run.id,
        "original_draft" => "Original research draft",
        "edited_draft" => "Teacher edited text",
        "published_text" => published_post.raw,
        "reviewer_username" => teacher.username,
        "execution_status" => "success",
        "outcome" => "published",
      )
      execution.destroy!
      preview("reviews")
      expect(response.status).to eq(200), response.body
      expect(result_rows.first).to include(
        "run_id" => run.id,
        "execution_status" => "unavailable",
        "original_draft" => nil,
        "edited_draft" => nil,
        "published_text" => published_post.raw,
      )
    end

    it "keeps unrelated audit calls out of course usage and distinguishes missing cost from zero" do
      workflow = Fabricate(:discourse_workflows_workflow)
      policy =
        DiscourseEducustomize::TopicPolicy.create!(
          topic: topic,
          course: course,
          reviewer: teacher,
          workflow_id: workflow.id,
        )
      run =
        DiscourseEducustomize::Run.create!(
          topic_policy: policy,
          post: student_post,
          actor: teacher,
          configuration_digest: "usage-fixture",
          request_key: SecureRandom.uuid,
        )
      zero_cost =
        Fabricate(
          :ai_api_audit_log,
          feature_context: {
            "educustomize_run_id" => run.id,
          },
          estimated_cost: 0,
          request_tokens: 5,
          response_tokens: 2,
          response_status: 200,
        )
      unknown_cost =
        Fabricate(
          :ai_api_audit_log,
          feature_context: {
            "educustomize_run_id" => run.id,
          },
          estimated_cost: nil,
          request_tokens: 3,
          response_tokens: 1,
          response_status: 500,
        )
      Fabricate(:ai_api_audit_log, topic_id: topic.id, estimated_cost: 10, request_tokens: 999)
      preview("usage")
      expect(response.status).to eq(200), response.body
      expect(result_rows.pluck("log_id")).to contain_exactly(zero_cost.id, unknown_cost.id)
      preview("usage_summary")
      expect(response.status).to eq(200), response.body
      expect(result_rows.first).to include(
        "call_count" => 2,
        "success_count" => 1,
        "failure_count" => 1,
        "request_tokens" => 8,
        "response_tokens" => 3,
        "missing_cost_count" => 1,
      )
    end
    it "executes every report with columns matching its published field dictionary" do
      get "/educustomize/courses/#{course.id}/reports.json"
      expect(response.status).to eq(200), response.body
      catalog = response.parsed_body.fetch("reports")
      catalog.each do |report|
        preview(report.fetch("key"))
        expect(response.status).to eq(200), "#{report.fetch("key")}: #{response.body}"
        expect(response.parsed_body["columns"]).to be_present
        expect(response.parsed_body["columns"]).to eq(report.fetch("columns"))
      end
    end
  end

  describe "#download" do
    before { sign_in(teacher) }

    it "exports the same authorized fields and rows as the preview" do
      preview
      expect(response.status).to eq(200), response.body
      expected = response.parsed_body
      post "/educustomize/courses/#{course.id}/reports/discussions/download.csv"
      expect(response.status).to eq(200), response.body
      csv = CSV.parse(response.body.sub(/\A\uFEFF/, ""))
      expect(csv.first).to eq(expected.fetch("columns"))
      expect(csv.drop(1)).to eq(
        expected.fetch("rows").map { |row| row.map { |value| value&.to_s } },
      )
    end

    it "refuses a full download at the native result limit" do
      attributes = student_post.attributes.except("id")
      records =
        (2..DiscourseDataExplorer::QUERY_RESULT_MAX_LIMIT).map do |number|
          attributes.merge("post_number" => number)
        end
      Post.insert_all!(records)
      post "/educustomize/courses/#{course.id}/reports/discussions/download.csv"
      expect(response.status).to eq(422), response.body
      expect(response.headers["Content-Disposition"]).to be_nil
    end

    it "downloads JSON with the same fields and data as the preview" do
      preview
      expected = response.parsed_body
      post "/educustomize/courses/#{course.id}/reports/discussions/download.json"
      expect(response.status).to eq(200), response.body
      actual = JSON.parse(response.body)
      expect(actual["columns"]).to eq(expected["columns"])
      expect(actual["rows"]).to eq(expected["rows"])
    end
    it "rejects download after teacher access is revoked" do
      course.teacher_group.remove(teacher)
      post "/educustomize/courses/#{course.id}/reports/discussions/download.json"
      expect(response.status).to eq(403)
    end
  end
end
