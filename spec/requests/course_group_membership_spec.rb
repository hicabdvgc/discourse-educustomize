# frozen_string_literal: true

RSpec.describe GroupsController do
  fab!(:teacher, :user)
  fab!(:replacement_teacher, :user)
  fab!(:student, :user)
  fab!(:new_student, :user)
  fab!(:course) { Fabricate(:educustomize_course, created_by: teacher) }

  before do
    SiteSetting.educustomize_enabled = true
    SiteSetting.enable_category_group_moderation = true
    course.student_group.add(student)
  end

  describe "#add_members" do
    it "allows a newly appointed teacher to manage native course membership" do
      course.teacher_group.add(replacement_teacher)
      expect(course.student_group.group_users.find_by(user: replacement_teacher)).to be_owner
      sign_in(replacement_teacher)
      put "/groups/#{course.student_group_id}/members.json",
          params: {
            usernames: new_student.username,
          }
      expect(response.status).to eq(200), response.body
      expect(course.student_group.users).to include(new_student)
    end

    it "rejects a revoked teacher even when a stale owner flag remains" do
      course.teacher_group.remove(teacher)
      expect(course.student_group.group_users.find_by(user: teacher)).not_to be_owner
      course.student_group.group_users.find_by(user: teacher).update!(owner: true)
      sign_in(teacher)
      put "/groups/#{course.student_group_id}/members.json",
          params: {
            usernames: new_student.username,
          }
      expect(response.status).to eq(403)
      expect(course.student_group.users).not_to include(new_student)
    end

    it "rejects a teacher assigned to another course" do
      another_course = Fabricate(:educustomize_course)
      sign_in(teacher)
      put "/groups/#{another_course.student_group_id}/members.json",
          params: {
            usernames: new_student.username,
          }
      expect(response.status).to eq(403)
    end

    it "respects category visibility when the teacher group remains assigned" do
      course.category.set_permissions(Group[:admins].name => 1)
      course.category.save!
      sign_in(teacher)
      put "/groups/#{course.student_group_id}/members.json",
          params: {
            usernames: new_student.username,
          }
      expect(response.status).to eq(403)
    end
  end

  describe "#remove_member" do
    it "allows the replacement teacher and denies the revoked teacher" do
      course.teacher_group.add(replacement_teacher)
      course.teacher_group.remove(teacher)
      sign_in(teacher)
      delete "/groups/#{course.student_group_id}/members.json",
             params: {
               usernames: student.username,
             }
      expect(response.status).to eq(403)
      expect(course.student_group.users).to include(student)
      sign_in(replacement_teacher)
      delete "/groups/#{course.student_group_id}/members.json",
             params: {
               usernames: student.username,
             }
      expect(response.status).to eq(200), response.body
      expect(course.student_group.users).not_to include(student)
    end
  end
  describe "#update" do
    it "restricts course enrollment settings to administrators" do
      sign_in(teacher)
      put "/groups/#{course.student_group_id}.json",
          params: {
            group: {
              public_admission: false,
              public_exit: false,
            },
          }
      expect(response.status).to eq(403)
      expect(course.student_group.reload).to be_public_admission
      expect(course.student_group).to be_public_exit
      sign_in(Fabricate(:admin))
      put "/groups/#{course.student_group_id}.json",
          params: {
            group: {
              public_admission: false,
              public_exit: false,
            },
          }
      expect(response.status).to eq(200), response.body
      expect(course.student_group.reload).not_to be_public_admission
    end

    it "preserves native owner settings for unrelated groups" do
      unrelated_group = Fabricate(:group, public_admission: true)
      unrelated_group.add_owner(teacher)
      sign_in(teacher)
      put "/groups/#{unrelated_group.id}.json", params: { group: { public_admission: false } }
      expect(response.status).to eq(200), response.body
      expect(unrelated_group.reload).not_to be_public_admission
    end
  end

  describe "#add_owners" do
    it "rejects course student-group owner assignment by a teacher" do
      sign_in(teacher)
      put "/groups/#{course.student_group_id}/owners.json", params: { usernames: student.username }
      expect(response.status).to eq(403)
      expect(course.student_group.group_users.find_by(user: student)).not_to be_owner
    end

    it "preserves administrator assignment of course group owners" do
      sign_in(Fabricate(:admin))
      put "/groups/#{course.student_group_id}/owners.json", params: { usernames: student.username }
      expect(response.status).to eq(200), response.body
      expect(course.student_group.group_users.find_by(user: student)).to be_owner
    end
  end

  describe "course teacher appointments" do
    before { course.teacher_group.add_owner(teacher) }

    it "rejects membership and owner changes even by a native teacher-group owner" do
      sign_in(teacher)
      put "/groups/#{course.teacher_group_id}/members.json",
          params: {
            usernames: replacement_teacher.username,
          }
      expect(response.status).to eq(403)
      put "/groups/#{course.teacher_group_id}/owners.json", params: { usernames: student.username }
      expect(response.status).to eq(403)
      delete "/groups/#{course.teacher_group_id}/members.json",
             params: {
               usernames: teacher.username,
             }
      expect(response.status).to eq(403)
      expect(course.teacher_group.users).to contain_exactly(teacher)
    end

    it "preserves administrator teacher appointments and student-group owner synchronization" do
      sign_in(Fabricate(:admin))
      put "/groups/#{course.teacher_group_id}/members.json",
          params: {
            usernames: replacement_teacher.username,
          }
      expect(response.status).to eq(200), response.body
      expect(course.teacher_group.users).to include(replacement_teacher)
      expect(course.student_group.group_users.find_by(user: replacement_teacher)).to be_owner
      delete "/groups/#{course.teacher_group_id}/members.json",
             params: {
               usernames: teacher.username,
             }
      expect(response.status).to eq(200), response.body
      expect(course.teacher_group.users).not_to include(teacher)
      expect(course.student_group.group_users.find_by(user: teacher)).not_to be_owner
    end

    it "rejects teacher self-enrollment if native admission is accidentally enabled" do
      course.teacher_group.update!(public_admission: true)
      sign_in(student)
      put "/groups/#{course.teacher_group_id}/join.json"
      expect(response.status).to eq(403)
      expect(course.teacher_group.users).not_to include(student)
    end
  end
end
