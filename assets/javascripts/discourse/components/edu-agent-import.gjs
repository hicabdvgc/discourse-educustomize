import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import confirmEduDiscard from "../lib/confirm-edu-discard";
import EduAgentFields from "./edu-agent-fields";
import EduDirtyGuard from "./edu-dirty-guard";

export default class EduAgentImport extends Component {
  @service dialog;

  @tracked selectedKey;
  @tracked formApi;
  @tracked file;
  @tracked preview;
  @tracked error;
  @tracked busy = false;
  skipDirtyCheck = () => false;

  constructor() {
    super(...arguments);
    this.args.onRegisterEditor?.(this);
  }

  get dirty() {
    return Boolean(this.preview);
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  selectAgent(key) {
    this.selectedKey = key;
  }

  get base() {
    return `/educustomize/courses/${this.args.model.course.id}/agent-configurations`;
  }

  get delegates() {
    return (this.preview?.agents || [])
      .filter((agent) => agent.key !== this.preview.root)
      .map((agent) => ({
        id: agent.key,
        name: agent.name,
        description: agent.description,
      }));
  }

  @action
  choose(event) {
    const file = event.target.files[0];
    confirmEduDiscard(this.dialog, this.dirty, () => {
      this.file = file;
      this.preview = null;
      this.error = null;
    });
    event.target.value = "";
  }

  @action
  cancel() {
    confirmEduDiscard(this.dialog, this.dirty, () => {
      this.preview = null;
      this.error = null;
    });
  }

  @action
  async validate() {
    if (!this.file || this.busy) {
      return;
    }
    this.busy = true;
    this.error = null;
    try {
      let document;
      try {
        document = JSON.parse((await this.file.text()).replace(/^\uFEFF/, ""));
      } catch {
        this.error = i18n("educustomize.configuration.invalid_json");
        return;
      }
      const result = await ajax(this.base + "/preview.json", {
        type: "POST",
        contentType: "application/json",
        data: JSON.stringify({ document }),
      });
      this.selectedKey = result.document.root;
      this.preview = {
        ...result.document,
        agents: result.document.agents.map((agent) => ({
          ...agent,
          default_llm_id: result.model_mappings[agent.key],
        })),
      };
    } catch (error) {
      this.error = extractError(error, i18n("educustomize.ui.request_failed"));
    } finally {
      this.busy = false;
    }
  }

  @action
  validateFields(data, { addError }) {
    const invalid = data.agents.find(
      (agent) =>
        !agent.name?.trim() ||
        !agent.description?.trim() ||
        !agent.system_prompt?.trim() ||
        agent.skills.some(
          (skill) => !skill.name?.trim() || !skill.instructions?.trim()
        ) ||
        (agent.model && !agent.default_llm_id)
    );
    if (invalid) {
      this.selectedKey = invalid.key;
      if (invalid.model && !invalid.default_llm_id) {
        this.error = i18n("educustomize.configuration.model_required");
        const index = data.agents.indexOf(invalid);
        addError(`agents.${index}.default_llm_id`, {
          title: i18n("educustomize.model"),
          message: this.error,
        });
      }
    }
  }

  @action
  async create(data) {
    if (this.busy) {
      return;
    }
    this.error = null;
    const modelMappings = {};
    const agents = data.agents.map(({ default_llm_id: modelId, ...agent }) => {
      const target = this.args.model.models.find(
        (model) => model.id === Number(modelId)
      );
      modelMappings[agent.key] = target?.id || null;
      return {
        ...agent,
        model: target
          ? {
              provider: target.provider,
              name: target.model_name,
              display_name: target.name,
            }
          : agent.model,
        temperature:
          agent.temperature === "" || agent.temperature == null
            ? null
            : Number(agent.temperature),
        top_p:
          agent.top_p === "" || agent.top_p == null
            ? null
            : Number(agent.top_p),
      };
    });
    if (agents.some((agent) => agent.model && !modelMappings[agent.key])) {
      this.error = i18n("educustomize.configuration.model_required");
      return;
    }
    this.busy = true;
    try {
      const result = await ajax(this.base + ".json", {
        type: "POST",
        contentType: "application/json",
        data: JSON.stringify({
          document: {
            format: data.format,
            schema_version: data.schema_version,
            root: data.root,
            agents,
          },
          model_mappings: modelMappings,
        }),
      });
      this.preview = null;
      await this.args.onImported(result.agent_id);
    } catch (error) {
      this.error = extractError(error, i18n("educustomize.ui.request_failed"));
    } finally {
      this.busy = false;
    }
  }

  <template>
    <section class="educustomize__card educustomize__import">
      <EduDirtyGuard @isDirty={{this.dirty}} />
      <h3>{{i18n "educustomize.configuration.import"}}</h3>
      <label class="educustomize__upload">
        {{i18n "educustomize.configuration.file"}}
        <input
          type="file"
          accept=".json,application/json"
          {{on "change" this.choose}}
        />
      </label>
      {{#if this.file}}<p>{{this.file.name}}</p>{{/if}}
      {{#unless this.preview}}<DButton
          @label="educustomize.configuration.preview"
          @action={{this.validate}}
          @disabled={{this.busy}}
        />{{/unless}}
      {{#if this.busy}}<p role="status">{{i18n
            "educustomize.configuration.busy"
          }}</p>{{/if}}
      {{#if this.error}}<p role="alert">{{this.error}}</p>{{/if}}
      {{#if this.preview}}
        <p class="educustomize__notice">{{i18n
            "educustomize.configuration.preview_help"
          }}</p>
        <p>{{i18n "educustomize.configuration.model_help"}}</p>
        <Form
          @data={{this.preview}}
          @onSubmit={{this.create}}
          @validate={{this.validateFields}}
          @onRegisterApi={{this.registerApi}}
          @onDirtyCheck={{this.skipDirtyCheck}}
          @commitOnSubmit={{false}}
          as |form draft|
        >
          <nav
            class="educustomize__preview-nav"
            aria-label={{i18n "educustomize.ui.import_agents"}}
          >
            {{#each draft.agents as |agent|}}<DButton
                @translatedLabel={{agent.name}}
                @action={{fn this.selectAgent agent.key}}
                aria-current={{if (eq this.selectedKey agent.key) "true"}}
              />{{/each}}
          </nav>
          <form.Collection @name="agents" as |agentForm index agent|>
            <section
              class="educustomize__card educustomize__import-agent"
              hidden={{if (eq this.selectedKey agent.key) false true}}
            >
              <p>{{if
                  (eq agent.key this.preview.root)
                  (i18n "educustomize.ui.root_agent")
                  (i18n "educustomize.ui.delegate_agent")
                }}</p>
              <h4>{{agent.name}}</h4>
              {{#if agent.model}}<p>{{i18n
                    "educustomize.configuration.source_model"
                    provider=agent.model.provider
                    name=agent.model.name
                    display=agent.model.display_name
                  }}</p>{{/if}}
              <EduAgentFields
                @form={{agentForm}}
                @rootForm={{form}}
                @skillsPath={{concat "agents." index ".skills"}}
                @model={{@model}}
                @delegateField={{if
                  (eq agent.key this.preview.root)
                  "delegates"
                }}
                @delegates={{this.delegates}}
              />
            </section>
          </form.Collection>
          <div class="educustomize__save-bar"><form.Submit
              @label="educustomize.configuration.create"
              @disabled={{this.busy}}
            /><DButton
              @label="educustomize.configuration.cancel"
              @action={{this.cancel}}
              @disabled={{this.busy}}
            /></div>
        </Form>

      {{/if}}
    </section>
  </template>
}
