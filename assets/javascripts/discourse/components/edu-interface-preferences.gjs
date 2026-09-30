import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import EduColorSelector from "./edu-color-selector";
import EduLanguageSwitcher from "./edu-language-switcher";

export default class EduInterfacePreferences extends Component {
  @service interfaceColor;
  @service siteSettings;

  <template>
    <section
      class="educustomize-interface"
      aria-label={{i18n "educustomize.interface.title"}}
    >
      <div class="educustomize-interface__row">
        <span>{{i18n "educustomize.interface.color"}}</span>
        {{#if this.interfaceColor.selectorAvailable}}
          <EduColorSelector />
        {{else}}
          <span>{{i18n "educustomize.interface.theme_fixed"}}</span>
        {{/if}}
      </div>
      <div class="educustomize-interface__row">
        <span>{{i18n "educustomize.interface.language"}}</span>
        {{#if this.siteSettings.allow_user_locale}}
          <EduLanguageSwitcher />
        {{else}}
          <span>{{i18n "educustomize.interface.locale_fixed"}}</span>
        {{/if}}
      </div>
    </section>
  </template>
}
