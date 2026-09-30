import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

export default class EduColorSelector extends Component {
  @service eduPalette;

  get label() {
    return i18n(`educustomize.interface.${this.eduPalette.mode}`);
  }

  @action
  choose(mode, menu) {
    this.eduPalette.select(mode);
    menu.close();
  }

  <template>
    <DMenu
      @label={{this.label}}
      @triggerClass="btn-flat sidebar-footer-actions-button"
      @identifier="educustomize-color-selector"
      @animated={{false}}
      @ariaLabel={{i18n "educustomize.interface.palette_label" mode=this.label}}
      class="educustomize-color-selector"
    >
      <:content as |menu|>
        <DDropdownMenu as |dropdown|>
          <dropdown.item><DButton
              @label="educustomize.interface.dark"
              @action={{fn this.choose "dark" menu}}
              class="educustomize-color-selector__dark"
            /></dropdown.item>
          <dropdown.item><DButton
              @label="educustomize.interface.light"
              @action={{fn this.choose "light" menu}}
              class="educustomize-color-selector__light"
            /></dropdown.item>
          <dropdown.item><DButton
              @label="educustomize.interface.ambient"
              @action={{fn this.choose "ambient" menu}}
              class="educustomize-color-selector__ambient"
            /></dropdown.item>
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
