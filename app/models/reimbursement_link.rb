class ReimbursementLink < ApplicationRecord
  # expense_entry — расходная запись, которую покрывает возмещение
  belongs_to :expense_entry, class_name: "Entry"
  # income_entry — доходная запись, являющаяся возмещением
  belongs_to :income_entry, class_name: "Entry"

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validate :amount_does_not_exceed_expense
  validate :amount_does_not_exceed_income
  validate :entries_belong_to_same_family

  private

    # Суммарное покрытие по одной расходной записи не может превышать её сумму
    def amount_does_not_exceed_expense
      return unless expense_entry && amount

      total_covered = expense_entry.reimbursement_links_as_expense
                                   .where.not(id: id)
                                   .sum(:amount) + amount
      if total_covered > expense_entry.amount.abs
        errors.add(:amount, :exceeds_expense,
          message: I18n.t("errors.reimbursement_links.exceeds_expense"))
      end
    end

    # Суммарное покрытие по одной доходной записи не может превышать её сумму
    def amount_does_not_exceed_income
      return unless income_entry && amount

      total_covered = income_entry.reimbursement_links_as_income
                                  .where.not(id: id)
                                  .sum(:amount) + amount
      if total_covered > income_entry.amount.abs
        errors.add(:amount, :exceeds_income,
          message: I18n.t("errors.reimbursement_links.exceeds_income"))
      end
    end

    # Обе записи должны принадлежать одной семье
    def entries_belong_to_same_family
      return unless expense_entry && income_entry
      unless expense_entry.account.family_id == income_entry.account.family_id
        errors.add(:base, :different_families,
          message: I18n.t("errors.reimbursement_links.different_families"))
      end
    end
end
