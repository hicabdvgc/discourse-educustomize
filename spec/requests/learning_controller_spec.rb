# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::LearningController do
  fab!(:teacher) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:student) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:discussion) do
    Fabricate(:topic_with_op, category: course.category, title: "Teaching discussion")
  end
  fab!(:other_course, :educustomize_course)
  fab!(:private_discussion) do
    Fabricate(:topic_with_op, category: other_course.category, title: "Another course secret")
  end

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.enable_category_group_moderation = true
  end

  describe "#show" do
    it "requires authentication" do
      get "/educustomize/courses/#{course.id}/learning.json"
      expect(response.status).to eq(403)
    end

    it "rejects a student who has not enrolled" do
      sign_in(student)
      get "/educustomize/courses/#{course.id}/learning.json"
      expect(response.status).to eq(403)
      expect(response.body).not_to include(discussion.title)
    end

    it "returns the enrolled student's course workspace without teacher controls or foreign topics" do
      course.student_group.add(student)
      sign_in(student)
      get "/educustomize/courses/#{course.id}/learning.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["course"]).to include(
        "can_manage" => false,
        "learning_url" => "/educustomize/courses/#{course.id}/learning",
      )
      expect(response.parsed_body["course"].keys).not_to include("members_url", "uploaded_logo_id")
      expect(response.parsed_body["topics"].pluck("id")).to eq([discussion.id])
      expect(response.parsed_body["kinds"].pluck("key")).to eq(
        %w[discussion announcement material question feedback],
      )
      expect(response.parsed_body["templates_url"]).to eq(nil)
      expect(response.parsed_body["can_post"]).to eq(true)
      expect(response.body).not_to include(private_discussion.title)
    end

    it "allows the assigned teacher and administrator to enter the course workspace" do
      [teacher, admin].each do |actor|
        sign_in(actor)
        get "/educustomize/courses/#{course.id}/learning.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["course"]).to include(
          "can_manage" => true,
          "members_url" => "/g/#{course.student_group.name}",
        )
      end
    end

    it "applies changed membership and topic categories on each request" do
      course.student_group.add(student)
      sign_in(student)
      discussion.update!(category: other_course.category)
      get "/educustomize/courses/#{course.id}/learning.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["topics"]).to eq([])
      course.student_group.remove(student)
      get "/educustomize/courses/#{course.id}/learning.json"
      expect(response.status).to eq(403)
    end
  end
end
