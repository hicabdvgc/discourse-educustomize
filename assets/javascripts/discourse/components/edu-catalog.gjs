import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import refreshCourseCategory from "../lib/refresh-course-category";

export default class EduCatalog extends Component {
  @service router;
  @service currentUser;
  @service site;

  @tracked creating = false;
  defaults = { color: "0088CC" };

  get dependencies() {
    return Object.entries(this.args.model.dependencies || {}).map(
      ([key, enabled]) => ({
        label: i18n("educustomize.dependency." + key),
        status: i18n(
          enabled
            ? "educustomize.dependency.enabled"
            : "educustomize.dependency.disabled"
        ),
      })
    );
  }

  @action
  toggleCreate() {
    this.creating = !this.creating;
  }

  @action
  async create(data) {
    try {
      const result = await ajax("/educustomize/courses.json", {
        type: "POST",
        data: { course: data },
      });
      this.currentUser.set("educustomize_course_ids", [
        ...(this.currentUser.educustomize_course_ids || []),
        result.course.id,
      ]);
      await refreshCourseCategory(this.site, result.course);
      this.router.transitionTo("educustomize.course", result.course.id);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async join(course) {
    try {
      const result = await ajax(
        "/educustomize/courses/" + course.id + "/join.json",
        {
          type: "POST",
        }
      );
      await refreshCourseCategory(this.site, result.course);
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <main class="educustomize">
      <h1>{{i18n "educustomize.title"}}</h1>
      {{#if this.currentUser.admin}}<a
          class="btn"
          href="/admin/plugins/discourse-educustomize/courses"
        >{{i18n "educustomize.admin.title"}}</a>{{/if}}
      {{#unless @model.can_create}}{{#if @model.teacher_application_url}}<p><a
              class="btn"
              href={{@model.teacher_application_url}}
            >{{i18n
                "educustomize.learning.apply_teacher"
              }}</a></p>{{/if}}{{/unless}}
      {{#if @model.can_create}}
        <details>
          <summary>{{i18n "educustomize.dependencies"}}</summary>
          <ul>
            {{#each this.dependencies as |dependency|}}
              <li>{{dependency.label}}: {{dependency.status}}</li>
            {{/each}}
          </ul>
        </details>
      {{/if}}
      {{#if @model.can_create}}<DButton
          @label="educustomize.create"
          @action={{this.toggleCreate}}
        />{{/if}}
      {{#if this.creating}}
        <Form @data={{this.defaults}} @onSubmit={{this.create}} as |form|>
          <form.Field
            @name="name"
            @title={{i18n "educustomize.name"}}
            @type="input"
            @validation="required"
            as |field|
          ><field.Control /></form.Field>
          <form.Field
            @name="description"
            @title={{i18n "educustomize.description"}}
            @type="textarea"
            as |field|
          ><field.Control /></form.Field>
          <form.Field
            @name="color"
            @title={{i18n "educustomize.color"}}
            @type="input"
            as |field|
          ><field.Control /></form.Field>
          <form.Submit @label="educustomize.create" />
        </Form>
      {{/if}}
      {{#each @model.courses as |course|}}
        <article class="educustomize__card">
          <h2>{{course.name}}</h2>
          <p class="educustomize__description">{{course.description}}</p>
          <div class="educustomize__actions">
            {{#if course.joined}}
              <a
                class="btn btn-primary"
                href={{or course.learning_url course.category_url}}
              >{{i18n "educustomize.open"}}</a>
            {{else}}
              <DButton
                @label="educustomize.join"
                @action={{fn this.join course}}
              />
            {{/if}}
            {{#if course.can_manage}}
              <a class="btn" href="/educustomize/courses/{{course.id}}">{{i18n
                  "educustomize.manage"
                }}</a>
            {{/if}}
          </div>
        </article>
      {{else}}
        <p>{{i18n "educustomize.empty"}}</p>
      {{/each}}
    </main>
  </template>
}
