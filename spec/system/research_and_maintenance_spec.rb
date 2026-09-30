# frozen_string_literal: true

RSpec.describe "Research and maintenance" do
  fab!(:admin)
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:model, :fake_model)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:topic) { Fabricate(:topic, category: course.category, user: teacher) }
  fab!(:opening_post) { Fabricate(:post, topic: topic, user: teacher) }
  fab!(:student_post) do
    Fabricate(
      :post,
      topic: topic,
      user: student,
      raw: "Evidence supports this learning explanation.",
    )
  end

  let(:research) { PageObjects::Pages::EduResearch.new }
  let(:operations) { PageObjects::Pages::EduOperations.new }
  let(:administration) { PageObjects::Pages::EduResearchAdmin.new }
  let(:catalog) { PageObjects::Pages::EduCourses.new }

  before do
    enable_current_plugin
    SiteSetting.default_locale = "en"
    SiteSetting.data_explorer_enabled = true
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.educustomize_model_ids = model.id.to_s
    course.student_group.add(student)
  end

  it "lets teachers preview teaching reports and download the same discussion text" do
    sign_in(teacher)
    research.open_from_course(course).preview
    expect(research).to have_post(student_post)
    csv = research.download_csv
    expect(research).to have_download_notice
    expect(csv.map { |row| row.fetch("text") }).to include(student_post.raw)
    expect(csv.headers).to include("post_id", "user_id", "created_at_utc")
    research.preview(view: "AI replies and review · Drafts and review outcomes")
    expect(research).to have_column("Generated draft")
    expect(research).to have_empty_result
    research.preview(view: "AI usage · LLM call details")
    expect(research).to have_column("Input tokens")
    expect(research).to have_empty_result
    research.preview(view: "Polls and feedback · Poll results")
    expect(research).to have_column("Votes")
    expect(research).to have_empty_result
  end

  it "lets teachers filter rejected runs and open their existing review record" do
    agent =
      Fabricate(:ai_agent, default_llm_id: model.id, allowed_group_ids: [course.teacher_group_id])
    course.agent_links.create!(ai_agent: agent)
    workflow = DiscourseEducustomize::WorkflowTemplate.install!(admin)
    policy =
      DiscourseEducustomize::TopicPolicy.create!(
        topic: topic,
        course: course,
        ai_agent: agent,
        reviewer: teacher,
        workflow_id: workflow.id,
      )
    execution = Fabricate(:discourse_workflows_completed_execution, workflow: workflow)
    Fabricate(
      :discourse_workflows_execution_data,
      execution: execution,
      data: {
        "context" => {
          "Generate" => [{ "json" => { "draft" => "Research review sample." } }],
          "Review" => [{ "json" => { "button" => "reject" } }],
        },
      },
    )
    run =
      DiscourseEducustomize::Run.create!(
        topic_policy: policy,
        post: student_post,
        actor: teacher,
        execution: execution,
        configuration_digest: DiscourseEducustomize::AiConfiguration.digest(policy),
        request_key: SecureRandom.uuid,
      )
    sign_in(teacher)
    operations.open_from_course(course)
    expect(operations).to have_run(run, status: "Execution succeeded", outcome: "Rejected")
    expect(operations).to have_no_retention_controls
    operations.filter(status: "Queued")
    expect(operations).to have_no_matching_runs
    operations.filter(status: "Execution succeeded", outcome: "Rejected")
    expect(operations).to have_run(run, status: "Execution succeeded", outcome: "Rejected")
    page.current_window.resize_to(1200, 800)
    operations.open_run(run)
    expect(page).to have_current_path("/educustomize/topics/#{topic.id}?run_id=#{run.id}")
    expect(operations).to have_review_record(run)
  end

  it "lets administrators find course tools and retain an updated cleanup period after refresh" do
    sign_in(admin)
    administration.open
    expect(administration).to have_course_tools(course)
    administration.set_retention(45)
    expect(administration).to have_saved_notice
    page.refresh
    expect(administration).to have_retention(45)
    expect(administration).to have_course_tools(course)
  end

  it "explains disabled exports to teachers and keeps management links hidden from students" do
    SiteSetting.data_explorer_enabled = false
    sign_in(teacher)
    research.open_from_course(course)
    expect(research).to have_disabled_notice
    operations.open_from_course(course)
    expect(operations).to have_no_retention_controls
    sign_in(student)
    catalog.visit_catalog
    expect(research).to have_no_management_links
    catalog.enter_course(course)
    expect(research).to have_no_management_links
  end
end
