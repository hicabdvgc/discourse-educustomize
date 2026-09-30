import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import confirmEduDiscard from "../lib/confirm-edu-discard";

export default class EduDirtyGuard extends Component {
  @service router;
  @service dialog;

  leaving = false;

  constructor() {
    super(...arguments);
    this.router.on("routeWillChange", this.checkTransition);
    this.router.on("routeDidChange", this.didTransition);
    window.addEventListener("beforeunload", this.beforeUnload);
  }

  willDestroy() {
    super.willDestroy();
    this.router.off("routeWillChange", this.checkTransition);
    this.router.off("routeDidChange", this.didTransition);
    window.removeEventListener("beforeunload", this.beforeUnload);
  }

  @action
  didTransition() {
    this.leaving = false;
  }

  @action
  checkTransition(transition) {
    if (this.args.isDirty && !this.leaving && !transition.isAborted) {
      transition.abort();
      confirmEduDiscard(this.dialog, true, () => {
        this.leaving = true;
        const retry = transition.retry();
        retry._discourse_anchor = transition._discourse_anchor;
      });
    }
  }

  @action
  beforeUnload(event) {
    if (this.args.isDirty && !this.leaving) {
      event.preventDefault();
      event.returnValue = "";
    }
  }

  <template></template>
}
