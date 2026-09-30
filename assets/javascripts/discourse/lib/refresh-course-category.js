import { ajax } from "discourse/lib/ajax";

export default async function refreshCourseCategory(site, course) {
  const result = await ajax(`/c/${course.category_id}/show.json`);
  site.updateCategory(result.category);
}
