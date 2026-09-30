import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class EducustomizeIndexRoute extends DiscourseRoute {
  model() {
    return ajax("/educustomize/courses.json");
  }
}
