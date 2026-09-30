# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::AdminController do
  fab!(:admin)
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:model, :fake_model)

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.enable_category_group_moderation = true
    course.student_group.add(student)
  end

  describe "#index" do
    it "returns administrator dependency status and model display fields" do
      sign_in(admin)
      get "/educustomize/admin.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["models"]).to eq(
        [{ "id" => model.id, "name" => model.display_name }],
      )
      expect(response.parsed_body["dependencies"]).to eq(
        "ai" => true,
        "workflows" => true,
        "category_moderation" => true,
      )
      expect(response.parsed_body["models"].first.keys).to contain_exactly("id", "name")
    end

    it "rejects anonymous users, course teachers and students" do
      get "/educustomize/admin.json"
      expect(response.status).to eq(403)
      [teacher, student].each do |user|
        sign_in(user)
        get "/educustomize/admin.json"
        expect(response.status).to eq(403)
      end
    end
  end

  describe "#install_workflow" do
    it "returns the same authorized template on repeated installation" do
      sign_in(admin)
      post "/educustomize/admin/workflow.json"
      expect(response.status).to eq(200), response.body
      workflow_id = response.parsed_body["workflow"]["id"]
      expect do post "/educustomize/admin/workflow.json" end.not_to change(
        DiscourseWorkflows::Workflow,
        :count,
      )
      expect(response.status).to eq(200)
      expect(response.parsed_body["workflow"]["id"]).to eq(workflow_id)
      expect(response.parsed_body["workflow"].keys).to contain_exactly("id", "name")
    end

    it "returns a dependency error when workflows are disabled" do
      sign_in(admin)
      SiteSetting.enable_discourse_workflows = false
      post "/educustomize/admin/workflow.json"
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("educustomize.dependencies_required"),
      )
    end

    it "rejects anonymous users, course teachers and students" do
      post "/educustomize/admin/workflow.json"
      expect(response.status).to eq(403)
      [teacher, student].each do |user|
        sign_in(user)
        post "/educustomize/admin/workflow.json"
        expect(response.status).to eq(403)
      end
      expect(DiscourseWorkflows::Workflow.count).to eq(0)
    end
  end

  describe "#sampling" do
    it "lets administrators update only the native sampling switch" do
      sign_in(admin)
      put "/educustomize/admin/sampling.json",
          params: {
            enabled: true,
            setting_name: "login_required",
          }
      expect(response.status).to eq(200)
      expect(SiteSetting.ai_llm_temperature_top_p_enabled).to eq(true)
      expect(
        UserHistory.where(subject: "ai_llm_temperature_top_p_enabled", acting_user_id: admin.id),
      ).to exist
      put "/educustomize/admin/sampling.json", params: { enabled: "invalid" }
      expect(response.status).to eq(400)
      expect(SiteSetting.ai_llm_temperature_top_p_enabled).to eq(true)
    end

    it "denies teachers, students and anonymous callers" do
      put "/educustomize/admin/sampling.json", params: { enabled: true }
      expect(response.status).to eq(403)
      [teacher, student].each do |user|
        sign_in(user)
        put "/educustomize/admin/sampling.json", params: { enabled: true }
        expect(response.status).to eq(403)
      end
      expect(SiteSetting.ai_llm_temperature_top_p_enabled).to eq(false)
    end
  end
end
