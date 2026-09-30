import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import EduCourseNav from "./edu-course-nav";
import EduHelp from "./edu-help";

export default class EduLearning extends Component {
  @service currentUser;

  get sections() {
    return this.args.model.kinds.map((kind) => {
      const params = new URLSearchParams({
        category_id: this.args.model.course.category_id,
        body: i18n("educustomize.learning.drafts." + kind.key),
      });
      if (kind.ready) {
        params.set("tags", kind.tag);
      }
      return {
        ...kind,
        title: i18n("educustomize.learning.kinds." + kind.key),
        help: i18n("educustomize.learning.help." + kind.key),
        createUrl: "/new-topic?" + params.toString(),
        browseUrl:
          "/tags" + this.args.model.course.category_url + "/" + kind.tag,
        canCreate:
          this.args.model.can_post &&
          (this.args.model.course.can_manage ||
            kind.key === "question" ||
            kind.key === "discussion"),
      };
    });
  }

  <template>
    <main class="educustomize">
      <a href="/educustomize">{{i18n "educustomize.back"}}</a>
      <h1>{{@model.course.name}}</h1>
      <p>{{@model.course.description}}</p>
      <EduCourseNav @course={{@model.course}} />
      {{#if @model.course.can_manage}}
        <EduHelp @context="course" @courseId={{@model.course.id}} />
      {{/if}}
      <p>{{i18n "educustomize.learning.intro"}}</p>
      <div class="educustomize__sections">
        {{#each this.sections as |activity|}}
          <section class="educustomize__card">
            <h2>{{activity.title}}</h2>
            <p>{{activity.help}}</p>
            <div class="educustomize__actions">
              {{#if activity.ready}}<a
                  class="btn"
                  href={{activity.browseUrl}}
                >{{i18n "educustomize.learning.browse"}}</a>{{else}}<p>{{i18n
                    "educustomize.learning.setup_needed"
                  }}</p>{{/if}}
              {{#if activity.canCreate}}<a
                  class="btn"
                  href={{activity.createUrl}}
                >{{i18n "educustomize.learning.create"}}</a>{{/if}}
            </div>
          </section>
        {{/each}}
      </div>
      <h2>{{i18n "educustomize.learning.recent"}}</h2>
      <ul>{{#each @model.topics as |topic|}}<li>
            <a href={{topic.url}}>{{topic.title}}</a>
            {{#if @model.course.can_manage}}
              ·
              <a href={{concat "/educustomize/topics/" topic.id}}>{{i18n
                  "educustomize.ai_settings"
                }}</a>{{/if}}
          </li>{{else}}<li>{{i18n
              "educustomize.learning.no_topics"
            }}</li>{{/each}}</ul>
      <a class="btn" href={{@model.course.category_url}}>{{i18n
          "educustomize.learning.all_discussions"
        }}</a>
      {{#if @model.course.can_manage}}
        <h2>{{i18n "educustomize.learning.teacher_tools"}}</h2>
        <p>{{i18n "educustomize.learning.native_tools"}}</p>
        <p>{{i18n "educustomize.learning.test_help"}}</p>
        {{#if @model.templates_url}}<a
            class="btn"
            href={{@model.templates_url}}
          >{{i18n "educustomize.learning.templates"}}</a>{{/if}}
        <a class="btn" href={{@model.course.members_url}}>{{i18n
            "educustomize.members"
          }}</a>
      {{/if}}
      <h2>{{i18n "educustomize.learning.account"}}</h2>
      <nav class="educustomize__actions">
        <a
          class="btn"
          href={{concat "/u/" this.currentUser.username "/preferences"}}
        >{{i18n "educustomize.learning.preferences"}}</a>
        <a class="btn" href="/chat">{{i18n "educustomize.learning.chat"}}</a>
      </nav>
    </main>
  </template>
}
