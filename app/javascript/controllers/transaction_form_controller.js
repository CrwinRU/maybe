import { Controller } from "@hotwired/stimulus"

// Управляет формой транзакции:
// 1. Переключатель знака (Расход/Доход) независим от набора категорий
// 2. Автокомплит контрагента — подтягивает категорию и notes с сервера
export default class extends Controller {
  static targets = [
    "amountInput",
    "amountSign",
    "categorySelect",
    "notesInput",
    "accountSelect",
    "merchantInput"
  ]

  static values = {
    autocompleteUrl: String,
    nature: { type: String, default: "outflow" }
  }

  connect() {
    this._applySign(this.natureValue)
  }

  // Вызывается кнопками Расход/Доход
  setNature(event) {
    const nature = event.currentTarget.dataset.nature
    this.natureValue = nature
    this._applySign(nature)
  }

  natureValueChanged(value) {
    // Обновляем hidden field :nature если он есть
    const hidden = this.element.querySelector("input[name='entry[nature]']")
    if (hidden) hidden.value = value
  }

  // Вызывается при выборе контрагента — GET /transactions/merchant_autocomplete
  async merchantChanged(event) {
    const merchantId  = event.currentTarget.value
    const accountId   = this._accountId()

    if (!merchantId || !accountId) return

    try {
      const url = `${this.autocompleteUrlValue}?merchant_id=${merchantId}&account_id=${accountId}`
      const resp = await fetch(url, { headers: { Accept: "application/json" } })
      if (!resp.ok) return
      const data = await resp.json()

      if (data.category_id && this.hasCategorySelectTarget) {
        this.categorySelectTarget.value = data.category_id
      }
      if (data.notes && this.hasNotesInputTarget) {
        this.notesInputTarget.value = data.notes
      }
    } catch (_e) {
      // молча игнорируем — автокомплит не блокирует сохранение
    }
  }

  // --- private ---

  _applySign(nature) {
    if (!this.hasAmountInputTarget) return

    const input = this.amountInputTarget
    const current = parseFloat(input.value) || 0
    const abs = Math.abs(current)

    // outflow → положительное число в поле (Rails делает его положительным в БД)
    // inflow  → отрицательное (кредит)
    input.value = nature === "inflow" ? -abs : abs

    // Визуальный маркер знака
    if (this.hasAmountSignTarget) {
      this.amountSignTarget.textContent = nature === "inflow" ? "+" : "−"
      this.amountSignTarget.dataset.nature = nature
    }
  }

  _accountId() {
    if (this.hasAccountSelectTarget) return this.accountSelectTarget.value
    // Если счёт захардкожен hidden field-ом
    const hidden = this.element.querySelector("input[name='entry[account_id]']")
    return hidden ? hidden.value : null
  }
}
