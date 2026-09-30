import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import EduCourseNav from "./edu-course-nav";
import EduHelp from "./edu-help";

export default class EduMaintenance extends Component {
  @tracked result = null;
  @tracked busy = false;
  @tracked filters = { topic_id: "", status: "", outcome: "" };
  @tracked refreshedSummary = null;

  get summary() {
    return this.refreshedSummary || this.args.model;
  }

  get courseUrl() {
    return "/educustomize/courses/" + this.args.model.course.id;
  }

  get dependencies() {
    return Object.entries(this.summary.dependencies).map(([key, enabled]) => ({
      label: i18n("educustomize.dependency." + key),
      state: i18n(
        "educustomize.dependency." + (enabled ? "enabled" : "disabled")
      ),
    }));
  }

  get policies() {
    return this.summary.policies.map((policy) => ({
      ...policy,
      url: "/educustomize/topics/" + policy.topic_id,
      reasons: policy.reasons.map((reason) =>
        i18n("educustomize.maintenance.reasons." + reason)
      ),
    }));
  }

  get agents() {
    return this.summary.agents.map((agent) => ({
      ...agent,
      modelLabel: i18n(
        "educustomize.dependency." +
          (agent.model_authorized ? "enabled" : "disabled")
      ),
      materials: agent.materials.map((material) => ({
        ...material,
        label: i18n(
          "educustomize.maintenance.material_status." + material.status
        ),
        progress:
          material.total > 0
            ? i18n("educustomize.maintenance.material_progress", {
                indexed: material.indexed,
                pending: material.left,
              })
            : null,
      })),
    }));
  }

  get runs() {
    return (this.result?.runs || []).map((run) => ({
      ...run,
      statusLabel: i18n("educustomize.status." + run.status),
      outcomeLabel: run.outcome
        ? i18n("educustomize.status." + run.outcome)
        : "—",
    }));
  }

  get statuses() {
    return [
      "pending",
      "running",
      "waiting",
      "success",
      "error",
      "rate_limited",
      "skipped",
      "unavailable",
    ].map((value) => ({ value, label: i18n("educustomize.status." + value) }));
  }

  get outcomes() {
    return ["published", "rejected", "superseded"].map((value) => ({
      value,
      label: i18n("educustomize.status." + value),
    }));
  }

  get previousPage() {
    return (this.result?.page || 1) - 1;
  }

  get nextPage() {
    return (this.result?.page || 1) + 1;
  }

  @action
  async load(page = 1) {
    this.busy = true;
    try {
      this.result = await ajax(this.courseUrl + "/runs.json", {
        data: { ...this.filters, page },
      });
      this.refreshedSummary = await ajax(this.courseUrl + "/maintenance.json");
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  @action
  async refresh() {
    await this.load(1);
  }

  @action
  async filter(data) {
    this.filters = { ...data };
    await this.load(1);
  }

  <template>
    <main class="educustomize" {{didInsert this.refresh}}>
      <a href={{this.courseUrl}}>{{@model.course.name}}</a>
      <EduCourseNav @course={{hash id=@model.course.id can_manage=true}} />
      <h1>{{i18n "educustomize.maintenance.title"}}</h1>
      <EduHelp @context="maintenance" @courseId={{@model.course.id}} />
      <p>{{i18n "educustomize.maintenance.help"}}</p>
      <p class="educustomize__notice">{{i18n
          "educustomize.research.retention"
          workflow=this.summary.retention.workflow_days
          ai=this.summary.retention.ai_days
        }}</p>
      <h2>{{i18n "educustomize.dependencies"}}</h2>
      <ul>{{#each this.dependencies as |dependency|}}<li>{{dependency.label}}:
            {{dependency.state}}</li>{{/each}}</ul>
      <h2>{{i18n "educustomize.ai_settings"}}</h2>
      {{#each this.policies as |policy|}}
        <section class="educustomize__card"><a
            href={{policy.url}}
          >{{policy.title}}</a>
          <ul>{{#each policy.reasons as |reason|}}<li>{{reason}}</li>{{else}}<li
              >{{i18n "educustomize.ready"}}</li>{{/each}}</ul>
        </section>
      {{else}}<p>{{i18n "educustomize.maintenance.no_policies"}}</p>{{/each}}
      <h2>{{i18n "educustomize.knowledge"}}</h2>
      {{#each this.agents as |agent|}}
        <section class="educustomize__card"><h3>{{agent.name}}</h3>
          <p>{{i18n "educustomize.model"}}: {{agent.modelLabel}}</p>
          <ul>{{#each agent.materials as |material|}}<li>{{material.name}}
                —
                {{material.label}}
                {{material.progress}}</li>{{else}}<li>{{i18n
                  "educustomize.maintenance.no_materials"
                }}</li>{{/each}}</ul>
        </section>
      {{/each}}
      <h2>{{i18n "educustomize.runs"}}</h2>
      <Form @data={{this.filters}} @onSubmit={{this.filter}} as |form|>
        <form.Field
          @name="topic_id"
          @title={{i18n "educustomize.research.topic"}}
          @type="select"
          as |field|
        ><field.Control
            @nonePlaceholder={{i18n "educustomize.research.all_topics"}}
            as |control|
          >{{#each @model.topics as |topic|}}<control.Option
                @value={{topic.id}}
              >{{topic.title}}</control.Option>{{/each}}</field.Control></form.Field>
        <form.Field
          @name="status"
          @title={{i18n "educustomize.maintenance.execution_status"}}
          @type="select"
          as |field|
        ><field.Control
            @nonePlaceholder={{i18n "educustomize.maintenance.all"}}
            as |control|
          >{{#each this.statuses as |status|}}<control.Option
                @value={{status.value}}
              >{{status.label}}</control.Option>{{/each}}</field.Control></form.Field>
        <form.Field
          @name="outcome"
          @title={{i18n "educustomize.maintenance.outcome"}}
          @type="select"
          as |field|
        ><field.Control
            @nonePlaceholder={{i18n "educustomize.maintenance.all"}}
            as |control|
          >{{#each this.outcomes as |outcome|}}<control.Option
                @value={{outcome.value}}
              >{{outcome.label}}</control.Option>{{/each}}</field.Control></form.Field>
        <form.Submit @label="educustomize.refresh" @disabled={{this.busy}} />
      </Form>
      {{#each this.runs as |run|}}
        <article class="educustomize__card">
          <p>#{{run.id}} · {{run.topic_title}}</p>
          <p>{{run.statusLabel}} / {{run.outcomeLabel}}</p>
          <a href={{run.review_url}}>{{i18n
              "educustomize.maintenance.open_run"
            }}</a>
        </article>
      {{else}}<p>{{i18n "educustomize.maintenance.no_runs"}}</p>{{/each}}
      <nav class="educustomize__actions">
        {{#if this.previousPage}}<DButton
            @label="educustomize.maintenance.previous"
            @disabled={{this.busy}}
            @action={{fn this.load this.previousPage}}
          />{{/if}}
        {{#if this.result.has_more}}<DButton
            @label="educustomize.maintenance.next"
            @disabled={{this.busy}}
            @action={{fn this.load this.nextPage}}
          />{{/if}}
      </nav>
    </main>
  </template>
}
