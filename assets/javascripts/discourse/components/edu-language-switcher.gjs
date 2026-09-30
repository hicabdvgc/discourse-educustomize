import LanguageSwitcher from "discourse/components/language-switcher";

export default class EduLanguageSwitcher extends LanguageSwitcher {
  get content() {
    return [
      { value: "zh_CN", name: "简体中文" },
      { value: "en", name: "English" },
    ].map((language) => ({
      ...language,
      isActive: language.value === this.currentLocale,
    }));
  }
}
