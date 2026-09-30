import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class EducustomizeTopicRoute extends DiscourseRoute {
  queryParams = { run_id: { refreshModel: true } };

  async model(params) {
    const model = await ajax(
      "/educustomize/topics/" + params.topic_id + ".json"
    );
    return { ...model, run_id: params.run_id };
  }
}
