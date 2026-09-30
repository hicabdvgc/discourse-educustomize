import Component from "@glimmer/component";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

class CourseLinks extends Component {
  @service currentUser;

  get category() {
    return this.args.outletArgs?.category;
  }

  get canManage() {
    return this.currentUser?.educustomize_course_ids?.includes(
      this.category?.educustomize_course_id
    );
  }

  <template>
    {{#if this.category.educustomize_course_id}}
      {{#if this.currentUser}}<a
          class="btn educustomize__learning-link"
          href="/educustomize/courses/{{this.category.educustomize_course_id}}/learning"
        >{{i18n "educustomize.learning.title"}}</a>{{/if}}
      {{#if this.canManage}}
        <nav class="educustomize__actions">
          <a
            class="btn"
            href="/educustomize/courses/{{this.category.educustomize_course_id}}"
          >{{i18n "educustomize.manage"}}</a>
          <a
            class="btn"
            href="/educustomize/courses/{{this.category.educustomize_course_id}}#ai"
          >{{i18n "educustomize.agents"}}</a>
        </nav>
      {{/if}}
    {{/if}}
  </template>
}
class TopicLinks extends Component {
  get topic() {
    return this.args.outletArgs?.model;
  }

  <template>
    {{#if this.topic.educustomize_course}}
      <nav class="educustomize__actions">
        <a
          class="btn"
          href="/educustomize/courses/{{this.topic.educustomize_course.id}}/learning"
        >{{i18n "educustomize.learning.title"}}</a>
        {{#if this.topic.educustomize_course.can_manage}}
          <a class="btn" href="/educustomize/topics/{{this.topic.id}}">{{i18n
              "educustomize.ai_settings"
            }}</a>
        {{/if}}
      </nav>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  if (!api.container.lookup("service:site-settings").educustomize_enabled) {
    return;
  }
  if (api.getCurrentUser()) {
    api.addCommunitySectionLink({
      name: "educustomize",
      route: "educustomize",
      text: i18n("educustomize.title"),
      title: i18n("educustomize.title"),
      icon: "book",
    });
  }
  api.renderInOutlet("above-category-heading", CourseLinks);
  api.renderInOutlet("topic-above-posts", TopicLinks);
});
