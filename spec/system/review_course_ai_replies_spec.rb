# frozen_string_literal: true

RSpec.describe "Review course AI replies" do
  fab!(:admin)
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:model, :fake_model)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:topic) { Fabricate(:topic, category: course.category, user: teacher) }
  fab!(:opening_post) { Fabricate(:post, topic:, user: teacher) }
  fab!(:student_post) { Fabricate(:post, topic:, user: student) }
  let(:ai_page) { PageObjects::Pages::EduTopic.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:notification) { PageObjects::Modals::Base.new }

  before do
    enable_current_plugin
    SiteSetting.default_locale = "en"
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.educustomize_model_ids = model.id.to_s
    course.student_group.add(student)
    @assistant =
      Fabricate(:ai_agent, default_llm_id: model.id, allowed_group_ids: [course.teacher_group_id])
    course.agent_links.create!(ai_agent: @assistant)
    @workflow = DiscourseEducustomize::WorkflowTemplate.install!(admin)
    Jobs.run_immediately!
    sign_in(teacher)
  end

  after { AiAgent.agent_cache.flush! }

  it "lets the teacher approve edits, reject drafts and review a regenerated reply" do
    ai_page.visit_settings(topic).configure(assistant: @assistant, workflow: @workflow)
    expect(ai_page).to have_ready_notice
    page.refresh
    expect(ai_page).to have_ready_notice
    responses = [
      "Initial teaching draft.",
      "Rejected teaching draft.",
      "Outdated teaching draft.",
      "Regenerated teaching draft.",
    ]
    DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
      ai_page.generate_reply(student_post)
      expect(notification).to be_open
      notification.close
      expect(ai_page.latest_reply).to have_draft("Initial teaching draft.")
      ai_page.latest_reply.approve(draft: "The teacher edited this published explanation.")
      expect(ai_page.latest_reply).to have_published_draft(
        "The teacher edited this published explanation.",
      )
      page.refresh
      expect(ai_page.latest_reply).to have_published_draft(
        "The teacher edited this published explanation.",
      )
      expect(notification).to be_closed
      topic_page.visit_topic(topic)
      expect(topic_page).to have_post_content(
        post_number: 3,
        content: "The teacher edited this published explanation.",
      )
      ai_page.visit_settings(topic).generate_reply(student_post)
      expect(notification).to be_open
      notification.close
      expect(ai_page.latest_reply).to have_draft("Rejected teaching draft.")
      ai_page.latest_reply.reject
      expect(ai_page.latest_reply).to have_rejected_status
      expect(notification).to be_closed
      ai_page.generate_reply(student_post)
      expect(notification).to be_open
      notification.close
      expect(ai_page.latest_reply).to have_draft("Outdated teaching draft.")
      ai_page.latest_reply.regenerate
      expect(notification).to be_open
      notification.close
      expect(ai_page.latest_reply).to have_draft("Regenerated teaching draft.")
      page.refresh
      expect(ai_page.latest_reply).to have_draft("Regenerated teaching draft.")
      topic_page.visit_topic(topic)
      expect(page).to have_no_content("Rejected teaching draft.")
      expect(page).to have_no_content("Outdated teaching draft.")
      expect(page).to have_no_content("Regenerated teaching draft.")
    end
  end
  it "automatically publishes exactly one reply to a student post entered through the composer" do
    SiteSetting.fast_typing_threshold = "disabled"
    SiteSetting.approve_unless_allowed_groups = "1|2|#{course.student_group_id}"
    ai_page.visit_settings(topic).configure(assistant: @assistant, workflow: @workflow)
    expect(ai_page).to have_ready_notice
    ai_page.enable_automatic_discussion_context
    expect(ai_page).to have_saved_notice
    sign_in(student)
    topic_page.visit_topic(topic)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["Automatic teaching response to this student question."],
    ) do
      topic_page.click_reply_button
      topic_page.send_reply("Here is my new student question about this lesson.")
      expect(topic_page).to have_post_content(
        post_number: 3,
        content: "Here is my new student question about this lesson.",
      )
      page.refresh
      expect(topic_page).to have_post_content(
        post_number: 4,
        content: "Automatic teaching response to this student question.",
      )
      expect(ai_page).to have_no_native_post(5)
      sign_in(teacher)
      topic_page.visit_topic(topic)
      expect(topic_page).to have_post_content(
        post_number: 4,
        content: "Automatic teaching response to this student question.",
      )
      ai_page.visit_settings(topic)
      expect(ai_page.latest_reply).to have_published_draft(
        "Automatic teaching response to this student question.",
      )
    end
  end

  it "keeps the teacher's Bloc, automatic response and discussion context choices after refresh" do
    dais =
      Fabricate(
        :ai_agent,
        name: "UI topic teaching Bloc",
        default_llm_id: model.id,
        allowed_group_ids: [course.teacher_group_id],
        subagent_ids: [@assistant.id],
      )
    course.agent_links.create!(ai_agent: dais)
    ai_page.visit_settings(topic).configure(assistant: dais, workflow: @workflow)
    expect(ai_page).to have_ready_notice
    page.refresh
    ai_page.enable_automatic_discussion_context
    expect(ai_page).to have_saved_notice
    page.refresh
    expect(ai_page).to have_automatic_discussion_context
    expect(ai_page).to have_selected_assistant(dais)
  end
end
