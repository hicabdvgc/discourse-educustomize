import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";

export default <template>
  <nav
    class="educustomize__actions"
    aria-label={{i18n "educustomize.learning.navigation"}}
  >
    <a
      class="btn"
      href={{concat "/educustomize/courses/" @course.id "/learning"}}
    >{{i18n "educustomize.learning.title"}}</a>
    {{#if @course.can_manage}}
      <a class="btn" href={{concat "/educustomize/courses/" @course.id}}>{{i18n
          "educustomize.manage"
        }}</a>
      <a
        class="btn"
        href={{concat "/educustomize/courses/" @course.id "/reports"}}
      >{{i18n "educustomize.research.title"}}</a>
      <a
        class="btn"
        href={{concat "/educustomize/courses/" @course.id "/maintenance"}}
      >{{i18n "educustomize.maintenance.title"}}</a>
    {{/if}}
  </nav>
</template>
