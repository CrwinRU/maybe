class EntrySplit < ApplicationRecord
  belongs_to :entry
  belongs_to :category, optional: true

  validates :amount, presence: true, numericality: { other_than: 0 }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Сумма всех сплитов должна совпадать с суммой entry — проверяется на уровне Entry
  scope :ordered, -> { order(:position) }

  # Возвращает долю этого сплита от общей суммы entry
  def percentage_of(total_amount)
    return 0 if total_amount.zero?
    (amount.abs / total_amount.abs * 100).round(2)
  end
end
