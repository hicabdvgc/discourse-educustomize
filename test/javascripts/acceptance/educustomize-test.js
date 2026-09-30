import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Educustomize | course configuration", function (needs) {
  needs.user();
  needs.settings({ educustomize_enabled: true });
  needs.hooks.beforeEach(() =>
    history.replaceState(null, "", location.pathname + location.search)
  );
  needs.pretender((server, helper) => {
    server.get("/educustomize/courses.json", () =>
      helper.response({
        can_create: true,
        dependencies: {},
        courses: [
          {
            id: 1,
            name: "Course introduction",
            description: "Visible before enrollment.",
            joined: false,
            can_manage: false,
          },
        ],
      })
    );
    server.get("/educustomize/courses/1.json", () =>
      helper.response({
        course: {
          id: 1,
          name: "Course introduction",
          description: "Course detail.",
          color: "0088CC",
          members_url: "/g/course_students",
        },
      })
    );
    server.get("/educustomize/courses/1/agents.json", () =>
      helper.response({
        agents: [],
        models: [],
        tools: [],
        dependencies: { ai: true },
      })
    );
    server.get("/educustomize/topics/2.json", () =>
      helper.response({
        topic_id: 2,
        title: "A teaching discussion",
        course_id: 1,
        ready: false,
        readiness_reasons: ["model_unauthorized"],
        policy: {
          memory: false,
          auto_reply: false,
          require_review: true,
          reviewer_id: 1,
        },
        agents: [],
        workflows: [],
        reviewers: [{ id: 1, name: "Teacher" }],
        posts: [],
      })
    );
  });

  test("catalog shows only introduction and enrollment before joining", async function (assert) {
    await visit("/educustomize");
    assert.dom(".educustomize__card h2").hasText("Course introduction");
    assert
      .dom(".educustomize__description")
      .hasText("Visible before enrollment.");
    assert.dom(".educustomize__card a").doesNotExist();
    await click(".educustomize > button");
    assert.dom('input[name="color"]').hasValue("0088CC");
  });

  test("teacher can edit native-backed course and open assistant form without a model", async function (assert) {
    await visit("/educustomize/courses/1");
    assert.dom('input[name="name"]').hasValue("Course introduction");
    await click("[data-area='ai']");
    await click(".educustomize > button");
    assert.dom('textarea[name="system_prompt"]').exists();
    await fillIn(
      'textarea[name="system_prompt"]',
      "Explain the course concepts."
    );
    assert
      .dom('textarea[name="system_prompt"]')
      .hasValue("Explain the course concepts.");
  });

  test("Topic defaults require review with memory and automatic generation disabled", async function (assert) {
    await visit("/educustomize/topics/2");
    assert.dom('input[name="memory"]').isNotChecked();
    assert.dom('input[name="auto_reply"]').isNotChecked();
    assert.dom('input[name="require_review"]').isChecked();
    assert.dom(".educustomize h1").exists();
    assert
      .dom(".educustomize__readiness")
      .includesText(
        "Every assistant needs a model that the administrator has authorized for course use."
      );
    assert.dom("a[href='/educustomize/courses/1']").hasText("Back to course");
    // No runs endpoint is stubbed: unsaved policies must not request it.
    assert.dom(".dialog-body").doesNotExist();
  });
});
for (const isTeacher of [true, false]) {
  acceptance(
    `Educustomize | category entry | teacher=${isTeacher}`,
    function (needs) {
      needs.user({ educustomize_course_ids: isTeacher ? [1] : [] });
      needs.settings({ educustomize_enabled: true });
      needs.site({
        categories: [
          {
            id: 1,
            name: "bug",
            slug: "bug",
            permission: 1,
            educustomize_course_id: 1,
          },
        ],
      });

      test("course management entries respect course teaching permission", async function (assert) {
        await visit("/c/bug/1");
        if (isTeacher) {
          assert
            .dom('.educustomize__actions a[href="/educustomize/courses/1"]')
            .exists();
          assert
            .dom('.educustomize__actions a[href="/educustomize/courses/1#ai"]')
            .exists();
        } else {
          assert.dom(".educustomize__actions").doesNotExist();
        }
      });
    }
  );
}
