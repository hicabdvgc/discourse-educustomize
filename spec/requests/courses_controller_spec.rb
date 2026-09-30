# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::CoursesController do
  fab!(:teacher, :user)
  fab!(:student, :user)
  fab!(:approved_teachers, :group)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }
  fab!(:private_post) { Fabricate(:post, topic: Fabricate(:topic, category: course.category)) }
  let(:course_params) do
    { name: "Course request", description: "Enrollment introduction", color: "336699" }
  end

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.educustomize_teacher_group = approved_teachers.id.to_s
    approved_teachers.add(teacher)
  end

  describe "#index" do
    it "requires login" do
      get "/educustomize/courses.json"
      expect(response.status).to eq(403)
    end

    it "returns enrollment summaries without protected discussion or management data" do
      sign_in(student)
      get "/educustomize/courses.json"
      expect(response.status).to eq(200)
      summary = response.parsed_body["courses"].find { |item| item["id"] == course.id }
      expect(summary).to include(
        "description" => course.description,
        "joined" => false,
        "can_manage" => false,
      )
      expect(summary.keys).not_to include(
        "category_id",
        "category_url",
        "members_url",
        "uploaded_logo_id",
      )
      expect(response.body).not_to include(private_post.raw)
      get "/t/#{private_post.topic_id}.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#show" do
    it "returns the membership management link to the assigned teacher" do
      sign_in(teacher)
      get "/educustomize/courses/#{course.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["course"]).to include(
        "can_manage" => true,
        "members_url" => "/g/#{course.student_group.name}",
      )
    end

    it "rejects an enrolled student" do
      course.student_group.add(student)
      sign_in(student)
      get "/educustomize/courses/#{course.id}.json"
      expect(response.status).to eq(403)
    end
  end

  describe "#create" do
    it "creates a course for an approved teacher and ignores administrative fields" do
      sign_in(teacher)
      post "/educustomize/courses.json",
           params: {
             course:
               course_params.merge(
                 permissions: {
                   everyone: 1,
                 },
                 teacher_group_id: approved_teachers.id,
               ),
           }
      expect(response.status).to eq(201)
      created = DiscourseEducustomize::Course.find(response.parsed_body["course"]["id"])
      expect(created.teacher_group_id).not_to eq(approved_teachers.id)
      expect(student.guardian.can_see?(created.category)).to eq(false)
    end

    it "rejects a student who submits a teacher group identifier" do
      sign_in(student)
      expect do
        post "/educustomize/courses.json",
             params: {
               course: course_params.merge(teacher_group_id: approved_teachers.id),
             }
      end.not_to change(DiscourseEducustomize::Course, :count)
      expect(response.status).to eq(403)
    end

    it "returns a validation error for a duplicate name without orphan groups" do
      sign_in(teacher)
      expect do
        post "/educustomize/courses.json",
             params: {
               course: course_params.merge(name: course.category.name),
             }
      end.not_to change(Group, :count)
      expect(response.status).to eq(422)
    end
  end

  describe "#update" do
    it "changes permitted metadata while retaining security and teacher assignments" do
      sign_in(teacher)
      original_permissions = course.category.category_groups.pluck(:group_id, :permission_type)
      put "/educustomize/courses/#{course.id}.json",
          params: {
            course:
              course_params.merge(
                permissions: {
                  everyone: 1,
                },
                teacher_group_id: approved_teachers.id,
              ),
          }
      expect(response.status).to eq(200)
      expect(course.reload.category.reload.name).to eq(course_params[:name])
      expect(course.category.category_groups.pluck(:group_id, :permission_type)).to eq(
        original_permissions,
      )
      expect(course.teacher_group_id).not_to eq(approved_teachers.id)
    end

    it "rejects a teacher assigned to a different course" do
      another_course = Fabricate(:educustomize_course)
      sign_in(teacher)
      put "/educustomize/courses/#{another_course.id}.json", params: { course: course_params }
      expect(response.status).to eq(403)
      expect(another_course.category.reload.name).not_to eq(course_params[:name])
    end
  end

  describe "#join" do
    it "grants native course visibility and makes repeated enrollment harmless" do
      sign_in(student)
      expect do 2.times { post "/educustomize/courses/#{course.id}/join.json" } end.to change {
        course.student_group.group_users.where(user: student).count
      }.by(1)
      expect(response.status).to eq(200)
      expect(response.parsed_body["course"]).to include(
        "joined" => true,
        "category_id" => course.category_id,
      )
      get "/t/#{private_post.topic_id}.json"
      expect(response.status).to eq(200)
      expect(response.body).to include(private_post.raw)
    end

    it "respects an administrator closing self enrollment" do
      course.student_group.update!(public_admission: false)
      sign_in(student)
      post "/educustomize/courses/#{course.id}/join.json"
      expect(response.status).to eq(403)
      expect(course.student_group.users).not_to include(student)
    end
  end
end
