import { apiInitializer } from "discourse/lib/api";
import EduInterfacePreferences from "../components/edu-interface-preferences";

const FallbackPreferences = <template>
  <div class="educustomize-interface-fallback">
    <EduInterfacePreferences />
  </div>
</template>;

export default apiInitializer((api) => {
  if (!api.container.lookup("service:site-settings").educustomize_enabled) {
    return;
  }
  api.container.lookup("service:edu-palette").initialize();
  api.renderInOutlet("before-sidebar-sections", EduInterfacePreferences);
  api.renderInOutlet("above-main-container", FallbackPreferences);
});
