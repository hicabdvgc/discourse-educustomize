import { i18n } from "discourse-i18n";

export default function confirmEduDiscard(dialog, dirty, proceed) {
  if (!dirty) {
    return proceed();
  }
  return dialog.confirm({
    title: i18n("educustomize.ui.unsaved_title"),
    message: i18n("educustomize.ui.unsaved_message"),
    confirmButtonLabel: "educustomize.ui.discard",
    cancelButtonLabel: "educustomize.ui.keep_editing",
    didConfirm: proceed,
  });
}
