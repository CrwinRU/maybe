class AccountGroup < ApplicationRecord
  belongs_to :family
  has_many :accounts, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :family_id }

  default_scope { order(:position) }

  # Баланс группы — сумма дочерних счетов с include_in_group_balance: true.
  # Вычисляется на лету, не хранится в БД.
  def balance
    accounts.where(include_in_group_balance: true).sum(:balance)
  end

  def balance_money
    Money.new(balance, family.currency)
  end
end
