import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class EduAgentChoices extends Component {
  get choices() {
    return (this.args.options || []).map((option) => ({
      ...option,
      checked: (this.args.value || []).includes(option.id),
    }));
  }

  @action
  toggle(id, event) {
    const selected = this.args.value || [];
    this.args.onChange(
      event.target.checked
        ? [...selected, id]
        : selected.filter((value) => value !== id)
    );
  }

  <template>
    <div class="educustomize__choices">
      <p role="status">{{i18n "educustomize.selected" count=@value.length}}</p>
      {{#each this.choices key="id" as |choice|}}
        <div class="educustomize__choice">
          <label>
            <input
              type="checkbox"
              checked={{choice.checked}}
              {{on "change" (fn this.toggle choice.id)}}
            />
            <span><strong>{{choice.name}}</strong>{{#if
                choice.description
              }}<span
                  class="educustomize__choice-description"
                >{{choice.description}}</span>{{/if}}</span>
          </label>
          {{#if @onEdit}}<DButton
              @label={{or @editLabel "educustomize.edit"}}
              @action={{fn @onEdit choice}}
            />{{/if}}
        </div>
      {{else}}
        <p>{{@emptyText}}</p>
      {{/each}}
    </div>
  </template>
}
