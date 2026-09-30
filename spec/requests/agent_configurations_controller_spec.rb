# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::AgentConfigurationsController do
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:admin)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:foreign_link, :educustomize_agent_link)
  fab!(:model, :fake_model)
  fab!(:root_link) do
    Fabricate(
      :educustomize_agent_link,
      course: course,
      ai_agent:
        Fabricate(:ai_agent, name: "Original assistant", default_llm: model, tools: ["Time"]),
      prompt: "Preserve original instructions.\n\n第二段。",
      skills: [{ "name" => "Reason", "description" => "", "instructions" => "State assumptions." }],
    )
  end
  let(:document) do
    JSON.parse(File.read(File.expand_path("../fixtures/agent_configuration.json", __dir__)))
  end
  let(:base_path) { "/educustomize/courses/#{course.id}" }

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.educustomize_model_ids = model.id.to_s
    SiteSetting.educustomize_tool_names = "Time"
  end

  describe "#show" do
    it "exports all editable source fields without knowledge associations or model credentials" do
      sign_in(teacher)
      upload = Fabricate(:upload, user: teacher)
      UploadReference.ensure_exist!(upload_ids: [upload.id], target: root_link.ai_agent)

      get "#{base_path}/agents/#{root_link.ai_agent_id}/configuration.json"
      expect(response.status).to eq(200), response.body
      exported = response.parsed_body
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(DiscourseEducustomize::AgentConfiguration.new(exported).errors).to be_empty
      expect(exported["agents"].first).to eq(
        "key" => "agent-#{root_link.ai_agent_id}",
        "name" => root_link.ai_agent.name,
        "description" => root_link.ai_agent.description,
        "system_prompt" => root_link.prompt,
        "skills" => root_link.skills,
        "model" => model.attributes.slice("provider", "name", "display_name"),
        "enabled" => root_link.ai_agent.enabled,
        "temperature" => root_link.ai_agent.temperature,
        "top_p" => root_link.ai_agent.top_p,
        "tools" => ["Time"],
        "delegates" => [],
      )
    end

    it "rejects student access and a cross-course assistant" do
      course.student_group.add(student)
      sign_in(student)
      get "#{base_path}/agents/#{root_link.ai_agent_id}/configuration.json"
      expect(response.status).to eq(403)
      sign_in(teacher)
      get "#{base_path}/agents/#{foreign_link.ai_agent_id}/configuration.json"
      expect(response.status).to eq(404)
    end

    it "rejects a cross-course Delegate relationship" do
      root_link.ai_agent.update!(subagent_ids: [foreign_link.ai_agent_id])
      sign_in(teacher)
      get "#{base_path}/agents/#{root_link.ai_agent_id}/configuration.json"
      expect(response.status).to eq(403)
    end

    it "allows administrator access" do
      sign_in(admin)
      get "#{base_path}/agents/#{root_link.ai_agent_id}/configuration.json"
      expect(response.status).to eq(200)
    end
  end

  describe "#preview" do
    it "returns an editable copy with unused names and explicit model mappings" do
      sign_in(teacher)
      document["agents"].first["name"] = root_link.ai_agent.name
      expect do
        post "#{base_path}/agent-configurations/preview.json",
             params: {
               document: document,
             },
             as: :json
      end.not_to change(AiAgent, :count)
      expect(response.status).to eq(200), response.body
      expect(response.parsed_body["document"]["agents"].first["name"]).to eq(
        root_link.ai_agent.name + I18n.t("educustomize.configuration.copy_suffix", number: 2),
      )
      expect(response.parsed_body["model_mappings"]).to eq(
        "dais" => model.id,
        "tutor" => model.id,
        "critic" => model.id,
      )
    end

    it "returns a concrete validation error for malformed document content" do
      sign_in(teacher)
      [
        "{invalid JSON",
        document.merge("schema_version" => 2),
        document.merge("api_key" => "secret"),
      ].each do |invalid|
        post "#{base_path}/agent-configurations/preview.json",
             params: {
               document: invalid,
             },
             as: :json
        expect(response.status).to eq(422), response.body
        expect(response.parsed_body["errors"]).to be_present
      end
    end

    it "requires course-teacher access" do
      post "#{base_path}/agent-configurations/preview.json",
           params: {
             document: document,
           },
           as: :json
      expect(response.status).to eq(403)
      sign_in(student)
      post "#{base_path}/agent-configurations/preview.json",
           params: {
             document: document,
           },
           as: :json
      expect(response.status).to eq(403)
      sign_in(teacher)
      post "/educustomize/courses/#{foreign_link.course_id}/agent-configurations/preview.json",
           params: {
             document: document,
           },
           as: :json
      expect(response.status).to eq(403)
    end
  end

  describe "#create" do
    it "preserves the full Bloc through export, external edits, import, and re-export" do
      sign_in(teacher)
      tutor =
        Fabricate(
          :educustomize_agent_link,
          course: course,
          ai_agent: Fabricate(:ai_agent, default_llm: model),
        )
      critic =
        Fabricate(
          :educustomize_agent_link,
          course: course,
          ai_agent: Fabricate(:ai_agent, default_llm: model),
        )
      root_link.ai_agent.update!(subagent_ids: [tutor.ai_agent_id, critic.ai_agent_id])
      upload = Fabricate(:upload, user: teacher)
      UploadReference.ensure_exist!(upload_ids: [upload.id], target: tutor.ai_agent)
      original_prompt = root_link.ai_agent.system_prompt

      get "#{base_path}/agents/#{root_link.ai_agent_id}/configuration.json"
      exported = response.parsed_body
      exported["agents"].first[
        "system_prompt"
      ] += "\nExternal amendment referencing the original assistant."
      exported["agents"].last["skills"] = [
        {
          "name" => "Review",
          "description" => "Identify gaps.",
          "instructions" => "Challenge unsupported claims.",
        },
      ]
      exported["agents"].first["temperature"] = 0.42
      post "#{base_path}/agent-configurations/preview.json",
           params: {
             document: exported,
           },
           as: :json
      preview = response.parsed_body
      expect(response.status).to eq(200), response.body
      replacement = Fabricate(:fake_model, display_name: "Mapped target")
      SiteSetting.educustomize_model_ids = replacement.id.to_s
      mappings = exported["agents"].to_h { |agent| [agent["key"], replacement.id] }
      expect do
        post "#{base_path}/agent-configurations.json",
             params: {
               document: preview["document"],
               model_mappings: mappings,
             },
             as: :json
      end.to change(AiAgent, :count).by(3)
      expect(response.status).to eq(201), response.body
      imported_ids = response.parsed_body["agent_ids"]
      root_id = response.parsed_body["agent_id"]
      get "#{base_path}/agents/#{root_id}/configuration.json"
      expect(response.status).to eq(200), response.body
      reexported = response.parsed_body
      expected = preview["document"].deep_dup
      expected["root"] = "agent-#{root_id}"
      expected["agents"].each do |agent|
        agent["key"] = "agent-#{imported_ids.fetch(agent["key"])}"
        agent["delegates"].map! { |key| "agent-#{imported_ids.fetch(key)}" }
        agent["model"] = replacement.attributes.slice("provider", "name", "display_name")
      end
      expect(reexported).to eq(expected)
      expect(AiAgent.find(root_id).subagent_ids.size).to eq(2)
      expect(
        UploadReference.where(target_type: "AiAgent", target_id: imported_ids.values),
      ).to be_empty
      expect(root_link.ai_agent.reload.system_prompt).to eq(original_prompt)
      expect(tutor.ai_agent.uploads).to contain_exactly(upload)
    end

    it "imports a standalone assistant as a new copy" do
      sign_in(teacher)
      document["agents"] = [document["agents"].last]
      document["root"] = document["agents"].first["key"]
      expect do
        post "#{base_path}/agent-configurations.json",
             params: {
               document: document,
               model_mappings: {
                 document["root"] => model.id,
               },
             },
             as: :json
      end.to change(AiAgent, :count).by(1)
      expect(response.status).to eq(201), response.body
      expect(AiAgent.find(response.parsed_body["agent_id"]).subagent_ids).to be_empty
    end

    it "revalidates edits and rolls back the whole import after a name collision" do
      sign_in(teacher)
      document["agents"].first["name"] = root_link.ai_agent.name
      expect do
        post "#{base_path}/agent-configurations.json",
             params: {
               document: document,
               model_mappings: document["agents"].to_h { |agent| [agent["key"], model.id] },
             },
             as: :json
      end.not_to change {
        [AiAgent.count, DiscourseEducustomize::AgentLink.count, UserHistory.count]
      }
      expect(response.status).to eq(422), response.body
      expect(response.parsed_body["errors"].join).to include(root_link.ai_agent.name)
    end

    it "rejects unauthorized model mappings without creating any Agent" do
      sign_in(teacher)
      unauthorized = Fabricate(:fake_model)
      expect do
        post "#{base_path}/agent-configurations.json",
             params: {
               document: document,
               model_mappings: document["agents"].to_h { |agent| [agent["key"], unauthorized.id] },
             },
             as: :json
      end.not_to change(AiAgent, :count)
      expect(response.status).to eq(422), response.body
      expect(response.parsed_body["errors"]).to be_present
    end

    it "rejects a student and preserves the source course" do
      course.student_group.add(student)
      sign_in(student)
      expect do
        post "#{base_path}/agent-configurations.json",
             params: {
               document: document,
               model_mappings: {
               },
             },
             as: :json
      end.not_to change(AiAgent, :count)
      expect(response.status).to eq(403)
    end
  end
end
