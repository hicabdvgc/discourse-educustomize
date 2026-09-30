# frozen_string_literal: true

RSpec.describe "Manage teaching courses" do
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:approved_teachers, :group)
  fab!(:model, :fake_model)
  let(:catalog) { PageObjects::Pages::EduCourses.new }
  let(:course_page) { PageObjects::Pages::EduCourse.new }

  before do
    enable_current_plugin
    SiteSetting.default_locale = "en"
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.educustomize_teacher_group = approved_teachers.id.to_s
    SiteSetting.educustomize_model_ids = model.id.to_s
    approved_teachers.add(teacher)
  end

  it "lets an approved teacher create a course and maintain its assistant" do
    sign_in(teacher)
    catalog.visit_catalog.create_course(
      name: "UI teaching course",
      introduction: "Initial course introduction.",
    )
    expect(course_page).to have_course_name("UI teaching course")
    course_page.back_to_catalog
    catalog.enter_named_course("UI teaching course")
    expect(course_page).to have_category_management_links
    course_page.open_from_category
    course_page.update_introduction("Revised course introduction.")
    expect(course_page).to have_saved_notice
    page.refresh
    expect(course_page).to have_introduction("Revised course introduction.")
    assistant = course_page.new_assistant
    assistant.configure(
      name: "UI teaching assistant",
      instructions: "Ask students to reflect before answering.",
      model:,
    )
    assistant.add_skill(
      name: "Evidence",
      description: "Check support.",
      instructions: "Ask for two supporting facts.",
    )
    assistant.upload_material(Rails.root.join("LICENSE.txt"))
    expect(assistant).to have_material("LICENSE.txt")
    assistant.save
    expect(course_page).to have_assistant("UI teaching assistant")
    page.refresh
    assistant = course_page.edit_assistant("UI teaching assistant")
    expect(assistant).to have_skill(name: "Evidence", instructions: "Ask for two supporting facts.")
    expect(assistant).to have_export_link
    expect(assistant).to have_material("LICENSE.txt")
    assistant.remove_material("LICENSE.txt")
    expect(assistant).to have_no_material("LICENSE.txt")
    expect(assistant).to have_instructions("Ask students to reflect before answering.")
    assistant.change_instructions("Encourage evidence-based reasoning.")
    expect(assistant).to have_unsaved_export_warning
    assistant.upload_material(Rails.root.join("LICENSE.txt"))
    expect(assistant).to have_material("LICENSE.txt")
    assistant.save
    expect(course_page).to have_assistant("UI teaching assistant")
    critic = course_page.new_assistant
    critic.configure(
      name: "UI critic",
      instructions: "Identify gaps in the evidence.",
      model: model,
    )
    critic.save
    expect(course_page).to have_assistant("UI critic")
    page.refresh
    assistant = course_page.edit_assistant("UI teaching assistant")
    expect(assistant).to have_material("LICENSE.txt")
    assistant.remove_material("LICENSE.txt")
    expect(assistant).to have_no_material("LICENSE.txt")
    expect(assistant).to have_instructions("Encourage evidence-based reasoning.")
    assistant.save
    expect(course_page).to have_assistant("UI teaching assistant")
    dais = course_page.new_assistant
    dais.configure(
      name: "UI course Bloc",
      instructions: "Coordinate the selected Delegate.",
      model:,
    )
    dais.add_delegate("UI teaching assistant")
    dais.add_delegate("UI critic")
    dais.save
    expect(course_page).to have_assistant("UI course Bloc")
    page.refresh
    reopened = course_page.edit_assistant("UI course Bloc")
    expect(reopened).to have_delegate("UI teaching assistant")
    expect(reopened).to have_delegate("UI critic")
  end

  it "persists a teacher-uploaded course image in the native category header" do
    course = Fabricate(:educustomize_course, created_by: teacher)
    sign_in(teacher)
    course_page.visit_course(course).upload_image(Rails.root.join("spec/fixtures/images/logo.png"))
    expect(course_page).to have_completed_image_upload
    course_page.update_introduction("A course with an uploaded image.")
    expect(course_page).to have_saved_notice
    course_page.back_to_catalog
    catalog.enter_course(course)
    course_page.open_all_discussions
    expect(course_page).to have_category_image
    page.refresh
    expect(course_page).to have_category_image
  end

  it "lets a student read the introduction and enter discussions after joining" do
    course = Fabricate(:educustomize_course, created_by: teacher)
    sign_in(student)
    catalog.visit_catalog
    expect(catalog).to have_joinable_course(course)
    catalog.join_course(course)
    expect(catalog).to have_joined_course(course)
    catalog.enter_course(course)
    expect(page).to have_content(course.category.name)
    expect(page).to have_current_path("/educustomize/courses/#{course.id}/learning")
    expect(course_page).to have_no_category_management_links
    course_page.open_all_discussions
    page.refresh
    expect(page).to have_current_path(course.category.url)
    catalog.visit_catalog
    expect(catalog).to have_joined_course(course)
  end
  it "lets a teacher add and remove students through native membership management" do
    course = Fabricate(:educustomize_course, created_by: teacher)
    sign_in(teacher)
    members = PageObjects::Pages::EduMembers.new
    members.open_from_course(course)
    members.add_student(student)
    expect(members).to have_student(student)
    page.refresh
    expect(members).to have_student(student)
    members.remove_student(student)
    expect(members).to have_no_student(student)
    page.refresh
    expect(members).to have_no_student(student)
  end
end
