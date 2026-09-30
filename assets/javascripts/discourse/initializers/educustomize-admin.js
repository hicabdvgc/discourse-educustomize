import { apiInitializer } from "discourse/lib/api";
import EduNativeGuide from "../components/edu-native-guide";

export default apiInitializer((api) => {
  if (api.getCurrentUser()?.admin) {
    api.renderInOutlet("above-main-container", EduNativeGuide);
    api.addAdminPluginConfigurationNav("discourse-educustomize", [
      {
        label: "educustomize.admin.title",
        route: "adminPlugins.show.educustomize",
      },
    ]);
  }
});
