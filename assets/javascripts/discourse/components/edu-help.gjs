import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class EduHelp extends Component {
  @service currentUser;

  @tracked opened = false;
  trigger;

  get title() {
    return i18n(`educustomize.guide.${this.args.context}.title`);
  }

  get steps() {
    return [1, 2, 3].map((index) =>
      i18n(`educustomize.guide.${this.args.context}.step${index}`)
    );
  }

  @action
  open() {
    this.trigger = document.activeElement;
    this.opened = true;
  }

  @action
  close() {
    this.opened = false;
    this.trigger?.focus();
  }

  <template>
    <DButton
      class="educustomize__help-button"
      @icon="circle-question"
      @label="educustomize.ui.guide"
      @action={{this.open}}
      aria-haspopup="dialog"
    />
    {{#if this.opened}}
      <DModal
        @title={{this.title}}
        @closeModal={{this.close}}
        @submitOnEnter={{false}}
        class="educustomize-help"
      >
        <:body>
          <ol>{{#each this.steps as |step|}}<li>{{step}}</li>{{/each}}</ol>
          {{#if @courseId}}
            <a href="/educustomize" {{on "click" this.close}}>{{i18n
                "educustomize.back"
              }}</a>
          {{/if}}
          {{#if this.currentUser.admin}}
            <nav
              aria-label={{i18n "educustomize.ui.setup_links"}}
              class="educustomize-help__links"
            >
              <a
                href="/admin/plugins/discourse-educustomize"
                {{on "click" this.close}}
              >{{i18n "educustomize.admin.title"}}</a>
              <a
                href="/admin/plugins/discourse-ai/ai-llms"
                {{on "click" this.close}}
              >{{i18n "educustomize.admin.models"}}</a>
              <a
                href="/admin/plugins/discourse-ai/ai-secrets"
                {{on "click" this.close}}
              >{{i18n "educustomize.ui.credentials"}}</a>
              <a
                href="/admin/plugins/discourse-ai/ai-embeddings"
                {{on "click" this.close}}
              >{{i18n "educustomize.ui.embeddings"}}</a>
              <a
                href="/admin/site_settings/category/all_results?filter=educustomize"
                {{on "click" this.close}}
              >{{i18n "educustomize.ui.authorization"}}</a>
              <a
                href="/admin/plugins/discourse-workflows"
                {{on "click" this.close}}
              >{{i18n "educustomize.workflow"}}</a>
            </nav>
          {{/if}}
        </:body>
      </DModal>
    {{/if}}
  </template>
}
