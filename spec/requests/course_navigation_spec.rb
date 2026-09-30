# frozen_string_literal: true

RSpec.describe TopicsController do
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:topic) { Fabricate(:topic_with_op, category: course.category) }

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.enable_category_group_moderation = true
  end

  describe "#show" do
    it "returns a course workspace link with role-appropriate management authorization" do
      course.student_group.add(student)
      { student => false, teacher => true }.each do |actor, can_manage|
        sign_in(actor)
        get "/t/#{topic.id}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["educustomize_course"]).to eq(
          "id" => course.id,
          "can_manage" => can_manage,
        )
      end
    end

    it "protects the course's native Topic from nonmembers" do
      sign_in(student)
      get "/t/#{topic.id}.json"
      expect(response.status).to eq(404)
      expect(response.body).not_to include(topic.title)
    end

    it "omits management metadata for anonymous readers of an administrator-opened category" do
      course.category.set_permissions(everyone: CategoryGroup.permission_types[:full])
      course.category.save!
      get "/t/#{topic.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["educustomize_course"]).to eq(nil)
    end
  end
end
