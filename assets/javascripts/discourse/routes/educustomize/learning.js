import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class EducustomizeLearningRoute extends DiscourseRoute {
  model(params) {
    return ajax("/educustomize/courses/" + params.course_id + "/learning.json");
  }
}
