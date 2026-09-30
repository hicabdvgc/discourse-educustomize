# frozen_string_literal: true

RSpec.describe "Import a course assistant configuration" do
  fab!(:teacher, :user)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:model, :fake_model)
  fab!(:original_link) do
    Fabricate(
      :educustomize_agent_link,
      course: course,
      ai_agent: Fabricate(:ai_agent, name: "Import Dais", default_llm: model),
    )
  end
  let(:course_page) { PageObjects::Pages::EduCourse.new }
  let(:importer) { PageObjects::Components::EduConfigurationImport.new }
  let(:assistant) { PageObjects::Components::EduAssistant.new }

  before do
    enable_current_plugin
    SiteSetting.default_locale = "en"
    SiteSetting.educustomize_model_ids = model.id.to_s
    SiteSetting.educustomize_tool_names = "Time"
  end

  it "lets a teacher preview and edit a complete Bloc, then opens a separate saved copy" do
    sign_in(teacher)
    course_page.visit_course(course)
    importer.preview_file(File.expand_path("../fixtures/agent_configuration.json", __dir__))
    expect(importer).to have_root_name("Import Dais (copy 2)")
    importer.edit_root(
      name: "Imported classroom Dais",
      prompt: "Coordinate independent evidence and critique.",
      skill_instructions: "Request two facts before summarizing.",
    )
    importer.create_copies
    expect(importer).to have_import_notice
    expect(assistant).to have_instructions("Coordinate independent evidence and critique.")
    expect(assistant).to have_skill(
      name: "Evidence",
      instructions: "Request two facts before summarizing.",
    )
    expect(assistant).to have_delegate("Import Tutor")
    expect(assistant).to have_delegate("Import Critic")
    expect(assistant).to have_export_link
    page.refresh
    reopened = course_page.edit_assistant("Imported classroom Dais")
    expect(reopened).to have_instructions("Coordinate independent evidence and critique.")
    expect(reopened).to have_delegate("Import Tutor")
    expect(reopened).to have_delegate("Import Critic")
  end
end
