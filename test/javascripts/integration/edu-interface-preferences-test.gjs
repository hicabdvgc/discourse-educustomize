import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import cookie from "discourse/lib/cookie";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import EduInterfacePreferences from "discourse/plugins/discourse-educustomize/discourse/components/edu-interface-preferences";

module("Educustomize | interface preferences", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.allow_user_locale = true;
    const session = this.owner.lookup("service:session");
    session.darkModeAvailable = true;
    session.defaultColorSchemeIsDark = false;
    this.originalColor = cookie("forced_color_mode");
    this.originalPalette = cookie("educustomize_palette");
  });

  hooks.afterEach(function () {
    cookie("forced_color_mode", this.originalColor, { path: "/" });
    cookie("educustomize_palette", this.originalPalette, { path: "/" });
  });

  test("anonymous users can find both languages without enabling content translation", async function (assert) {
    this.siteSettings.content_localization_enabled = false;
    await render(<template><EduInterfacePreferences /></template>);
    assert.dom(".educustomize-interface").includesText("Color mode");
    assert.dom(".educustomize-interface").includesText("语言 / Language");
    await triggerEvent(".language-switcher__locale", "click");
    assert.dom("[data-menu-option-id='en'] button").hasText("English");
    assert.dom("[data-menu-option-id='zh_CN'] button").hasText("简体中文");
  });

  test("three palettes retain native dark mode and persist the ambient choice", async function (assert) {
    cookie("educustomize_palette", "ambient", { path: "/" });
    const palette = this.owner.lookup("service:edu-palette");
    palette.initialize();
    await render(<template><EduInterfacePreferences /></template>);
    assert.dom(".educustomize-color-selector").includesText("Ambient");
    assert.strictEqual(cookie("forced_color_mode"), "light");
    assert.strictEqual(
      document.documentElement.dataset.educustomizePalette,
      "ambient"
    );
    await triggerEvent(".educustomize-color-selector", "click");
    await triggerEvent(".educustomize-color-selector__dark", "click");
    assert.strictEqual(cookie("forced_color_mode"), "dark");
    assert.strictEqual(
      document.documentElement.dataset.educustomizePalette,
      "dark"
    );
    await triggerEvent(".educustomize-color-selector", "click");
    await triggerEvent(".educustomize-color-selector__light", "click");
    assert.strictEqual(cookie("forced_color_mode"), "light");
    assert.strictEqual(cookie("educustomize_palette"), "light");
    this.owner.lookup("service:interface-color").forceDarkMode();
    assert.strictEqual(palette.mode, "dark");
  });
});
