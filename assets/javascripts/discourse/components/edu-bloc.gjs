import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
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
import EduAgentChoices from "./edu-agent-choices";
import EduDirtyGuard from "./edu-dirty-guard";

export default class EduBloc extends Component {
  @service dialog;

  @tracked daisId;
  @tracked formApi;
  @tracked saved = false;
  skipDirtyCheck = () => false;

  constructor() {
    super(...arguments);
    this.daisId = this.args.daisId;
    this.args.onRegisterEditor?.(this);
  }

  get dirty() {
    return this.formApi?.isDirty;
  }

  get candidates() {
    const assigned = this.args.model.agents.flatMap(
      (agent) => agent.subagent_ids
    );
    return this.args.model.agents.filter(
      (agent) => !assigned.includes(agent.id)
    );
  }

  get selected() {
    const agent = this.args.model.agents.find(
      (item) => item.id === this.daisId
    );
    return agent ? [agent] : [];
  }

  get delegates() {
    return this.args.model.agents.filter(
      (agent) => agent.id !== this.daisId && !agent.subagent_ids.length
    );
  }

  @action
  registerApi(api) {
    this.formApi = api;
    this.args.onRegisterApi?.(api);
  }

  @action
  choose(event) {
    const next = Number(event.target.value) || null;
    event.target.value = this.daisId || "";
    confirmEduDiscard(this.dialog, this.dirty, () => {
      this.formApi = null;
      this.saved = false;
      this.daisId = next;
      this.args.onDaisChange?.(next);
    });
  }

  @action
  async save(data) {
    try {
      await ajax(
        `/educustomize/courses/${this.args.model.course.id}/agents/${this.daisId}.json`,
        {
          type: "PUT",
          contentType: "application/json",
          data: JSON.stringify({ agent: { subagent_ids: data.subagent_ids } }),
        }
      );
      this.formApi.commit();
      this.saved = true;
      await this.args.onSaved();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <section class="educustomize__card educustomize__bloc">
      <EduDirtyGuard @isDirty={{this.dirty}} />
      <h3>{{i18n "educustomize.bloc"}}</h3>
      <p>{{i18n "educustomize.bloc_help"}}</p>
      <p class="educustomize__notice">{{i18n "educustomize.bloc_flow"}}</p>
      <label class="educustomize__dais-picker">{{i18n "educustomize.dais"}}
        <select value={{this.daisId}} {{on "change" this.choose}}>
          <option value="">{{i18n "educustomize.choose_dais"}}</option>
          {{#each this.candidates as |agent|}}<option
              value={{agent.id}}
              selected={{eq agent.id this.daisId}}
            >{{agent.name}}</option>{{/each}}
        </select>
      </label>
      {{#each this.selected key="@identity" as |dais|}}
        <h4>{{dais.name}}</h4>
        <DButton
          @label="educustomize.ui.edit_dais"
          @action={{fn @onEdit dais}}
        />
        <Form
          @data={{dais}}
          @onSubmit={{this.save}}
          @onRegisterApi={{this.registerApi}}
          @onDirtyCheck={{this.skipDirtyCheck}}
          @commitOnSubmit={{false}}
          as |form|
        >
          <form.Field
            @name="subagent_ids"
            @title={{i18n "educustomize.delegates"}}
            @type="custom"
            as |field|
          >
            <field.Control><EduAgentChoices
                @options={{this.delegates}}
                @value={{field.value}}
                @onChange={{field.set}}
                @onEdit={{@onEdit}}
                @editLabel="educustomize.ui.edit_delegate"
                @emptyText={{i18n "educustomize.no_delegates"}}
              /></field.Control>
          </form.Field>
          <div class="educustomize__save-bar"><form.Submit
              @label="educustomize.ui.save_bloc"
            /><span role="status">{{if
                this.dirty
                (i18n "educustomize.ui.unsaved")
                (i18n "educustomize.ui.no_changes")
              }}</span></div>
        </Form>
      {{/each}}
      {{#if this.saved}}<p role="status">{{i18n
            "educustomize.saved"
          }}</p>{{/if}}
    </section>
  </template>
}
