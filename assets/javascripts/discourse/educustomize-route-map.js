export default function () {
  this.route("educustomize", function () {
    this.route("course", { path: "/courses/:course_id" });
    this.route("learning", { path: "/courses/:course_id/learning" });
    this.route("reports", { path: "/courses/:course_id/reports" });
    this.route("maintenance", { path: "/courses/:course_id/maintenance" });
    this.route("topic", { path: "/topics/:topic_id" });
  });
}
