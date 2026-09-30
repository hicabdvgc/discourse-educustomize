import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import EduReview from "discourse/plugins/discourse-educustomize/discourse/components/edu-review";

module("Educustomize | review readability", function (hooks) {
  setupRenderingTest(hooks);

  test("draft preview renders safe Markdown and returns to the same editable draft", async function (assert) {
    this.run = { id: 1, can_review: true, draft: "Original reply" };
    await render(<template><EduReview @run={{this.run}} /></template>);
    await fillIn(
      "textarea[name='draft']",
      "**Teaching point**\n\n<script>alert(1)</script>"
    );
    await click(".form-kit > button");
    assert.dom(".educustomize__draft strong").hasText("Teaching point");
    assert.dom(".educustomize__draft script").doesNotExist();
    assert
      .dom(".educustomize__save-bar [role='status']")
      .hasText("Unsaved changes");
    await click(".form-kit > button");
    assert
      .dom("textarea[name='draft']")
      .hasValue("**Teaching point**\n\n<script>alert(1)</script>");
  });
});
