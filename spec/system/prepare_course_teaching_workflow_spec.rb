# frozen_string_literal: true

RSpec.describe "Prepare course teaching workflow" do
  fab!(:admin)
  let(:setup_page) { PageObjects::Pages::EduAdmin.new }

  before do
    enable_current_plugin
    SiteSetting.default_locale = "en"
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.enable_category_group_moderation = true
    sign_in(admin)
  end

  it "lets administrators find course setup and prepare the reusable workflow" do
    setup_page.open_from_plugin_navigation
    expect(page).to have_current_path("/admin/plugins/discourse-educustomize/courses")
    expect(setup_page).to have_setup_links
    setup_page.prepare_workflow
    expect(setup_page).to have_prepared_notice
    expect(setup_page).to have_teaching_workflow
    page.refresh
    expect(setup_page).to have_teaching_workflow
    setup_page.prepare_workflow
    expect(setup_page).to have_prepared_notice
    expect(setup_page).to have_teaching_workflow
  end
end
