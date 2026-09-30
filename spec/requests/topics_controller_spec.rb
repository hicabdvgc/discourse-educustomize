# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::TopicsController do
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:topic) { Fabricate(:topic, category: course.category) }
  fab!(:own_link) { Fabricate(:educustomize_agent_link, course:) }

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.enable_category_group_moderation = true
  end

  describe "#show" do
    it "rejects an enrolled student" do
      course.student_group.add(student)
      sign_in(student)
      get "/educustomize/topics/#{topic.id}.json"
      expect(response.status).to eq(403)
    end

    it "shows safe initial settings and a not-ready indicator" do
      sign_in(teacher)
      get "/educustomize/topics/#{topic.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["policy"]).to eq(
        "reviewer_id" => teacher.id,
        "auto_reply" => false,
        "memory" => false,
        "require_review" => true,
      )
      expect(response.parsed_body["ready"]).to be_falsey
      expect(response.parsed_body["readiness_reasons"]).to eq([])
    end
  end

  describe "#show" do
    it "explains a disabled assistant and missing authorization to the course teacher" do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.enable_discourse_workflows = true
      SiteSetting.educustomize_model_ids = ""
      own_link.ai_agent.update!(enabled: false, default_llm_id: nil, tools: [])
      DiscourseEducustomize::TopicPolicy.create!(
        course: course,
        topic: topic,
        ai_agent: own_link.ai_agent,
        reviewer_id: teacher.id,
      )
      sign_in(teacher)

      get "/educustomize/topics/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["ready"]).to eq(false)
      expect(response.parsed_body["readiness_reasons"]).to contain_exactly(
        "workflow_invalid",
        "assistant_disabled",
        "model_unauthorized",
      )
    end
  end

  describe "#update" do
    it "saves native agent binding while ignoring a submitted course and revision" do
      sign_in(teacher)
      put "/educustomize/topics/#{topic.id}.json",
          params: {
            policy: {
              ai_agent_id: own_link.ai_agent_id,
              course_id: -1,
              revision: -1,
            },
          }
      expect(response.status).to eq(204)
      policy = DiscourseEducustomize::TopicPolicy.find_by!(topic:)
      expect(policy).to have_attributes(
        course_id: course.id,
        ai_agent_id: own_link.ai_agent_id,
        require_review: true,
        memory: false,
      )
      expect(policy.revision).to be > 0
    end

    it "rejects a forged reviewer from outside the course teachers" do
      sign_in(teacher)
      put "/educustomize/topics/#{topic.id}.json", params: { policy: { reviewer_id: student.id } }
      expect(response.status).to eq(403)
      expect(DiscourseEducustomize::TopicPolicy.find_by(topic:)).to eq(nil)
    end
  end
end
