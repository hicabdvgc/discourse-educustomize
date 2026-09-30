import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import EduHelp from "./edu-help";

export default class EduNativeGuide extends Component {
  @service router;
  @service currentUser;
  @service siteSettings;

  get visible() {
    return (
      this.siteSettings.educustomize_enabled &&
      this.currentUser?.admin &&
      /^\/admin\/plugins\/(discourse-ai\/(ai-llms|ai-secrets|ai-embeddings)|discourse-workflows)(\/|\?|$)/.test(
        this.router.currentURL || ""
      )
    );
  }

  <template>
    {{#if this.visible}}
      <nav
        class="educustomize educustomize__native-guide"
        aria-label={{i18n "educustomize.ui.setup_links"}}
      >
        <a href="/admin/plugins/discourse-educustomize">{{i18n
            "educustomize.ui.back_to_setup"
          }}</a>
        <EduHelp @context="admin" />
      </nav>
    {{/if}}
  </template>
}
