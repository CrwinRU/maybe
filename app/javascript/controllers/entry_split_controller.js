import { Controller } from "@hotwired/stimulus"

// Управляет UI сплита транзакции:
// - Добавление/удаление строк сплита
// - Замочек (locked): заблокированная строка не пересчитывается
// - Пересчёт в реальном времени: сумма всех незаблокированных строк
//   меняется так, чтобы итог совпадал с суммой entry
export default class extends Controller {
  static targets = ["row", "rowAmount", "rowLocked", "total", "addButton", "remainderWarning"]
  static values  = { entryAmount: Number }

  connect() {
    this._recalculate()
  }

  entryAmountValueChanged() {
    this._recalculate()
  }

  // Добавить новую строку сплита (клон шаблона)
  addRow(event) {
    event.preventDefault()
    const template = this.element.querySelector("[data-split-template]")
    if (!template) return

    const clone = template.content.cloneNode(true)
    const idx   = this.rowTargets.length

    // Обновляем индексы полей Rails nested attributes
    clone.querySelectorAll("[name]").forEach(el => {
      el.name = el.name.replace(/\[\d+\]/, `[${idx}]`)
    })
    clone.querySelectorAll("[id]").forEach(el => {
      el.id = el.id.replace(/_\d+_/, `_${idx}_`)
    })

    this.element.querySelector("[data-split-rows]").appendChild(clone)
    this._recalculate()
  }

  // Удалить строку сплита
  removeRow(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-entry-split-target='row']")
    if (!row) return

    // Если у строки есть persisted id — помечаем _destroy вместо удаления DOM
    const destroyInput = row.querySelector("input[name*='_destroy']")
    if (destroyInput) {
      destroyInput.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
    this._recalculate()
  }

  // Переключить замочек строки
  toggleLock(event) {
    const row    = event.currentTarget.closest("[data-entry-split-target='row']")
    const locked = row.querySelector("[data-entry-split-target='rowLocked']")
    if (!locked) return

    const isLocked = locked.value === "true"
    locked.value = isLocked ? "false" : "true"

    // Визуальный класс
    event.currentTarget.dataset.locked = isLocked ? "false" : "true"
    this._recalculate()
  }

  // Пересчёт при ручном вводе суммы
  amountChanged() {
    this._recalculate()
  }

  // --- private ---

  _recalculate() {
    const total       = Math.abs(this.entryAmountValue)
    const rows        = this.rowTargets.filter(r => !r.hidden)
    const lockedRows  = rows.filter(r => this._isLocked(r))
    const freeRows    = rows.filter(r => !this._isLocked(r))

    const lockedSum   = lockedRows.reduce((s, r) => s + this._rowAmount(r), 0)
    const remainder   = total - lockedSum

    // Распределяем remainder поровну между свободными строками
    if (freeRows.length > 0) {
      const share    = remainder / freeRows.length
      const rounded  = parseFloat(share.toFixed(2))
      freeRows.forEach((r, i) => {
        // Последней строке отдаём остаток с учётом округления
        const val = (i === freeRows.length - 1)
          ? parseFloat((remainder - rounded * (freeRows.length - 1)).toFixed(2))
          : rounded
        this._setRowAmount(r, val)
      })
    }

    // Итог
    const currentSum = rows.reduce((s, r) => s + this._rowAmount(r), 0)
    const diff       = parseFloat((total - currentSum).toFixed(2))

    if (this.hasTotalTarget) {
      this.totalTarget.textContent = currentSum.toFixed(2)
      this.totalTarget.classList.toggle("text-red-500", Math.abs(diff) > 0.01)
    }

    if (this.hasRemainderWarningTarget) {
      this.remainderWarningTarget.hidden = Math.abs(diff) <= 0.01
      this.remainderWarningTarget.textContent = diff !== 0
        ? `Остаток: ${diff > 0 ? "+" : ""}${diff.toFixed(2)}`
        : ""
    }
  }

  _isLocked(row) {
    const locked = row.querySelector("[data-entry-split-target='rowLocked']")
    return locked && locked.value === "true"
  }

  _rowAmount(row) {
    const input = row.querySelector("[data-entry-split-target='rowAmount']")
    return input ? parseFloat(input.value) || 0 : 0
  }

  _setRowAmount(row, val) {
    const input = row.querySelector("[data-entry-split-target='rowAmount']")
    if (input && !this._isLocked(row)) input.value = val.toFixed(2)
  }
}
