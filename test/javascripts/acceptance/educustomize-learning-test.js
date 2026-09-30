import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Educustomize | learning workspace", function (needs) {
  needs.user();
  needs.settings({ educustomize_enabled: true });
  let teacher;
  needs.hooks.beforeEach(() => {
    teacher = false;
  });
  needs.pretender((server, helper) => {
    server.get("/educustomize/courses.json", () =>
      helper.response({ courses: [], dependencies: {}, can_create: false })
    );
    server.get("/educustomize/courses/1/learning.json", () =>
      helper.response({
        course: {
          id: 1,
          name: "Learning course",
          category_id: 9,
          category_url: "/c/learning/9",
          can_manage: teacher,
          members_url: "/g/learners",
        },
        can_post: true,
        kinds: [
          "discussion",
          "announcement",
          "material",
          "question",
          "feedback",
        ].map((key) => ({ key, tag: "edu-" + key, ready: true })),
        topics: [
          { id: 12, title: "Latest lesson", url: "/t/latest-lesson/12" },
        ],
        templates_url: teacher ? "/c/templates/10" : null,
      })
    );
  });

  test("student workspace groups activities and hides course management", async function (assert) {
    await visit("/educustomize/courses/1/learning");
    assert.dom(".educustomize__sections section").exists({ count: 5 });
    assert.dom('a[href="/educustomize/courses/1/reports"]').doesNotExist();
    assert.dom('a[href="/educustomize/topics/12"]').doesNotExist();
    assert.dom('a[href^="/new-topic?"]').exists({ count: 2 });
    assert.dom('a[href="/t/latest-lesson/12"]').hasText("Latest lesson");
  });

  test("teacher workspace exposes native composer and scoped search links", async function (assert) {
    teacher = true;
    await visit("/educustomize/courses/1/learning");
    assert.dom('a[href="/educustomize/courses/1/reports"]').exists();
    assert.dom('a[href="/educustomize/courses/1/maintenance"]').exists();
    assert.dom('a[href="/educustomize/topics/12"]').exists();
    assert.dom('a[href^="/new-topic?"]').exists({ count: 5 });
    const links = [...document.querySelectorAll('a[href^="/new-topic?"]')];
    const feedback = links
      .map((link) => new URL(link.href))
      .find((url) => url.searchParams.get("tags") === "edu-feedback");
    assert.strictEqual(feedback.searchParams.get("category_id"), "9");
    assert.true(feedback.searchParams.get("body").includes("[poll"));
    assert.dom('a[href^="/tags/c/learning/9/edu-"]').exists({ count: 5 });
  });
});
