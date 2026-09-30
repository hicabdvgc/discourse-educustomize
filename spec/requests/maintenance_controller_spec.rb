# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::MaintenanceController do
  fab!(:admin)
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:topic) { Fabricate(:topic, category: course.category) }
  fab!(:student_post) { Fabricate(:post, topic: topic, user: student) }
  fab!(:model, :fake_model)

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.educustomize_model_ids = model.id.to_s
    course.student_group.add(student)
    @agent =
      Fabricate(:ai_agent, default_llm_id: model.id, allowed_group_ids: [course.teacher_group_id])
    course.agent_links.create!(ai_agent: @agent)
    @workflow = DiscourseEducustomize::WorkflowTemplate.install!(admin)
    @policy =
      DiscourseEducustomize::TopicPolicy.create!(
        topic: topic,
        course: course,
        ai_agent: @agent,
        reviewer: teacher,
        workflow_id: @workflow.id,
      )
  end

  after { AiAgent.agent_cache.flush! }

  def create_run(execution: nil, **attributes)
    DiscourseEducustomize::Run.create!(
      topic_policy: @policy,
      post: student_post,
      actor: teacher,
      request_key: SecureRandom.uuid,
      configuration_digest: DiscourseEducustomize::AiConfiguration.digest(@policy),
      execution: execution,
      **attributes,
    )
  end

  describe "#show" do
    it "returns the course readiness and native retention settings to its teacher" do
      sign_in(teacher)
      get "/educustomize/courses/#{course.id}/maintenance.json"
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body).to include("dependencies", "policies", "agents", "retention")
      expect(response.parsed_body["course"]["id"]).to eq(course.id)
    end

    it "reports missing model authorization using the same readiness rules as generation" do
      SiteSetting.educustomize_model_ids = ""
      sign_in(teacher)
      get "/educustomize/courses/#{course.id}/maintenance.json"
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["policies"].first["reasons"]).to include("model_unauthorized")
      expect(response.parsed_body["agents"].first["model_authorized"]).to eq(false)
    end

    it "reports unknown and partially indexed materials from native embedding records" do
      vector_def = Fabricate(:embedding_definition)
      SiteSetting.ai_embeddings_selected_model = vector_def.id
      SiteSetting.ai_embeddings_enabled = true
      pending_upload = Fabricate(:upload)
      indexed_upload = Fabricate(:upload)
      UploadReference.ensure_exist!(
        upload_ids: [pending_upload.id, indexed_upload.id],
        target: @agent,
      )
      indexed_fragment = Fabricate(:rag_document_fragment, upload: indexed_upload, target: @agent)
      Fabricate(:rag_document_fragment, upload: indexed_upload, target: @agent)
      stub_request(:post, vector_def.url).to_return(
        status: 200,
        body: ([0.0038493] * vector_def.dimensions).to_json,
      )
      DiscourseAi::Embeddings::Vector.instance.generate_representation_from(indexed_fragment)
      sign_in(teacher)
      get "/educustomize/courses/#{course.id}/maintenance.json"
      expect(response.status).to eq(200), response.body
      materials =
        response.parsed_body["agents"].first["materials"].index_by { |material| material["id"] }
      expect(materials[pending_upload.id]).to include("status" => "unknown", "total" => 0)
      expect(materials[indexed_upload.id]).to include(
        "status" => "indexing",
        "total" => 2,
        "indexed" => 1,
        "left" => 1,
      )
    end
    it "rejects anonymous and enrolled student requests" do
      get "/educustomize/courses/#{course.id}/maintenance.json"
      expect(response.status).to eq(403)
      sign_in(student)
      get "/educustomize/courses/#{course.id}/maintenance.json"
      expect(response.status).to eq(403)
    end

    it "allows maintenance when the independent export dependency is disabled" do
      SiteSetting.data_explorer_enabled = false
      sign_in(teacher)
      get "/educustomize/courses/#{course.id}/maintenance.json"
      expect(response.status).to eq(200), response.body
    end

    it "rechecks course assignment before disclosing maintenance data" do
      sign_in(teacher)
      course.teacher_group.remove(teacher)
      get "/educustomize/courses/#{course.id}/maintenance.json"
      expect(response.status).to eq(403)
    end
  end

  describe "#runs" do
    before { sign_in(teacher) }

    it "separates successful execution from a rejected review outcome" do
      execution = Fabricate(:discourse_workflows_completed_execution, workflow: @workflow)
      Fabricate(
        :discourse_workflows_execution_data,
        execution: execution,
        data: {
          "context" => {
            "Review" => [{ "json" => { "button" => "reject" } }],
          },
        },
      )
      rejected = create_run(execution: execution)
      create_run
      get "/educustomize/courses/#{course.id}/runs.json",
          params: {
            status: "success",
            outcome: "rejected",
          }
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["runs"].pluck("id")).to eq([rejected.id])
      expect(response.parsed_body["runs"].first).to include(
        "status" => "success",
        "outcome" => "rejected",
      )
    end

    it "retains the run reference when native execution data has expired" do
      execution = Fabricate(:discourse_workflows_completed_execution, workflow: @workflow)
      run = create_run(execution: execution)
      execution.destroy!
      get "/educustomize/courses/#{course.id}/runs.json"
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["runs"].pluck("id")).to eq([run.id])
      expect(response.parsed_body["runs"].first["draft"]).to be_nil
    end

    it "excludes runs whose Topic moved to another category" do
      create_run
      topic.update!(category: Fabricate(:category))
      get "/educustomize/courses/#{course.id}/runs.json"
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["runs"]).to be_empty
    end

    it "rejects a Topic filter belonging to another course" do
      get "/educustomize/courses/#{course.id}/runs.json", params: { topic_id: Fabricate(:topic).id }
      expect(response.status).to eq(404)
    end

    it "paginates in stable newest-first order without losing course runs" do
      runs = 26.times.map { create_run }
      get "/educustomize/courses/#{course.id}/runs.json", params: { page: 1 }
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["runs"].pluck("id")).to eq(runs.reverse.first(25).map(&:id))
      expect(response.parsed_body["has_more"]).to eq(true)
      get "/educustomize/courses/#{course.id}/runs.json", params: { page: 2 }
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["runs"].pluck("id")).to eq([runs.first.id])
      expect(response.parsed_body["has_more"]).to eq(false)
    end

    it "rejects malformed pagination and unsupported status filters" do
      [{ page: 0 }, { status: "invalid" }, { outcome: "invalid" }].each do |params|
        get "/educustomize/courses/#{course.id}/runs.json", params: params
        expect(response.status).to eq(400), response.body
      end
    end
    it "rejects a student attempting to access run details" do
      create_run
      sign_in(student)
      get "/educustomize/courses/#{course.id}/runs.json"
      expect(response.status).to eq(403)
    end
  end
