import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Educustomize | Topic review drafts", function (needs) {
  needs.user({ admin: false });
  needs.settings({ educustomize_enabled: true });
  let runs, reads, generations, decisions, saves, failReads, failGeneration;
  needs.hooks.beforeEach(() => {
    runs = [1, 2].map((id) => ({
      id,
      post_id: 12,
      status: "awaiting_review",
      draft: `Original ${id}`,
      can_review: true,
      can_regenerate: true,
    }));
    runs.push({
      id: 3,
      status: "succeeded",
      outcome: "published",
      draft: "Published reply",
      published_post_id: 123,
    });
    reads = 0;
    generations = 0;
    decisions = [];
    saves = 0;
    failReads = false;
    failGeneration = false;
  });
  needs.pretender((server, helper) => {
    server.get("/educustomize/courses.json", () =>
      helper.response({ courses: [], can_create: false })
    );
    server.get("/educustomize/courses/1.json", () =>
      helper.response({ course: { id: 1, name: "Review course" } })
    );
    server.get("/educustomize/courses/1/agents.json", () =>
      helper.response({ agents: [], models: [], tools: [], topics: [] })
    );
    server.get("/educustomize/topics/2.json", () =>
      helper.response({
        topic_id: 2,
        course_id: 1,
        title: "Review discussion",
        policy_id: 9,
        policy: {
          ai_agent_id: 88,
          workflow_id: 4,
          reviewer_id: 1,
          require_review: true,
        },
        agents: [{ id: 88, name: "Tutor" }],
        workflows: [{ id: 4, name: "Teaching" }],
        reviewers: [{ id: 1, name: "Teacher" }],
        posts: [{ id: 12, name: "Student reply" }],
        ready: true,
      })
    );
    server.get("/educustomize/topics/2/runs.json", () => {
      reads++;
      return failReads
        ? helper.response(503, { errors: ["Refresh unavailable"] })
        : helper.response({ runs });
    });
    server.post("/educustomize/topics/2/runs.json", () => {
      generations++;
      return failGeneration
        ? helper.response(503, { errors: ["Generation unavailable"] })
        : helper.response({});
    });
    server.put("/educustomize/topics/2.json", () => {
      saves++;
      return helper.response({});
    });
    server.put("/educustomize/topics/2/runs/1.json", (request) => {
      decisions.push(new URLSearchParams(request.requestBody));
      runs = runs.map((run) =>
        run.id === 1
          ? {
              ...run,
              can_review: false,
              outcome:
                decisions.at(-1).get("decision") === "regenerate"
                  ? "superseded"
                  : "published",
            }
          : run
      );
      return helper.response({});
    });
  });
  const draft = (id) => `#run-${id} textarea[name='draft']`;
  const refresh = ".educustomize > button";

  test("records render and published links target the exact post", async function (assert) {
    await visit("/educustomize/topics/2");
    assert.dom("#run-3 a").hasAttribute("href", "/p/123");
    assert.dom(draft(1)).hasValue("Original 1");
    assert.dom(draft(2)).hasValue("Original 2");
  });

  test("refresh and leaving protect the draft, including after a failed refresh", async function (assert) {
    await visit("/educustomize/topics/2");
    await fillIn(draft(1), "Keep this teacher edit.");
    await click(refresh);
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-default");
    assert.strictEqual(reads, 1);
    assert.dom(draft(1)).hasValue("Keep this teacher edit.");
    failReads = true;
    await click(refresh);
    await click(".dialog-footer .btn-primary");
    assert.dom(".dialog-body").includesText("Refresh unavailable");
    await click(".dialog-footer .btn-primary");
    assert.dom(draft(1)).hasValue("Keep this teacher edit.");
    await click("a[href='/educustomize/courses/1']");
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-default");
    assert.dom(draft(1)).hasValue("Keep this teacher edit.");
    failReads = false;
    await click(refresh);
    await click(".dialog-footer .btn-primary");
    assert.dom(draft(1)).hasValue("Original 1");
    await fillIn(draft(1), "Second edit after refresh.");
    await click("a[href='/educustomize/courses/1']");
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-primary");
    assert.dom(draft(1)).doesNotExist();
  });

  test("refreshing records does not ask to discard unrelated Topic settings", async function (assert) {
    await visit("/educustomize/topics/2");
    await click("input[name='memory']");
    await click(refresh);
    assert.dom(".dialog-body").doesNotExist();
    assert.strictEqual(reads, 2);
    assert.dom("input[name='memory']").isChecked();
    assert
      .dom(".educustomize__save-bar [role='status']")
      .includesText("Unsaved changes");
  });

  test("generating waits for a choice before replacing an edited review", async function (assert) {
    await visit("/educustomize/topics/2");
    await fillIn(draft(1), "Keep while generating.");
    await fillIn("select[name='post_id']", "12");
    await click(".educustomize > section:nth-of-type(2) button[type='submit']");
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-default");
    assert.strictEqual(generations, 0);
    assert.dom(draft(1)).hasValue("Keep while generating.");
    await click(".educustomize > section:nth-of-type(2) button[type='submit']");
    await click(".dialog-footer .btn-primary");
    assert.strictEqual(generations, 1);
    assert.dom(draft(1)).hasValue("Original 1");
  });

  test("approving one review protects another edited review and submits the chosen draft", async function (assert) {
    await visit("/educustomize/topics/2");
    await fillIn(draft(1), "Approved wording.");
    await fillIn(draft(2), "Other unsaved wording.");
    await click("#run-1 button[type='submit']");
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-default");
    assert.strictEqual(decisions.length, 0);
    assert.dom(draft(1)).hasValue("Approved wording.");
    assert.dom(draft(2)).hasValue("Other unsaved wording.");
    await click("#run-1 button[type='submit']");
    await click(".dialog-footer .btn-primary");
    assert.strictEqual(decisions.length, 1);
    assert.strictEqual(decisions[0].get("draft"), "Approved wording.");
    assert.dom(draft(2)).hasValue("Original 2");
  });

  test("regeneration protects another draft and refreshes the decision even when queueing fails", async function (assert) {
    await visit("/educustomize/topics/2");
    await fillIn(draft(2), "Keep the other review.");
    await click("#run-1 > button");
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-default");
    assert.strictEqual(decisions.length, 0);
    assert.strictEqual(generations, 0);
    assert.dom(draft(2)).hasValue("Keep the other review.");
    failGeneration = true;
    await click("#run-1 > button");
    await click(".dialog-footer .btn-primary");
    assert.dom(".dialog-body").includesText("Generation unavailable");
    await click(".dialog-footer .btn-primary");
    assert.strictEqual(generations, 1);
    assert.strictEqual(decisions[0].get("decision"), "regenerate");
    assert.dom(draft(1)).doesNotExist();
    assert.dom(draft(2)).hasValue("Original 2");
  });

  test("saving Topic settings asks before reloading an edited review", async function (assert) {
    await visit("/educustomize/topics/2");
    await fillIn(draft(1), "Keep during policy changes.");
    await click("input[name='memory']");
    await click(".educustomize > section:first-of-type button[type='submit']");
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-default");
    assert.strictEqual(saves, 0);
    assert.dom("input[name='memory']").isChecked();
    assert.dom(draft(1)).hasValue("Keep during policy changes.");
    await click(".educustomize > section:first-of-type button[type='submit']");
    await click(".dialog-footer .btn-primary");
    assert.strictEqual(saves, 1);
    assert.dom(draft(1)).hasValue("Original 1");
  });
});
