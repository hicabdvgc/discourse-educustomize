# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::AgentsController do
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:own_link) { Fabricate(:educustomize_agent_link, course:) }
  fab!(:foreign_link, :educustomize_agent_link)
  let(:agent_params) do
    {
      name: "My assistant",
      description: "Teaching assistant",
      system_prompt: "Encourage critical reflection.",
    }
  end

  before { SiteSetting.educustomize_enabled = true }

  describe "#index" do
    it "requires a logged-in course teacher" do
      get "/educustomize/courses/#{course.id}/agents.json"
      expect(response.status).to eq(403)
      course.student_group.add(student)
      sign_in(student)
      get "/educustomize/courses/#{course.id}/agents.json"
      expect(response.status).to eq(403)
    end

    it "returns only course agents and administrator-approved model summaries" do
      model = Fabricate(:llm_model)
      SiteSetting.educustomize_model_ids = model.id.to_s
      sign_in(teacher)
      get "/educustomize/courses/#{course.id}/agents.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["agents"].pluck("id")).to eq([own_link.ai_agent_id])
      expect(response.parsed_body["models"]).to eq(
        [
          {
            "id" => model.id,
            "name" => model.display_name,
            "provider" => model.provider,
            "model_name" => model.name,
          },
        ],
      )
    end
  end

  describe "#create" do
    it "ignores privileged agent fields and records the current teacher" do
      sign_in(teacher)
      post "/educustomize/courses/#{course.id}/agents.json",
           params: {
             agent:
               agent_params.merge(
                 created_by_id: student.id,
                 allowed_group_ids: [0],
                 ai_agent_mcp_server_ids: [1],
               ),
           }
      expect(response.status).to eq(201)
      agent = AiAgent.find(response.parsed_body["agent"]["id"])
      expect(agent).to have_attributes(
        created_by_id: teacher.id,
        allowed_group_ids: [course.teacher_group_id],
      )
      expect(agent.ai_agent_mcp_servers).to be_empty
    end

    it "rejects configuration in another teacher's course" do
      sign_in(teacher)
      post "/educustomize/courses/#{foreign_link.course_id}/agents.json",
           params: {
             agent: agent_params,
           }
      expect(response.status).to eq(403)
    end
  end

  describe "#update" do
    it "reopens the original Prompt and Skills and keeps repeated saves stable" do
      sign_in(teacher)
      skills = [
        {
          "name" => "Evidence",
          "description" => "Seek support.",
          "instructions" => "Ask why the answer follows.",
        },
      ]
      data = agent_params.merge(skills: skills)
      2.times do
        put "/educustomize/courses/#{course.id}/agents/#{own_link.ai_agent_id}.json",
            params: {
              agent: data,
            },
            as: :json
        expect(response.status).to eq(200), response.body
        expect(response.parsed_body["agent"]).to include(
          "system_prompt" => data[:system_prompt],
          "skills" => skills,
        )
        get "/educustomize/courses/#{course.id}/agents.json"
        saved = response.parsed_body["agents"].find { |agent| agent["id"] == own_link.ai_agent_id }
        expect(saved).to include("system_prompt" => data[:system_prompt], "skills" => skills)
        expect(
          own_link.ai_agent.reload.system_prompt.scan(skills.first["instructions"]).length,
        ).to eq(1)
      end
      put "/educustomize/courses/#{course.id}/agents/#{own_link.ai_agent_id}.json",
          params: {
            agent: data.merge(skills: []),
          },
          as: :json
      expect(response.status).to eq(200)
      expect(own_link.reload.skills).to be_empty
      expect(own_link.ai_agent.reload.system_prompt).to eq(data[:system_prompt])
    end

    it "rejects an agent identifier from a different course" do
      sign_in(teacher)
      put "/educustomize/courses/#{course.id}/agents/#{foreign_link.ai_agent_id}.json",
          params: {
            agent: agent_params,
          }
      expect(response.status).to eq(403)
      expect(foreign_link.ai_agent.reload.system_prompt).not_to eq(agent_params[:system_prompt])
    end
  end
  describe "#upload" do
    let(:knowledge_file) do
      Rack::Test::UploadedFile.new(Rails.root.join("LICENSE.txt"), "text/plain")
    end

    it "uploads knowledge through native storage without configured embeddings" do
      sign_in(teacher)
      expect(DiscourseAi::Embeddings.enabled?).to eq(false)
      post "/educustomize/courses/#{course.id}/knowledge-upload.json",
           params: {
             file: knowledge_file,
           }
      expect(response.status).to eq(201), response.body
      upload = Upload.find(response.parsed_body["id"])
      expect(upload).to have_attributes(
        user_id: teacher.id,
        original_filename: "LICENSE.txt",
        extension: "txt",
      )
      post "/educustomize/courses/#{course.id}/agents.json",
           params: {
             agent: agent_params.merge(upload_ids: [upload.id]),
           }
      expect(response.status).to eq(201), response.body
      expect(AiAgent.find(response.parsed_body["agent"]["id"]).uploads).to contain_exactly(upload)
    end

    it "rejects an enrolled student and a teacher from another course" do
      course.student_group.add(student)
      sign_in(student)
      post "/educustomize/courses/#{course.id}/knowledge-upload.json",
           params: {
             file: knowledge_file,
           }
      expect(response.status).to eq(403)
      sign_in(teacher)
      post "/educustomize/courses/#{foreign_link.course_id}/knowledge-upload.json",
           params: {
             file: knowledge_file,
           }
      expect(response.status).to eq(403)
    end

    it "rejects unsupported file extensions before creating an upload" do
      sign_in(teacher)
      image = Rack::Test::UploadedFile.new(file_from_fixtures("logo.png"), "image/png")
      expect do
        post "/educustomize/courses/#{course.id}/knowledge-upload.json", params: { file: image }
      end.not_to change(Upload, :count)
      expect(response.status).to eq(400)
    end

    it "disables the plugin endpoint without removing native course data" do
      sign_in(teacher)
      SiteSetting.educustomize_enabled = false
      post "/educustomize/courses/#{course.id}/knowledge-upload.json",
           params: {
             file: knowledge_file,
           }
      expect(response.status).to eq(404)
      expect(course.reload.category).to be_present
    end
  end
end
