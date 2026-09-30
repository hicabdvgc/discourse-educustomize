# frozen_string_literal: true

RSpec.describe "Use course workspace" do
  fab!(:admin)
  fab!(:teacher) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:student) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:teacher_group, :group)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  let(:workspace) { PageObjects::Pages::EduLearning.new }
  let(:setup_page) { PageObjects::Pages::EduTeachingSetup.new }
  let(:composer) { PageObjects::Components::EduNativeComposer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:activity) { PageObjects::Components::EduNativeActivity.new }
  let(:assign_modal) { PageObjects::Modals::Assign.new }

  before do
    enable_current_plugin
    SiteSetting.default_locale = "en"
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.educustomize_teacher_group = teacher_group.id.to_s
    teacher_group.add(teacher)
    course.student_group.add(student)
    result = DiscourseEducustomize::PrepareTeaching.call(guardian: admin.guardian)
    expect(result).to run_successfully
  end

  it "lets a teacher create a tagged feedback topic and a student vote and reply" do
    sign_in(teacher)
    workspace.visit_course(course)
    expect(workspace).to have_sections
    expect(workspace).to have_teacher_controls
    workspace.create_activity("Feedback and questionnaires")
    expect(composer).to be_opened
    expect(composer).to have_activity_tag("edu-feedback")
    composer.fill_title("End of activity learning feedback")
    composer.submit
    expect(topic_page).to have_topic_title("End of activity learning feedback")
    expect(topic_page).to have_topic_tag("edu-feedback")
    sign_in(student)
    workspace.visit_course(course)
    expect(workspace).to have_student_controls
    workspace.open_topic("End of activity learning feedback")
    activity.vote("5 — Very useful")
    expect(activity).to have_vote
    topic_page.click_reply_button
    composer.fill_content("The discussion helped me compare and explain the evidence.")
    composer.submit
    expect(topic_page).to have_post_content(
      post_number: 2,
      content: "The discussion helped me compare and explain the evidence.",
    )
    page.refresh
    expect(activity).to have_vote
  end

  it "lets a teacher upload a PDF material and a student find and open it" do
    foreign_course = Fabricate(:educustomize_course)
    foreign_material =
      Fabricate(
        :topic_with_op,
        category: foreign_course.category,
        tags: [Tag.find_by!(name: "edu-material")],
      )
    sign_in(teacher)
    workspace.visit_course(course).create_activity("Learning materials")
    composer.fill_title("Course reading material for this week")
    composer.upload_file(Rails.root.join("spec/fixtures/pdf/small.pdf"))
    expect(composer).to have_no_in_progress_uploads
    composer.submit
    expect(topic_page).to have_topic_title("Course reading material for this week")
    expect(activity).to have_pdf_attachment
    sign_in(student)
    workspace.visit_course(course).browse_activity("Learning materials")
    expect(workspace).to have_activity("Course reading material for this week")
    expect(workspace).to have_no_activity(foreign_material.title)
    workspace.open_topic("Course reading material for this week")
    expect(activity).to have_pdf_attachment
    activity.open_pdf
    expect(activity).to have_pdf_document
  end

  it "lets teachers save reusable templates and find native editor teaching tools" do
    sign_in(teacher)
    workspace.visit_course(course).open_templates
    workspace.new_template
    composer.fill_title("Evidence-based discussion template")
    composer.fill_content("Explain your position and cite two sources supporting your argument.")
    composer.submit
    expect(topic_page).to have_topic_title("Evidence-based discussion template")
    workspace.visit_course(course).create_activity("Discussion assignments")
    composer.open_insertions
    expect(composer).to have_native_teaching_tools
    composer.insert_saved_template("Evidence-based discussion template")
    expect(composer).to have_value(/Explain your position and cite two sources/)
    composer.insert_event
    expect(composer).to have_value(/\[event start=/)
  end

  it "lets an applicant request teacher access and an administrator approve it through native groups" do
    sign_in(student)
    setup_page.request_teacher_access("I teach this subject and need to manage a new course.")
    expect(page).to have_content("I teach this subject and need to manage a new course.")
    sign_in(admin)
    setup_page.approve_teacher(teacher_group, student)
    expect(setup_page).to have_accepted_teacher(student)
    sign_in(student)
    visit("/educustomize")
    expect(setup_page).to have_course_creation
  end

  it "lets teachers assign a course task and students acknowledge its policy" do
    Jobs.run_immediately!
    sign_in(teacher)
    workspace.visit_course(course).create_activity("Discussion assignments")
    composer.fill_title("Course participation agreement for this task")
    composer.insert_policy(course.student_group)
    composer.submit
    expect(topic_page).to have_topic_title("Course participation agreement for this task")
    topic_page.click_assign_topic
    assign_modal.assignee = teacher
    assign_modal.confirm
    expect(activity).to have_assignment(teacher)
    sign_in(student)
    workspace.visit_course(course).open_topic("Course participation agreement for this task")
    activity.accept_policy
    expect(activity).to have_accepted_policy
    page.refresh
    expect(activity).to have_accepted_policy
  end

  it "lets administrators prepare teaching features from the central course setup page" do
    sign_in(admin)
    setup_page.visit_setup.prepare
    expect(setup_page).to have_prepared_features
    page.refresh
    expect(setup_page).to have_prepared_features
  end
end
