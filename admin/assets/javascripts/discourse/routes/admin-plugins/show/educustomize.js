import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class EducustomizeAdminRoute extends DiscourseRoute {
  model() {
    return ajax("/educustomize/admin.json");
  }
}
