import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Educustomize | research interface", function (needs) {
  needs.user();
  needs.settings({ educustomize_enabled: true });
  needs.pretender((server, helper) => {
    server.get("/educustomize/courses.json", () =>
      helper.response({ courses: [], can_create: false })
    );
    server.get("/educustomize/courses/1/reports.json", () =>
      helper.response({
        course: { id: 1, name: "Research course" },
        available: true,
        reports: [
          {
            key: "discussions",
            group: "discussion",
            columns: ["text", "estimated_cost"],
          },
        ],
        topics: [],
        retention: { workflow_days: 30, ai_days: 180 },
      })
    );
    server.post(
      "/educustomize/courses/1/reports/discussions/preview.json",
      () =>
        helper.response({
          columns: ["text", "estimated_cost"],
          rows: [
            ["<script>private text</script>", 0],
            ["Other response", null],
          ],
          truncated: true,
        })
    );
    server.get("/educustomize/courses/2/reports.json", () =>
      helper.response({
        course: { id: 2, name: "Teaching course" },
        available: false,
        reports: [],
        topics: [],
        retention: { workflow_days: 30, ai_days: 180 },
      })
    );
  });

  test("preview safely displays full text and distinguishes zero from missing data", async function (assert) {
    await visit("/educustomize/courses/1/reports");
    await click('.educustomize button[type="submit"]');
    assert.dom(".educustomize__table tbody tr").exists({ count: 2 });
    assert
      .dom(".educustomize__table tbody tr:first-child td:first-child")
      .hasText("<script>private text</script>");
    assert.dom(".educustomize__table tbody script").doesNotExist();
    assert
      .dom(".educustomize__table tbody tr:first-child td:last-child")
      .hasText("0");
    assert
      .dom(".educustomize__table tbody tr:last-child td:last-child")
      .hasText("Missing / unavailable");
    assert.dom('[role="status"]').includesText("first 50 rows");
  });

  test("disabled explorer offers a usable return to course management", async function (assert) {
    await visit("/educustomize/courses/2/reports");
    assert.dom(".educustomize form").doesNotExist();
    assert
      .dom('.educustomize a[href="/educustomize/courses/2"]')
      .hasText("Teaching course");
    assert
      .dom('[role="status"]')
      .includesText("The Data Explorer plugin is disabled");
  });
});
