import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import confirmEduDiscard from "../lib/confirm-edu-discard";
import refreshCourseCategory from "../lib/refresh-course-category";
import EduAgent from "./edu-agent";
import EduAgentImport from "./edu-agent-import";
import EduBloc from "./edu-bloc";
import EduCourseNav from "./edu-course-nav";
import EduDirtyGuard from "./edu-dirty-guard";
import EduHelp from "./edu-help";
import EduUpload from "./edu-upload";

export default class EduCourse extends Component {
  @service router;
  @service site;
  @service dialog;

  @tracked area = "basics";
  @tracked blocDaisId;
  @tracked selectedAgent = null;
  @tracked logo;
  @tracked background;
  @tracked saved = false;
  @tracked imported = false;
  @tracked basicApi;
  editor;
  returnArea = "ai";
  skipDirtyCheck = () => false;

  constructor() {
    super(...arguments);
    const entry = this.args.model.entryAnchor || window.location.hash.slice(1);
    const [area, id] = entry.split("-");
    if (["basics", "ai", "bloc", "migration", "topics"].includes(area)) {
      this.area = area;
    }
    if (area === "ai" && id) {
      this.selectedAgent = this.args.model.agents.find(
        (agent) => agent.id === Number(id)
      );
    }
    window.addEventListener("hashchange", this.hashChanged);
  }

  willDestroy() {
    super.willDestroy();
    window.removeEventListener("hashchange", this.hashChanged);
  }

  get areas() {
    return ["basics", "ai", "bloc", "migration", "topics"].map((id) => ({
      id,
      name: i18n(`educustomize.ui.areas.${id}`),
    }));
  }

  get backLabel() {
    return this.returnArea === "bloc"
      ? "educustomize.ui.back_to_bloc"
      : "educustomize.ui.back_to_list";
  }

  @action
  setDais(id) {
    this.blocDaisId = id;
  }

  get areaTitle() {
    return i18n(`educustomize.ui.areas.${this.area}`);
  }

  get helpContext() {
    return this.area === "basics" ? "course" : this.area;
  }

  get basicDirty() {
    return (
      this.basicApi?.isDirty ||
      this.logo !== undefined ||
      this.background !== undefined
    );
  }

  get dirty() {
    return this.area === "basics" ? this.basicDirty : this.editor?.dirty;
  }

  get editingAgents() {
    return this.selectedAgent ? [this.selectedAgent] : [];
  }

  @action
  registerBasic(api) {
    this.basicApi = api;
  }

  @action
  registerEditor(editor) {
    this.editor = editor;
  }

  @action
  selectArea(event) {
    const next = event.target.value;
    event.target.value = this.area;
    this.chooseArea(next);
  }

  @action
  hashChanged() {
    const [next, id] = window.location.hash.slice(1).split("-");
    if (this.areas.some((area) => area.id === next)) {
      const current = this.selectedAgent
        ? `ai-${this.selectedAgent.id}`
        : this.area;
      history.replaceState(null, "", `#${current}`);
      const agent =
        next === "ai" && id
          ? this.args.model.agents.find((item) => item.id === Number(id))
          : null;
      this.switchWorkspace(next, agent || null);
    }
  }

