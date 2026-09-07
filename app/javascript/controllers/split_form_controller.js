import { Controller } from "@hotwired/stimulus"

// Управляет UI сплита транзакции:
// - Добавление/удаление строк
// - Замочки: заблокированные строки исключаются из автопересчёта
// - Пересчёт: при изменении суммы в любой незаблокированной строке
//   остаток распределяется равными долями между остальными незаблокированными
// - Отображение итога и предупреждения о несовпадении

export default class extends Controller {
  static targets = ["linesContainer", "lineTemplate", "line",
                     "amountInput", "lockedField", "lockButton",
                     "lockOpen", "lockClosed", "destroyField",
                     "positionField", "totalDisplay", "mismatchWarning"]

  static values = {
    total: Number   // entry.amount.abs — передаётся из партиала
  }

  connect() {
    this._updatePositions()
    this._renderTotal()
    this._initLockIcons()
    // Сохраняем ссылку на bound-функцию для корректного removeEventListener
    this._boundOnActivate = this._onActivate.bind(this)
    this.element.addEventListener("split-form:activate", this._boundOnActivate)
  }

  disconnect() {
    this.element.removeEventListener("split-form:activate", this._boundOnActivate)
  }

  _onActivate() {
    if (this._activeLines().length === 0) {
      this.addLine()
      this.addLine()
    }
  }

  // ── Добавить строку ──────────────────────────────────────────────────────
  addLine() {
    const template = this.lineTemplateTarget
    const content  = template.innerHTML.replace(/NEW_RECORD/g, Date.now().toString())
    this.linesContainerTarget.insertAdjacentHTML("beforeend", content)
    this._updatePositions()
    this._recalcUnlocked()       // перераспределяем остаток в новую строку
    this._renderTotal()
    this._initLockIcons()
  }

  // ── Удалить строку ───────────────────────────────────────────────────────
  removeLine(event) {
    const line = event.currentTarget.closest("[data-split-form-target='line']")
    if (!line) return

    const destroyField = line.querySelector("[data-split-form-target='destroyField']")
    if (destroyField) {
      destroyField.value = "1"
      line.classList.add("hidden")  // скрываем, но не удаляем из DOM (нужно для Rails)
    } else {
      line.remove()                 // новая несохранённая строка — можно удалить
    }

    this._updatePositions()
    this._recalcUnlocked()
    this._renderTotal()
  }

  // ── Переключить замочек ──────────────────────────────────────────────────
  toggleLock(event) {
    const line = event.currentTarget.closest("[data-split-form-target='line']")
    if (!line) return

    const isLocked = line.dataset.locked === "true"
    const newLocked = !isLocked
    line.dataset.locked = newLocked ? "true" : "false"

    // Синхронизируем hidden field
    const lockedField = line.querySelector("[data-split-form-target='lockedField']")
    if (lockedField) lockedField.value = newLocked ? "true" : "false"

    // Меняем иконки
    const openIcon   = line.querySelector("[data-split-form-target='lockOpen']")
    const closedIcon = line.querySelector("[data-split-form-target='lockClosed']")
    openIcon?.classList.toggle("hidden", newLocked)
    closedIcon?.classList.toggle("hidden", !newLocked)
  }

  // ── Изменение суммы в строке ─────────────────────────────────────────────
  onAmountInput(event) {
    const line = event.currentTarget.closest("[data-split-form-target='line']")
    if (!line || line.dataset.locked === "true") return

    // Помечаем эту строку как «только что введённую» — она фиксируется при пересчёте
    this._recalcOthers(line)
    this._renderTotal()
  }

  // ── Приватные методы ─────────────────────────────────────────────────────

  // Перераспределяем незаблокированные строки равными долями
  _recalcUnlocked() {
    const activeLines  = this._activeLines()
    const unlocked     = activeLines.filter(l => l.dataset.locked !== "true")
    if (unlocked.length === 0) return

    const lockedSum = activeLines
      .filter(l => l.dataset.locked === "true")
      .reduce((sum, l) => sum + this._lineAmount(l), 0)

    const remainder = Math.max(0, this.totalValue - lockedSum)
    const share     = this._round(remainder / unlocked.length)
    let   assigned  = 0

    unlocked.forEach((line, idx) => {
      const input = line.querySelector("[data-split-form-target='amountInput']")
      if (!input) return
      if (idx === unlocked.length - 1) {
        // Последней строке отдаём остаток (компенсируем округление)
        input.value = this._round(remainder - assigned)
      } else {
        input.value = share
        assigned   += share
      }
    })
  }

  // При ручном вводе в строку — пересчитываем только остальные незаблокированные
  _recalcOthers(changedLine) {
    const activeLines = this._activeLines()
    const changedAmt  = this._lineAmount(changedLine)
    const locked      = activeLines.filter(l => l.dataset.locked === "true")
    const others      = activeLines.filter(l => l !== changedLine && l.dataset.locked !== "true")

    const lockedSum  = locked.reduce((sum, l) => sum + this._lineAmount(l), 0)
    const remainder  = Math.max(0, this.totalValue - lockedSum - changedAmt)

    if (others.length === 0) return

    const share  = this._round(remainder / others.length)
    let assigned = 0

    others.forEach((line, idx) => {
      const input = line.querySelector("[data-split-form-target='amountInput']")
      if (!input) return
      if (idx === others.length - 1) {
        input.value = this._round(remainder - assigned)
      } else {
        input.value = share
        assigned   += share
      }
    })
  }

  // Обновить атрибут position у видимых строк
  _updatePositions() {
    this._activeLines().forEach((line, idx) => {
      const field = line.querySelector("[data-split-form-target='positionField']")
      if (field) field.value = idx
    })
  }

  // Отобразить итоговую сумму и предупреждение
  _renderTotal() {
    const total   = this.totalValue
    const current = this._activeLines().reduce((sum, l) => sum + this._lineAmount(l), 0)

    if (this.hasTotalDisplayTarget) {
      this.totalDisplayTarget.textContent = `${this._round(current)} / ${total}`
    }

    const warn   = this.hasMismatchWarningTarget ? this.mismatchWarningTarget : null
    const diff   = Math.abs(this._round(current) - total)
    if (warn) {
      warn.textContent = diff > 0.005 ? `Δ ${this._round(diff)}` : ""
      warn.classList.toggle("hidden", diff <= 0.005)
    }
  }

  // Инициализировать иконки замочков для уже существующих строк
  _initLockIcons() {
    this._activeLines().forEach(line => {
      const isLocked  = line.dataset.locked === "true"
      const openIcon  = line.querySelector("[data-split-form-target='lockOpen']")
      const closeIcon = line.querySelector("[data-split-form-target='lockClosed']")
      openIcon?.classList.toggle("hidden", isLocked)
      closeIcon?.classList.toggle("hidden", !isLocked)
    })
  }

  // Видимые (не помеченные на удаление) строки
  _activeLines() {
    return this.lineTargets.filter(l => !l.classList.contains("hidden"))
  }

  _lineAmount(line) {
    const input = line.querySelector("[data-split-form-target='amountInput']")
    return parseFloat(input?.value) || 0
  }

  _round(val) {
    return Math.round(val * 100) / 100
  }
}
