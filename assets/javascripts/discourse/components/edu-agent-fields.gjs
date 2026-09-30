import Component from "@glimmer/component";
import { array, fn, hash } from "@ember/helper";
import { service } from "@ember/service";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import EduAgentChoices from "./edu-agent-choices";
import EduFieldHelp from "./edu-field-help";

const PromptHelp = <template>
  <DTooltip
    @identifier="educustomize-prompt-help"
    @icon="circle-question"
    @content={{i18n "educustomize.prompt_help"}}
    @triggers={{array "hover" "focus" "click"}}
    @untriggers={{array "hover" "focus" "click"}}
    tabindex="0"
    aria-label={{i18n "educustomize.prompt"}}
  />
</template>;

const ToolHelp = <template>
  <EduFieldHelp
    @title={{i18n "educustomize.tools"}}
    @text={{i18n "educustomize.ui.tool_help"}}
  />
</template>;

export default class EduAgentFields extends Component {
  @service siteSettings;

  skillNumber(index) {
    return index + 1;
  }

  get tools() {
    return (this.args.model.tools || []).map((name) => ({
      id: name,
      name,
      description: i18n("educustomize.tool_descriptions." + name),
    }));
  }

  <template>
    <fieldset class="educustomize__agent-group">
      <legend>{{i18n "educustomize.identity"}}</legend>
      <@form.Field
        @name="name"
        @title={{i18n "educustomize.name"}}
        @type="input"
        @validation="required"
        as |field|
      ><field.Control @format="full" maxlength="100" /></@form.Field>
      <@form.Field
        @name="description"
        @title={{i18n "educustomize.agent_description"}}
        @type="textarea"
        @validation="required"
        as |field|
      ><field.Control @format="full" maxlength="2000" /></@form.Field>
      <@form.Field
        @name="enabled"
        @title={{i18n "educustomize.enabled"}}
        @type="checkbox"
        as |field|
      ><field.Control /></@form.Field>
    </fieldset>
    <fieldset class="educustomize__agent-group">
      <legend>{{i18n "educustomize.behavior"}}</legend>
      <@form.Field
        @name="system_prompt"
        @title={{i18n "educustomize.prompt"}}
        @tooltip={{PromptHelp}}
        @type="textarea"
        @validation="required"
        as |field|
      ><field.Control
          @format="full"
          class="educustomize__prompt-input"
          @rows={{12}}
          maxlength="100000"
          aria-label={{i18n "educustomize.prompt"}}
        /></@form.Field>
      <h4>{{i18n "educustomize.skills"}}
        <EduFieldHelp
          @title={{i18n "educustomize.skills"}}
          @text={{i18n "educustomize.ui.skill_help"}}
        /></h4>
      <p>{{i18n "educustomize.skills_help"}}</p>
      <@form.Collection @name="skills" as |skill index|>
        <fieldset class="educustomize__skill">
          <legend>{{i18n "educustomize.skills"}}
            {{this.skillNumber index}}</legend>
          <skill.Field
            @name="name"
            @title={{i18n "educustomize.skill_name"}}
            @type="input"
            @validation="required"
            as |field|
          ><field.Control @format="full" maxlength="100" /></skill.Field>
          <skill.Field
            @name="description"
            @title={{i18n "educustomize.skill_description"}}
            @type="textarea"
            as |field|
          ><field.Control @format="full" maxlength="2000" /></skill.Field>
          <skill.Field
            @name="instructions"
            @title={{i18n "educustomize.skill_instructions"}}
            @type="textarea"
            @validation="required"
            as |field|
          ><field.Control
              @format="full"
              class="educustomize__skill-input"
              @rows={{8}}
              maxlength="100000"
            /></skill.Field>
          <DButton
            @label="educustomize.remove_skill"
            @icon="trash-can"
            @action={{fn skill.remove index}}
          />
        </fieldset>
      </@form.Collection>
      <DButton
        @label="educustomize.add_skill"
        @icon="plus"
        @action={{fn
          @rootForm.addItemToCollection
          @skillsPath
          (hash name="" description="" instructions="")
        }}
      />
    </fieldset>
    <fieldset class="educustomize__agent-group">
      <legend>{{i18n "educustomize.runtime"}}</legend>
      <@form.Field
        @name="default_llm_id"
        @title={{i18n "educustomize.model"}}
        @type="select"
        as |field|
      >
        <field.Control @format="full" @includeNone={{false}} as |control|>
          <control.Option @value={{null}}>{{i18n
              "educustomize.configuration.no_model"
            }}</control.Option>
          {{#each @model.models as |model|}}<control.Option
              @value={{model.id}}
            >{{model.name}}</control.Option>{{/each}}
        </field.Control>
      </@form.Field>
      <details class="educustomize__advanced"><summary>{{i18n
            "educustomize.ui.advanced"
          }}</summary>
        <p>{{i18n "educustomize.learning.parameters_help"}}</p>
        {{#unless this.siteSettings.ai_llm_temperature_top_p_enabled}}<p>{{i18n
              "educustomize.admin.sampling_disabled"
            }}</p>{{/unless}}
        <@form.Field
          @name="temperature"
          @title={{i18n "educustomize.learning.temperature"}}
          @type="input-number"
          as |field|
        ><field.Control step="any" min="0" max="2" /></@form.Field>
        <@form.Field
          @name="top_p"
          @title={{i18n "educustomize.learning.top_p"}}
          @type="input-number"
          as |field|
        ><field.Control step="any" min="0.000001" max="1" /></@form.Field>
      </details>
      <@form.Field
        @name="tools"
        @tooltip={{ToolHelp}}
        @title={{i18n "educustomize.tools"}}
        @type="custom"
        as |field|
      >
        <field.Control><EduAgentChoices
            @options={{this.tools}}
            @value={{field.value}}
            @onChange={{field.set}}
            @emptyText={{i18n "educustomize.no_tools"}}
          /></field.Control>
      </@form.Field>
      <p>{{i18n "educustomize.tools_help"}}</p>
    </fieldset>
    {{#if @delegateField}}
      <@form.Field
        @name={{@delegateField}}
        @title={{i18n "educustomize.delegates"}}
        @type="custom"
        as |field|
      >
        <field.Control><EduAgentChoices
            @options={{@delegates}}
            @value={{field.value}}
            @onChange={{field.set}}
            @emptyText={{i18n "educustomize.no_delegates"}}
          /></field.Control>
      </@form.Field>
    {{/if}}
  </template>
}
