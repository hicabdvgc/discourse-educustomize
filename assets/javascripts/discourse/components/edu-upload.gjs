import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class EduUpload extends Component {
  @tracked busy = false;

  @action
  async upload(event) {
    const file = event.target.files[0];
    if (!file) {
      return;
    }
    this.busy = true;
    try {
      const data = new FormData();
      data.append("type", "composer");
      data.append("files[]", file);
      const result = await ajax(this.args.url || "/uploads.json", {
        type: "POST",
        data,
        processData: false,
        contentType: false,
      });
      this.args.onUpload(result);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
      event.target.value = "";
    }
  }

  <template>
    <label class="educustomize__upload">
      {{@label}}
      <input
        type="file"
        disabled={{this.busy}}
        accept={{@accept}}
        {{on "change" this.upload}}
      />
    </label>
  </template>
}
