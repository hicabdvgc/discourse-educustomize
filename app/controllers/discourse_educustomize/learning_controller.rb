# frozen_string_literal: true

module DiscourseEducustomize
  class LearningController < BaseController
    def show
      course = find_course
      Access.ensure_visible!(guardian, course)
      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          topics =
            Topic.secured(guardian).where(
              category_id: course.category_id,
              archetype: Archetype.default,
              deleted_at: nil,
            )
          templates = TeachingFeatures.template_category
          render json: {
                   course: CourseSerializer.new(course, scope: guardian, root: false).as_json,
                   can_post: guardian.can_create_topic_on_category?(course.category),
                   kinds:
                     TeachingFeatures::KINDS.map { |kind|
                       {
                         key: kind,
                         tag: TeachingFeatures.tag(kind),
                         ready:
                           SiteSetting.tagging_enabled &&
                             Tag.exists?(name: TeachingFeatures.tag(kind)),
                       }
                     },
                   topics:
                     topics
                       .where.not(id: course.category.topic_id)
                       .order(bumped_at: :desc)
                       .limit(20)
                       .map { |topic|
                         { id: topic.id, title: topic.title, url: topic.relative_url }
                       },
                   templates_url: templates && guardian.can_see?(templates) ? templates.url : nil,
                   features:
                     TeachingFeatures::SWITCHES.to_h { |name|
                       [name, SiteSetting.public_send(name)]
                     },
                 }
        end
      end
    end
  end
end
