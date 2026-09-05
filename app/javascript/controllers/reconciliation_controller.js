import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="reconciliation"
export default class extends Controller {
  static targets = ["banner", "showReconciled"];
  static values  = { active: Boolean, showReconciled: Boolean };

  connect() {
    this.activeValue        = false;
    this.showReconciledValue = false;
  }

  // Тумблер «Режим сверки» в тулбаре
  toggle() {
    this.activeValue = !this.activeValue;
    this.#applyMode();
  }

  // Переключатель «Показать сверенные» внутри баннера
  toggleShowReconciled() {
    this.showReconciledValue = !this.showReconciledValue;
    this.#applyShowReconciled();
  }

  // Закрыть режим (кнопка × в баннере)
  exit() {
    this.activeValue = false;
    this.#applyMode();
  }

  // Тап по строке транзакции → submit скрытой формы
  toggleRow(event) {
    if (!this.activeValue) return;
    if (event.target.closest("a, button, input")) return;
    const form = event.currentTarget.querySelector("[data-reconciliation-form]");
    if (form) form.requestSubmit();
  }

  // --- private ---

  #applyMode() {
    if (this.activeValue) {
      this.bannerTarget.classList.remove("hidden");
      document.body.classList.add("reconciliation-mode");
    } else {
      this.bannerTarget.classList.add("hidden");
      document.body.classList.remove("reconciliation-mode");
      this.showReconciledValue = false;
      this.#applyShowReconciled();
    }
  }

  #applyShowReconciled() {
    const input = document.getElementById("reconciled_filter_input");
    if (!input) return;
    input.value = this.showReconciledValue ? "all" : "unreconciled";
    input.closest("form")?.requestSubmit();
  }
}