end

RSpec.describe DiscourseEducustomize::AdminController do
  fab!(:admin)
  fab!(:teacher, :user)

  before { SiteSetting.educustomize_enabled = true }

  describe "#workflow_retention" do
    it "saves the administrator's value through the native setting and audit log" do
      sign_in(admin)
      expect do
        put "/educustomize/admin/workflow-retention.json", params: { days: 45 }
        expect(response.status).to eq(200), response.body
      end.to change {
        UserHistory.where(action: UserHistory.actions[:change_site_setting]).count
      }.by(1)
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["days"]).to eq(45)
      expect(SiteSetting.workflow_executions_retention_days).to eq(45)
    end

    it "rejects teachers and preserves the current retention value" do
      sign_in(teacher)
      expect do
        put "/educustomize/admin/workflow-retention.json", params: { days: 45 }
      end.not_to change { SiteSetting.workflow_executions_retention_days }
      expect(response.status).to eq(403)
    end

    it "rejects values outside the documented integer range" do
      sign_in(admin)
      [-1, 36_501, "1.5", "invalid"].each do |days|
        expect do
          put "/educustomize/admin/workflow-retention.json", params: { days: days }
        end.not_to change { SiteSetting.workflow_executions_retention_days }
        expect(response.status).to eq(400), response.body
      end
    end
  end
end

RSpec.describe DiscourseEducustomize::RunsController do
  fab!(:teacher, :user)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:topic) { Fabricate(:topic, category: course.category) }
  fab!(:source_post) { Fabricate(:post, topic: topic) }
  fab!(:policy) do
    DiscourseEducustomize::TopicPolicy.create!(topic: topic, course: course, reviewer: teacher)
  end

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.enable_category_group_moderation = true
  end

  describe "#index" do
    before { sign_in(teacher) }

    it "loads a selected historical run outside the latest fifty records" do
      runs =
        51.times.map do
          DiscourseEducustomize::Run.create!(
            topic_policy: policy,
            post: source_post,
            actor: teacher,
            configuration_digest: "historical-run-fixture",
            request_key: SecureRandom.uuid,
          )
        end
      get "/educustomize/topics/#{topic.id}/runs.json"
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["runs"].pluck("id")).to eq(runs.reverse.first(50).map(&:id))
      get "/educustomize/topics/#{topic.id}/runs.json", params: { run_id: runs.first.id }
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["runs"].pluck("id")).to eq(
        [runs.first.id, *runs.reverse.first(50).map(&:id)],
      )
      expect(response.parsed_body["runs"].first["review_url"]).to eq(
        "/educustomize/topics/#{topic.id}?run_id=#{runs.first.id}#run-#{runs.first.id}",
      )
    end

    it "rejects a selected run belonging to another Topic policy" do
      other_topic = Fabricate(:topic, category: course.category)
      other_policy =
        DiscourseEducustomize::TopicPolicy.create!(
          topic: other_topic,
          course: course,
          reviewer: teacher,
        )
      other_run =
        DiscourseEducustomize::Run.create!(
          topic_policy: other_policy,
          post: Fabricate(:post, topic: other_topic),
          actor: teacher,
          configuration_digest: "other-policy-fixture",
          request_key: SecureRandom.uuid,
        )
      get "/educustomize/topics/#{topic.id}/runs.json", params: { run_id: other_run.id }
      expect(response.status).to eq(404)
    end
  end
end
