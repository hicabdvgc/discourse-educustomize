import { array } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";

export default <template>
  <DTooltip
    @identifier="educustomize-field-help"
    @icon="circle-question"
    @content={{@text}}
    @triggers={{array "hover" "focus" "click"}}
    @untriggers={{array "hover" "focus" "click"}}
    tabindex="0"
    aria-label={{@title}}
  />
</template>
