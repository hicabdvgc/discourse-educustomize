import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import DButton from "discourse/ui-kit/d-button";
import DCookText from "discourse/ui-kit/d-cook-text";
import { i18n } from "discourse-i18n";
import confirmEduDiscard from "../lib/confirm-edu-discard";

export default class EduReview extends Component {
  @service dialog;

  @tracked formApi;
  @tracked preview = false;
  skipDirtyCheck = () => false;

  constructor() {
    super(...arguments);
    this.args.onRegister?.(this);
  }

  get dirty() {
    return this.formApi?.isDirty;
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  togglePreview() {
    this.preview = !this.preview;
  }

  @action
  async approve(data) {
    await this.args.onDecide(this.args.run, "approve", data, () =>
      this.formApi.commit()
    );
  }

  @action
  reject() {
    confirmEduDiscard(this.dialog, this.dirty, () =>
      this.args.onDecide(this.args.run, "reject", null, () =>
        this.formApi?.commit()
      )
    );
  }

  @action
  regenerate() {
    confirmEduDiscard(this.dialog, this.dirty, () =>
      this.args.onDecide(this.args.run, "regenerate", null, () =>
        this.formApi?.commit()
      )
    );
  }

  <template>
    {{#if @run.can_review}}
      <Form
        @data={{@run}}
        @onSubmit={{this.approve}}
        @onRegisterApi={{this.registerApi}}
        @onDirtyCheck={{this.skipDirtyCheck}}
        @commitOnSubmit={{false}}
        as |form draft|
      >
        <DButton
          @label={{if
            this.preview
            "educustomize.ui.edit_draft"
            "educustomize.ui.preview_draft"
          }}
          @action={{this.togglePreview}}
        />
        <div class="educustomize__review-editor" hidden={{this.preview}}>
          <form.Field
            @name="draft"
            @title={{i18n "educustomize.draft"}}
            @type="textarea"
            @format="full"
            as |field|
          ><field.Control
              rows="12"
              class="educustomize__review-input"
            /></form.Field>
        </div>
        {{#if this.preview}}<DCookText
            @rawText={{draft.draft}}
            class="cooked educustomize__draft"
          />{{/if}}
        <div class="educustomize__save-bar"><form.Submit
            @label="educustomize.approve"
          /><DButton
            @label="educustomize.reject"
            @action={{this.reject}}
          /><span role="status">{{if
              this.dirty
              (i18n "educustomize.ui.unsaved")
            }}</span></div>
      </Form>
    {{else}}
      <DCookText @rawText={{@run.draft}} class="cooked educustomize__draft" />
    {{/if}}
    {{#if @run.can_regenerate}}<DButton
        @label="educustomize.regenerate"
        @action={{this.regenerate}}
      />{{/if}}
  </template>
}
