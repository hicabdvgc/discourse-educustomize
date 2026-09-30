import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import EduCourseNav from "./edu-course-nav";
import EduHelp from "./edu-help";

export default class EduReports extends Component {
  @service session;

  @tracked result = null;
  @tracked busy = false;
  @tracked downloaded = false;

  fields = (key) =>
    (
      this.args.model.reports.find((report) => report.key === key)?.columns ||
      []
    ).map((column) => ({
      key: column,
      label: i18n("educustomize.research.fields." + column),
    }));

  get defaults() {
    const today = new Date();
    const start = new Date();
    start.setDate(today.getDate() - 29);
    const date = (value) => {
      const offset = value.getTimezoneOffset() * 60000;
      return new Date(value.getTime() - offset).toISOString().slice(0, 10);
    };
    return {
      report: "discussions",
      start_date: date(start),
      end_date: date(today),
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC",
      topic_id: "",
      file_format: "csv",
    };
  }

  get reports() {
    return this.args.model.reports.map((report) => ({
      ...report,
      label:
        i18n("educustomize.research.groups." + report.group) +
        " · " +
        i18n("educustomize.research.views." + report.key),
    }));
  }

  get headings() {
    return (this.result?.columns || []).map((column) => ({
      key: column,
      label: i18n("educustomize.research.fields." + column),
    }));
  }

  get rows() {
    return (this.result?.rows || []).map((row) =>
      row.map((value) =>
        value === null || value === undefined
          ? i18n("educustomize.research.missing")
          : String(value)
      )
    );
  }

  get courseUrl() {
    return "/educustomize/courses/" + this.args.model.course.id;
  }

  @action
  async preview(data) {
    this.busy = true;
    this.result = null;
    this.downloaded = false;
    try {
      this.result = await ajax(
        this.courseUrl + "/reports/" + data.report + "/preview.json",
        {
          type: "POST",
          data,
        }
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  @action
  async download(data) {
    this.busy = true;
    this.downloaded = false;
    try {
      const response = await fetch(
        getURL(this.courseUrl + "/reports/" + data.report + "/download.json"),
        {
          method: "POST",
          credentials: "same-origin",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": this.session.csrfToken,
            "X-Requested-With": "XMLHttpRequest",
          },
          body: JSON.stringify(data),
        }
      );
      if (!response.ok) {
        const error = await response.json();
        popupAjaxError({
          jqXHR: { responseJSON: error, status: response.status },
        });
        return;
      }
      const url = URL.createObjectURL(await response.blob());
      const link = document.createElement("a");
      link.href = url;
      link.download =
        "course-" +
        this.args.model.course.id +
        "-" +
        data.report +
        "." +
        data.file_format;
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      this.downloaded = true;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  <template>
    <main class="educustomize">
      <a href={{this.courseUrl}}>{{@model.course.name}}</a>
      <EduCourseNav @course={{hash id=@model.course.id can_manage=true}} />
      <h1>{{i18n "educustomize.research.title"}}</h1>
      <EduHelp @context="reports" @courseId={{@model.course.id}} />
      <p>{{i18n "educustomize.research.help"}}</p>
      <p class="educustomize__notice">{{i18n
          "educustomize.research.retention"
          workflow=@model.retention.workflow_days
          ai=@model.retention.ai_days
        }}</p>
      {{#if @model.available}}
        <Form @data={{this.defaults}} @onSubmit={{this.preview}} as |form data|>
          <form.Field
            @name="report"
            @title={{i18n "educustomize.research.report"}}
            @type="select"
            @validation="required"
            as |field|
          >
            <field.Control as |control|>{{#each
                this.reports
                as |report|
              }}<control.Option
                  @value={{report.key}}
                >{{report.label}}</control.Option>{{/each}}</field.Control>
          </form.Field>
          <details class="educustomize__fields">
            <summary>{{i18n "educustomize.research.field_dictionary"}}</summary>
            <p>{{i18n "educustomize.research.field_help"}}</p>
            <dl>{{#each (this.fields data.report) as |field|}}<dt><code
                  >{{field.key}}</code></dt><dd
                >{{field.label}}</dd>{{/each}}</dl>
          </details>
          <form.Field
            @name="start_date"
            @title={{i18n "educustomize.research.start"}}
            @type="input"
            @validation="required"
            as |field|
          ><field.Control @type="date" /></form.Field>
          <form.Field
            @name="end_date"
            @title={{i18n "educustomize.research.end"}}
            @type="input"
            @validation="required"
            as |field|
          ><field.Control @type="date" /></form.Field>
          <form.Field
            @name="timezone"
            @title={{i18n "educustomize.research.timezone"}}
            @type="input"
            @validation="required"
            as |field|
          ><field.Control /></form.Field>
          <form.Field
            @name="topic_id"
            @title={{i18n "educustomize.research.topic"}}
            @type="select"
            as |field|
          >
            <field.Control
              @nonePlaceholder={{i18n "educustomize.research.all_topics"}}
              as |control|
            >{{#each @model.topics as |topic|}}<control.Option
                  @value={{topic.id}}
                >{{topic.title}}</control.Option>{{/each}}</field.Control>
          </form.Field>
          <form.Field
            @name="file_format"
            @title={{i18n "educustomize.research.format"}}
            @type="select"
            @validation="required"
            as |field|
          ><field.Control as |control|><control.Option
                @value="csv"
              >CSV</control.Option><control.Option
                @value="json"
              >JSON</control.Option></field.Control></form.Field>
          <div class="educustomize__actions">
            <form.Submit
              @label="educustomize.research.preview"
              @disabled={{this.busy}}
            />
            <DButton
              @label="educustomize.research.download"
              @disabled={{this.busy}}
              @action={{fn this.download data}}
            />
          </div>
        </Form>
        {{#if this.downloaded}}<p role="status">{{i18n
              "educustomize.research.downloaded"
            }}</p>{{/if}}
        {{#if this.result}}
          {{#if this.result.truncated}}<p role="status">{{i18n
                "educustomize.research.truncated"
              }}</p>{{/if}}
          <div
            class="educustomize__table-scroll"
            tabindex="0"
            role="region"
            aria-label={{i18n "educustomize.research.preview"}}
          >
            <table class="educustomize__table">
              <thead><tr>{{#each this.headings as |heading|}}<th
                      scope="col"
                      title={{heading.key}}
                    >{{heading.label}}</th>{{/each}}</tr></thead>
              <tbody>{{#each this.rows as |row|}}<tr>{{#each row as |value|}}<td
                      >{{value}}</td>{{/each}}</tr>{{/each}}</tbody>
            </table>
          </div>
          {{#unless this.result.rows.length}}<p role="status">{{i18n
                "educustomize.research.empty"
              }}</p>{{/unless}}
        {{/if}}
      {{else}}
        <p role="status">{{i18n "educustomize.research.unavailable"}}</p>
      {{/if}}
    </main>
  </template>
}
