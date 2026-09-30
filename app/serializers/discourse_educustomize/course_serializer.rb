# frozen_string_literal: true
module DiscourseEducustomize
  class CourseSerializer < ApplicationSerializer
    attributes :id, :name, :description, :color, :joined, :can_manage
    attributes :learning_url
    def learning_url
      "/educustomize/courses/#{object.id}/learning"
    end
    def include_learning_url?
      joined
    end
    attributes :category_id, :category_url, :members_url, :uploaded_logo_id, :uploaded_background_id
    def name
      object.category.name
    end
    def color
      object.category.color
    end
    def joined
      scope.can_see?(object.category)
    end
    def can_manage
      Access.teacher?(scope.user, object)
    end
    def category_url
      object.category.url
    end
    def members_url
      "/g/#{object.student_group.name}"
    end
    def uploaded_logo_id
      object.category.uploaded_logo_id
    end
    def uploaded_background_id
      object.category.uploaded_background_id
    end
    def include_members_url?
      can_manage
    end
    def include_category_id?
      joined
    end
    def include_category_url?
      joined
    end
    def include_uploaded_logo_id?
      can_manage
    end
    def include_uploaded_background_id?
      can_manage
    end
  end
end