  focusWorkspace() {
    requestAnimationFrame(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      const heading = document.querySelector(".educustomize__workspace-title");
      heading?.focus();
      heading?.scrollIntoView({ block: "start" });
    });
  }

  @action
  chooseArea(area) {
    this.switchWorkspace(area);
  }

  switchWorkspace(area, agent = null) {
    if (area === this.area && agent === this.selectedAgent) {
      return;
    }
    confirmEduDiscard(this.dialog, this.dirty, () => {
      this.basicApi = null;
      this.logo = undefined;
      this.background = undefined;
      this.selectedAgent = agent;
      this.returnArea = "ai";
      this.editor = null;
      this.saved = false;
      this.area = area;
      history.replaceState(null, "", agent ? `#ai-${agent.id}` : `#${area}`);
      this.focusWorkspace();
    });
  }

  @action
  setImage(kind, upload) {
    if (kind === "logo") {
      this.logo = upload.id;
    } else {
      this.background = upload.id;
    }
  }

  @action
  async save(data) {
    try {
      const result = await ajax(
        `/educustomize/courses/${this.args.model.course.id}.json`,
        {
          type: "PUT",
          data: {
            course: {
              ...data,
              uploaded_logo_id: this.logo ?? data.uploaded_logo_id,
              uploaded_background_id:
                this.background ?? data.uploaded_background_id,
            },
          },
        }
      );
      this.basicApi.commit();
      this.logo = undefined;
      this.background = undefined;
      await refreshCourseCategory(this.site, result.course);
      this.saved = true;
      await this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  edit(agent) {
    confirmEduDiscard(this.dialog, this.dirty, () => {
      this.returnArea = this.area === "bloc" ? "bloc" : "ai";
      this.editor = null;
      this.area = "ai";
      this.selectedAgent = { ...agent };
      history.replaceState(null, "", `#ai${agent.id ? `-${agent.id}` : ""}`);
      this.focusWorkspace();
    });
  }

  @action
  newAgent() {
    this.edit({
      name: "",
      description: "",
      system_prompt: "",
      skills: [],
      enabled: false,
      tools: [],
      subagent_ids: [],
      upload_ids: [],
    });
  }

  @action
  closeEditor() {
    confirmEduDiscard(this.dialog, this.dirty, () => {
      this.selectedAgent = null;
      this.editor = null;
      this.area = this.returnArea;
      history.replaceState(null, "", `#${this.area}`);
      this.focusWorkspace();
    });
  }

  @action
  async agentSaved() {
    this.editor = null;
    this.selectedAgent = null;
    this.area = this.returnArea;
    this.saved = true;
    await this.router.refresh();
    history.replaceState(null, "", `#${this.area}`);
    this.focusWorkspace();
  }

  @action
  async importedAgent(id) {
    this.editor = null;
    await this.router.refresh();
    this.area = "ai";
    this.returnArea = "ai";
    this.selectedAgent = {
      ...this.args.model.agents.find((agent) => agent.id === id),
    };
    this.imported = true;
    history.replaceState(null, "", `#ai-${id}`);
    this.focusWorkspace();
  }

  @action
  blocSaved() {
    return this.router.refresh();
  }

  <template>
    <main class="educustomize">
      <a href="/educustomize">{{i18n "educustomize.back"}}</a>
      <h1>{{@model.course.name}}</h1>
      <EduCourseNav @course={{@model.course}} />
      <nav
        class="educustomize__workspace-nav"
        aria-label={{i18n "educustomize.ui.navigation"}}
      >
        <div class="educustomize__workspace-tabs">
          {{#each this.areas as |area|}}<DButton
              @translatedLabel={{area.name}}
              @action={{fn this.chooseArea area.id}}
              aria-current={{if (eq this.area area.id) "page"}}
              data-area={{area.id}}
            />{{/each}}
        </div>
        <label class="educustomize__workspace-select">{{i18n
            "educustomize.ui.navigation"
          }}
          <select value={{this.area}} {{on "change" this.selectArea}}>{{#each
              this.areas
              as |area|
            }}<option
                value={{area.id}}
                selected={{eq area.id this.area}}
              >{{area.name}}</option>{{/each}}</select>
        </label>
        <EduHelp @context={{this.helpContext}} @courseId={{@model.course.id}} />
      </nav>
      <h2
        id={{this.area}}
        class="educustomize__workspace-title"
        tabindex="-1"
      >{{this.areaTitle}}</h2>
      {{#if this.saved}}<p role="status">{{i18n
            "educustomize.saved"
          }}</p>{{/if}}
      {{#if (eq this.area "basics")}}
        <EduDirtyGuard @isDirty={{this.basicDirty}} />
        <Form
          @data={{@model.course}}
          @onSubmit={{this.save}}
          @onRegisterApi={{this.registerBasic}}
          @onDirtyCheck={{this.skipDirtyCheck}}
          @commitOnSubmit={{false}}
          as |form|
        >
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
          <EduUpload
            @label={{i18n "educustomize.image"}}
            @accept="image/*"
            @onUpload={{fn this.setImage "logo"}}
          />
          <EduUpload
            @label={{i18n "educustomize.background"}}
            @accept="image/*"
            @onUpload={{fn this.setImage "background"}}
          />
          <div class="educustomize__save-bar"><form.Submit
              @label="educustomize.ui.save_course"
            /><span role="status">{{if
                this.basicDirty
                (i18n "educustomize.ui.unsaved")
                (i18n "educustomize.ui.no_changes")
              }}</span></div>
        </Form>
        <p><a href={{@model.course.members_url}}>{{i18n
              "educustomize.members"
            }}</a></p>

      {{else if (eq this.area "ai")}}
        {{#if this.selectedAgent}}
          <DButton
            @label={{this.backLabel}}
            @icon="arrow-left"
            @action={{this.closeEditor}}
          />
          {{#each this.editingAgents key="@identity" as |agent|}}
            <EduAgent
              @agent={{agent}}
              @model={{@model}}
              @onSaved={{this.agentSaved}}
              @onRegisterEditor={{this.registerEditor}}
              @onClose={{this.closeEditor}}
              @backLabel={{this.backLabel}}
            />
          {{/each}}
        {{else}}
          <p class="educustomize__notice">{{i18n
              "educustomize.configuration_help"
            }}</p>
          <DButton @label="educustomize.new_agent" @action={{this.newAgent}} />
          {{#each @model.agents as |agent|}}
            <div class="educustomize__card educustomize__agent-summary"><div><h3
                >{{agent.name}}</h3><p>{{agent.description}}</p></div><DButton
                @label="educustomize.ui.edit_assistant"
                @action={{fn this.edit agent}}
                aria-label={{i18n "educustomize.ui.edit_named" name=agent.name}}
              /></div>
          {{/each}}
        {{/if}}
        {{#if this.imported}}<p role="status">{{i18n
              "educustomize.configuration.imported"
            }}</p>{{/if}}
      {{else if (eq this.area "bloc")}}
        <EduBloc
          @daisId={{this.blocDaisId}}
          @onDaisChange={{this.setDais}}
          @model={{@model}}
          @onEdit={{this.edit}}
          @onSaved={{this.blocSaved}}
          @onRegisterEditor={{this.registerEditor}}
        />
      {{else if (eq this.area "migration")}}
        <EduAgentImport
          @model={{@model}}
          @onImported={{this.importedAgent}}
          @onRegisterEditor={{this.registerEditor}}
        />
      {{else}}
        <section class="educustomize__card">
          <p>{{i18n "educustomize.topic_help"}}</p>
          <ul>{{#each @model.topics as |topic|}}<li><a
                  href={{concat "/educustomize/topics/" topic.id}}
                >{{topic.title}}</a></li>{{else}}<li>{{i18n
                  "educustomize.no_topics"
                }}</li>{{/each}}</ul>
        </section>
      {{/if}}
    </main>
  </template>
}
