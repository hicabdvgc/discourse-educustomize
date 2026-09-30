# frozen_string_literal: true

Fabricator(:educustomize_course, class_name: "DiscourseEducustomize::Course") do
  category
  teacher_group { Fabricate(:group, visibility_level: Group.visibility_levels[:members]) }
  student_group do
    Fabricate(
      :group,
      visibility_level: Group.visibility_levels[:members],
      public_admission: true,
      public_exit: true,
    )
  end
  created_by { Fabricate(:user) }
  description "Course introduction available before enrollment."

  after_create do |course|
    course.teacher_group.add(course.created_by)
    course.student_group.add_owner(course.created_by)
    course.category.set_permissions(course.teacher_group.name => 1, course.student_group.name => 1)
    course.category.save!
    CategoryModerationGroup.create!(category: course.category, group: course.teacher_group)
  end
end
