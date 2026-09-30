import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import EduAgentFields from "./edu-agent-fields";
import EduDirtyGuard from "./edu-dirty-guard";
import EduUpload from "./edu-upload";

export default class EduAgent extends Component {
  @tracked formApi;
  @tracked uploaded = [];
  @tracked removed = [];
  skipDirtyCheck = () => false;

  constructor() {
    super(...arguments);
    this.args.onRegisterEditor?.(this);
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  get dirty() {
    return (
      this.formApi?.isDirty ||
      this.args.externalDirty ||
      this.uploaded.length > 0 ||
      this.removed.length > 0
    );
  }

  get exportUrl() {
    return `/educustomize/courses/${this.args.model.course.id}/agents/${this.args.agent.id}/configuration.json`;
  }

  get uploadUrl() {
    return (
      "/educustomize/courses/" +
      this.args.model.course.id +
      "/knowledge-upload.json"
    );
  }

  get attachments() {
    return [
      ...(this.args.agent.uploads || []),
      ...this.uploaded.map((u) => ({ id: u.id, name: u.original_filename })),
    ].filter((u) => !this.removed.includes(u.id));
  }

  @action
  removeUpload(upload) {
    this.removed = [...this.removed, upload.id];
  }

  get delegates() {
    return this.args.model.agents.filter(
      (agent) => agent.id !== this.args.agent.id && !agent.subagent_ids.length
    );
  }

  @action
  uploadedFile(upload) {
    this.removed = this.removed.filter((id) => id !== upload.id);
    if (
      !(this.args.agent.uploads || []).some((item) => item.id === upload.id) &&
      !this.uploaded.some((item) => item.id === upload.id)
    ) {
      this.uploaded = [...this.uploaded, upload];
    }
  }

  @action
  async save(data) {
    try {
      const url =
        "/educustomize/courses/" + this.args.model.course.id + "/agents";
      await ajax(
        url + (this.args.agent.id ? "/" + this.args.agent.id : "") + ".json",
        {
          type: this.args.agent.id ? "PUT" : "POST",
          contentType: "application/json",
          data: JSON.stringify({
            agent: {
              ...data,
              default_llm_id: data.default_llm_id || null,
              tools: data.tools || [],
              subagent_ids: data.subagent_ids || [],
              upload_ids: [
                ...(data.upload_ids || []),
                ...this.uploaded.map((u) => u.id),
              ].filter((id) => !this.removed.includes(id)),
            },
          }),
        }
      );
      this.formApi.commit();
      this.uploaded = [];
      this.removed = [];
      await this.args.onSaved();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <section class="educustomize__card educustomize__agent-editor">
      <EduDirtyGuard @isDirty={{this.dirty}} />
      <h3>{{if @agent.id @agent.name (i18n "educustomize.new_agent")}}</h3>
      <Form
        @data={{@agent}}
        @onSubmit={{this.save}}
        @onRegisterApi={{this.registerApi}}
        @commitOnSubmit={{false}}
        @onDirtyCheck={{this.skipDirtyCheck}}
        as |form|
      >
        <EduAgentFields
          @form={{form}}
          @rootForm={{form}}
          @skillsPath="skills"
          @model={{@model}}
          @delegateField="subagent_ids"
          @delegates={{this.delegates}}
        />
        <fieldset class="educustomize__agent-group">
          <legend>{{i18n "educustomize.knowledge"}}</legend>
          <p>{{i18n "educustomize.knowledge_help"}}</p>
          <EduUpload
            @label={{i18n "educustomize.knowledge"}}
            @accept=".pdf,.txt,.md"
            @url={{this.uploadUrl}}
            @onUpload={{this.uploadedFile}}
          />
          {{#each this.attachments as |upload|}}
            <p>{{upload.name}}
              <DButton
                @icon="xmark"
                @label="educustomize.remove_material"
                @action={{fn this.removeUpload upload}}
              /></p>
          {{/each}}
        </fieldset>
        <div class="educustomize__save-bar">
          <form.Submit @label="educustomize.ui.save_agent" />
          {{#if @onClose}}<DButton
              @label={{@backLabel}}
              @action={{@onClose}}
            />{{/if}}
          <span role="status">{{if
              this.dirty
              (i18n "educustomize.ui.unsaved")
              (i18n "educustomize.ui.no_changes")
            }}</span>
        </div>
      </Form>
      {{#if @agent.id}}
        <p>{{i18n "educustomize.configuration.export_help"}}</p>
        {{#if this.dirty}}
          <p role="status">{{i18n "educustomize.configuration.unsaved"}}</p>
          <DButton
            @label="educustomize.configuration.export"
            @disabled={{true}}
          />
        {{else}}
          <a
            class="btn btn-default educustomize__export"
            href={{this.exportUrl}}
            download
          >{{i18n "educustomize.configuration.export"}}</a>
        {{/if}}
      {{/if}}
    </section>
  </template>
}
