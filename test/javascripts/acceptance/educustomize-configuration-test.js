import {
  click,
  fillIn,
  settled,
  triggerEvent,
  triggerKeyEvent,
  visit,
  waitFor,
} from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, createFile } from "discourse/tests/helpers/qunit-helpers";

acceptance("Educustomize | configuration migration", function (needs) {
  needs.user({ admin: false });
  needs.settings({ educustomize_enabled: true });

  let failSave;
  let agents;
  let created;
  let savedAgent;
  let previewRequests;
  const configuration = {
    format: "discourse-educustomize/agent-config",
    schema_version: 1,
    root: "dais",
    agents: [
      {
        key: "dais",
        name: "Portable assistant",
        description: "Portable teaching role",
        system_prompt: "Original prompt.",
        skills: [
          {
            name: "Evidence",
            description: "Check support.",
            instructions: "Ask for evidence.",
          },
        ],
        model: { provider: "other", name: "missing", display_name: "Source" },
        enabled: true,
        temperature: 0.4,
        top_p: 0.7,
        tools: ["Time"],
        delegates: [],
      },
    ],
  };

  needs.hooks.beforeEach(() => {
    history.replaceState(null, "", location.pathname + location.search);
    failSave = false;
    agents = [];
    created = null;
    savedAgent = null;
    previewRequests = 0;
  });

  needs.pretender((server, helper) => {
    server.get("/educustomize/courses.json", () =>
      helper.response({ courses: [], dependencies: {}, can_create: false })
    );
    server.get("/educustomize/courses/1.json", () =>
      helper.response({
        course: {
          id: 1,
          name: "Migration course",
          description: "Course",
          color: "0088CC",
        },
      })
    );
    server.get("/educustomize/courses/1/agents.json", () =>
      helper.response({
        agents,
        models: [
          { id: 55, name: "Destination", provider: "fake", model_name: "fake" },
        ],
        tools: ["Time"],
        topics: [],
        dependencies: { ai: true },
      })
    );
    server.get("/educustomize/topics/2.json", () =>
      helper.response({
        topic_id: 2,
        title: "Discussion",
        course_id: 1,
        policy: { ai_agent_id: 88, reviewer_id: 1, require_review: true },
        agents,
        workflows: [],
        reviewers: [{ id: 1, name: "Teacher" }],
        posts: [],
        ready: false,
        readiness_reasons: [],
      })
    );
    server.post(
      "/educustomize/courses/1/agent-configurations/preview.json",
      (request) => {
        previewRequests++;
        return helper.response({
          document: JSON.parse(request.requestBody).document,
          model_mappings: { dais: null },
        });
      }
    );
    server.post(
      "/educustomize/courses/1/agent-configurations.json",
      (request) => {
        created = JSON.parse(request.requestBody);
        agents = created.document.agents.map((agent) => ({
          ...agent,
          id: 42,
          default_llm_id: created.model_mappings[agent.key],
          subagent_ids: [],
          upload_ids: [],
          uploads: [],
        }));
        return helper.response(201, { agent_id: 42, agent_ids: { dais: 42 } });
      }
    );
    server.put("/educustomize/courses/1/agents/88.json", (request) => {
      if (failSave) {
        return helper.response(422, {
          errors: ["The model authorization changed."],
        });
      }
      savedAgent = JSON.parse(request.requestBody).agent;
      agents = agents.map((agent) =>
        agent.id === 88 ? { ...agent, ...savedAgent } : agent
      );
      return helper.response({ agent: savedAgent });
    });
  });

  async function chooseFile(contents) {
    await click("[data-area='migration']");
    const transfer = new DataTransfer();
    transfer.items.add(
      createFile("assistant.json", "application/json", contents)
    );
    const input = document.querySelector(
      ".educustomize__import input[type='file']"
    );
    input.files = transfer.files;
    await triggerEvent(input, "change");
    await click(".educustomize__import > button");
    await waitFor(
      ".educustomize__import form, .educustomize__import [role='alert']"
    );
  }

  test("invalid JSON is explained before a preview request", async function (assert) {
    await visit("/educustomize/courses/1");
    await chooseFile("{invalid");
    assert
      .dom(".educustomize__import [role='alert']")
      .hasText(
        "The platform could not read this file as valid JSON. You need to correct its JSON syntax before trying again."
      );
    assert.strictEqual(previewRequests, 0);
    assert.dom(".educustomize__import form").doesNotExist();
  });

  test("Bloc selects two Delegates immediately and saves before opening its assistant", async function (assert) {
    agents = ["Dais", "Tutor", "Critic"].map((name, index) => ({
      ...configuration.agents[0],
      id: 88 + index,
      name,
      default_llm_id: 55,
      subagent_ids: [],
      uploads: [],
      upload_ids: [],
    }));
    await visit("/educustomize/courses/1");
    await click("[data-area='bloc']");
    await fillIn(".educustomize__dais-picker select", "88");
    assert.dom(".educustomize__bloc h4").hasText("Dais");
    const choices = document.querySelectorAll(
      ".educustomize__bloc .educustomize__choice input"
    );
    assert.strictEqual(choices.length, 2);
    await click(choices[0]);
    await click(choices[1]);
    assert.dom(".educustomize__choices [role='status']").hasText("Selected: 2");
    await click("[data-area='ai']");
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-default");
    assert
      .dom(".educustomize__bloc .educustomize__choice input:checked")
      .exists({ count: 2 });
    await click(".educustomize__bloc form button[type='submit']");
    assert.deepEqual(savedAgent, { subagent_ids: [89, 90] });
    await click(".educustomize__bloc > button");
    assert.dom(".educustomize__agent-editor h3").hasText("Dais");
    assert
      .dom("textarea[name='system_prompt']")
      .hasValue(configuration.agents[0].system_prompt);
    assert.dom(".educustomize__agent-editor .educustomize__export").exists();
    assert.dom(".educustomize__bloc").doesNotExist();
  });

  test("preview edits every source field and requires a model before creating and reopening a copy", async function (assert) {
    await visit("/educustomize/courses/1");
    await chooseFile(JSON.stringify(configuration));
    assert.strictEqual(previewRequests, 1);
    assert
      .dom("textarea[name='agents.0.system_prompt']")
      .hasValue("Original prompt.");
    assert.dom("input[name='agents.0.skills.0.name']").hasValue("Evidence");
    await click(".educustomize__import form button[type='submit']");
    assert
      .dom(".educustomize__import [role='alert']")
      .hasText(
        "You must choose an authorized destination model for this assistant."
      );
    assert.strictEqual(created, null);

    await fillIn("input[name='agents.0.name']", "Edited portable assistant");
    await fillIn(
      "textarea[name='agents.0.system_prompt']",
      "Edited original prompt."
    );
    await fillIn(
      "textarea[name='agents.0.skills.0.instructions']",
      "Compare two explanations."
    );
    const addSkill = [
      ...document.querySelectorAll(".educustomize__import button"),
    ].find((button) => button.textContent.trim() === "Add skill");
    await click(addSkill);
    assert
      .dom(".educustomize__import .educustomize__skill")
      .exists({ count: 2 });
    await fillIn("input[name='agents.0.skills.1.name']", "Temporary skill");
    await fillIn(
      "textarea[name='agents.0.skills.1.instructions']",
      "Temporary instructions."
    );
    await click(
      document.querySelectorAll(
        ".educustomize__import .educustomize__skill button"
      )[1]
    );
    assert
      .dom(".educustomize__import .educustomize__skill")
      .exists({ count: 1 });
    await fillIn("select[name='agents.0.default_llm_id']", "55");
    await click(".educustomize__advanced summary");
    await fillIn("input[name='agents.0.temperature']", "0.25");
    await click(".educustomize__import form button[type='submit']");
    assert.deepEqual(created.model_mappings, { dais: 55 });
    assert.deepEqual(created.document.agents[0], {
      ...configuration.agents[0],
      name: "Edited portable assistant",
      system_prompt: "Edited original prompt.",
      skills: [
        {
          ...configuration.agents[0].skills[0],
          instructions: "Compare two explanations.",
        },
      ],
      model: { provider: "fake", name: "fake", display_name: "Destination" },
      temperature: 0.25,
    });
    assert
      .dom(".educustomize__agent-editor h3")
      .hasText("Edited portable assistant");
    assert
      .dom(".educustomize__agent-editor textarea[name='system_prompt']")
      .hasValue("Edited original prompt.");
    assert
      .dom(".educustomize__agent-editor textarea[name='skills.0.instructions']")
      .hasValue("Compare two explanations.");
    assert.dom(".educustomize__agent-editor .educustomize__export").exists();
    assert.dom(".educustomize__agent-editor p button").doesNotExist();
    assert
      .dom(".educustomize")
      .includesText("upload their knowledge materials again");
  });
  function existingAssistant() {
    agents = [
      {
        ...configuration.agents[0],
        id: 88,
        name: "Saved assistant",
        default_llm_id: 55,
        subagent_ids: [],
        upload_ids: [],
        uploads: [],
      },
    ];
  }

  test("Topic edit-assistant navigation opens the bound assistant directly", async function (assert) {
    existingAssistant();
    await visit("/educustomize/topics/2");
    await click("input[name='auto_reply']");
    await click("a[href='/educustomize/courses/1#ai-88']");
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-primary");
    assert.dom(".educustomize__agent-editor").exists();
    assert
      .dom("textarea[name='system_prompt']")
      .hasValue(configuration.agents[0].system_prompt);
    assert.dom("[data-area='ai']").hasAttribute("aria-current", "page");
  });

  test("assistant hash links retain drafts until discard is confirmed", async function (assert) {
    existingAssistant();
    agents.push({ ...agents[0], id: 89, name: "Second assistant" });
    history.replaceState(null, "", "#ai-88");
    await visit("/educustomize/courses/1");
    await fillIn("textarea[name='system_prompt']", "Keep the first draft.");
    history.replaceState(null, "", "#ai-89");
    window.dispatchEvent(new HashChangeEvent("hashchange"));
    await settled();
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-default");
    assert
      .dom("textarea[name='system_prompt']")
      .hasValue("Keep the first draft.");
    assert.strictEqual(window.location.hash, "#ai-88");
    history.replaceState(null, "", "#ai-89");
    window.dispatchEvent(new HashChangeEvent("hashchange"));
    await settled();
    await click(".dialog-footer .btn-primary");
    assert.dom(".educustomize__agent-editor h3").hasText("Second assistant");
    assert
      .dom("textarea[name='system_prompt']")
      .hasValue(configuration.agents[0].system_prompt);
    assert.strictEqual(window.location.hash, "#ai-89");
  });

  test("help preserves the draft and closing it restores focus; leaving requires a choice", async function (assert) {
    existingAssistant();
    await visit("/educustomize/courses/1");
    await click("[data-area='ai']");
    await click(".educustomize__agent-summary button");
    await fillIn(
      "textarea[name='system_prompt']",
      "Keep this unsaved teaching instruction."
    );
    await click(".educustomize__help-button");
    assert.dom(".educustomize-help").exists();
    assert.dom(".educustomize-help").includesText("Prompt");
    assert
      .dom(
        ".educustomize-help a[href='/admin/plugins/discourse-ai/ai-secrets']"
      )
      .doesNotExist("Teachers are not sent to credential administration");
    await triggerKeyEvent(document.documentElement, "keydown", "Escape");
    assert.dom(".educustomize-help").doesNotExist();
    assert.dom(".educustomize__help-button").isFocused();
    assert
      .dom("textarea[name='system_prompt']")
      .hasValue("Keep this unsaved teaching instruction.");
    await click("[data-area='bloc']");
    assert.dom(".dialog-body").includesText("you have not saved");
    await click(".dialog-footer .btn-default");
    assert
      .dom("textarea[name='system_prompt']")
      .hasValue("Keep this unsaved teaching instruction.");
    await click("a[href='/educustomize']");
    await click(".dialog-footer .btn-primary");
    assert.dom(".educustomize__agent-editor").doesNotExist();
  });

  test("failed saving retains both draft and dirty state, then a successful retry reopens saved content", async function (assert) {
    existingAssistant();
    failSave = true;
    await visit("/educustomize/courses/1");
    await click("[data-area='ai']");
    await click(".educustomize__agent-summary button");
    await fillIn("textarea[name='system_prompt']", "Retained after failure.");
    await click(".educustomize__agent-editor button[type='submit']");
    assert.dom(".dialog-body").includesText("model authorization changed");
    await click(".dialog-footer .btn-primary");
    assert
      .dom("textarea[name='system_prompt']")
      .hasValue("Retained after failure.");
    assert
      .dom(".educustomize__save-bar [role='status']")
      .hasText("Unsaved changes");
    assert.dom(".educustomize__export").doesNotExist();
    failSave = false;
    await click(".educustomize__agent-editor button[type='submit']");
    assert.dom(".educustomize__agent-summary").exists();
    await click(".educustomize__agent-summary button");
    assert
      .dom("textarea[name='system_prompt']")
      .hasValue("Retained after failure.");
    assert.dom(".educustomize__export").exists();
  });

  test("import keeps edits across assistant previews and exposes the assistant with missing configuration", async function (assert) {
    await visit("/educustomize/courses/1");
    const document = structuredClone(configuration);
    document.agents[0].delegates = ["critic"];
    document.agents.push({
      ...structuredClone(configuration.agents[0]),
      key: "critic",
      name: "Critic",
      model: null,
      delegates: [],
    });
    await chooseFile(JSON.stringify(document));
    await fillIn(
      "textarea[name='agents.0.system_prompt']",
      "Edited root instructions."
    );
    await click(".educustomize__preview-nav button:nth-child(2)");
    assert
      .dom(".educustomize__import-agent:not([hidden]) h4")
      .hasText("Critic");
    await fillIn(
      "textarea[name='agents.1.system_prompt']",
      "Edited critique instructions."
    );
    await click(".educustomize__import button[type='submit']");
    assert
      .dom(".educustomize__import-agent:not([hidden]) h4")
      .hasText("Portable assistant");
    assert
      .dom("textarea[name='agents.0.system_prompt']")
      .hasValue("Edited root instructions.");
    await fillIn("select[name='agents.0.default_llm_id']", "55");
    await click(".educustomize__preview-nav button:nth-child(2)");
    assert
      .dom("textarea[name='agents.1.system_prompt']")
      .hasValue("Edited critique instructions.");
    await click(".educustomize__import button[type='submit']");
    assert.strictEqual(
      created.document.agents[0].system_prompt,
      "Edited root instructions."
    );
    assert.strictEqual(
      created.document.agents[1].system_prompt,
      "Edited critique instructions."
    );
  });
});
