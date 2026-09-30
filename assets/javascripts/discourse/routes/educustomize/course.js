import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class EducustomizeCourseRoute extends DiscourseRoute {
  async model(params, transition) {
    const course = await ajax(
      "/educustomize/courses/" + params.course_id + ".json"
    );
    const ai = await ajax(
      "/educustomize/courses/" + params.course_id + "/agents.json"
    );
    // DiscourseURL removes the fragment before routing and carries it here.
    // Mirror native Topic routing so existing course #ai links keep their target.
    return { ...course, ...ai, entryAnchor: transition?._discourse_anchor };
  }
}
