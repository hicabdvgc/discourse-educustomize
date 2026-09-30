# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::AdminController do
  fab!(:admin)
  fab!(:teacher, :user)
  fab!(:teacher_group, :group)

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.educustomize_teacher_group = teacher_group.id.to_s
  end

  describe "#prepare_teaching" do
    it "requires administrator authorization" do
      post "/educustomize/admin/teaching.json"
      expect(response.status).to eq(403)
      sign_in(teacher)
      post "/educustomize/admin/teaching.json"
      expect(response.status).to eq(403)
    end

    it "returns successful preparation through the administrator endpoint" do
      sign_in(admin)
      post "/educustomize/admin/teaching.json"
      expect(response.status).to eq(200)
      expect(teacher_group.reload.allow_membership_requests).to eq(true)
    end

    it "explains when an unsafe teacher group blocks preparation" do
      teacher_group.update!(public_admission: true)
      sign_in(admin)
      post "/educustomize/admin/teaching.json"
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to be_present
      expect(teacher_group.reload.allow_membership_requests).to eq(false)
    end
  end
end
