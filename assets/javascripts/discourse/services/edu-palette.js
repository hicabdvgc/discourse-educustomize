import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import cookie from "discourse/lib/cookie";

const COOKIE = "educustomize_palette";
const MODES = ["dark", "light", "ambient"];

export default class EduPalette extends Service {
  @service interfaceColor;
  @service appEvents;

  @tracked mode = "light";
  initialized = false;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.initialized) {
      this.appEvents.off(
        "interface-color:changed",
        this,
        this.nativeColorChanged
      );
      delete document.documentElement.dataset.educustomizePalette;
    }
  }

  initialize() {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    const saved = cookie(COOKIE);
    const dark =
      this.interfaceColor.colorModeIsDark ||
      (this.interfaceColor.colorModeIsAuto &&
        window.matchMedia("(prefers-color-scheme: dark)").matches);
    this.select(MODES.includes(saved) ? saved : dark ? "dark" : "light");
    this.appEvents.on("interface-color:changed", this, this.nativeColorChanged);
  }

  select(mode) {
    if (!MODES.includes(mode)) {
      return;
    }
    if (mode === "dark") {
      this.interfaceColor.forceDarkMode();
    } else {
      this.interfaceColor.forceLightMode();
    }
    this.apply(mode);
  }

  apply(mode) {
    this.mode = mode;
    document.documentElement.dataset.educustomizePalette = mode;
    cookie(COOKIE, mode, { path: "/", expires: 365 });
  }

  nativeColorChanged(mode) {
    if (mode === "dark" || mode === "light") {
      this.apply(mode);
    }
  }
}
