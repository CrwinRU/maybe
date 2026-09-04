class Transfer::Creator
  # Логика "любые 2 из 3":
  #   outflow_amount + exchange_rate  → inflow_amount = outflow_amount * exchange_rate
  #   outflow_amount + inflow_amount  → exchange_rate = outflow_amount / inflow_amount
  #   inflow_amount  + exchange_rate  → outflow_amount = inflow_amount / exchange_rate (редко)
  #
  # outflow_amount — фиксированная точка, никогда не пересчитывается автоматически.
  # При совпадении валют exchange_rate игнорируется, inflow_amount = outflow_amount.

  def initialize(
    family:,
    source_account_id:,
    destination_account_id:,
    date:,                         # legacy: используется как outflow_at если outflow_at не передан
    amount:,                       # legacy alias для outflow_amount
    outflow_amount: nil,
    inflow_amount: nil,
    exchange_rate: nil,
    outflow_at: nil,
    inflow_at: nil
  )
    @family             = family
    @source_account     = family.accounts.find(source_account_id)
    @destination_account = family.accounts.find(destination_account_id)

    # Совместимость с legacy-вызовами (передают только amount и date)
    @outflow_amount = (outflow_amount || amount).to_d
    @outflow_at     = outflow_at || date
    @inflow_at      = inflow_at || @outflow_at

    # Разрешаем 2-из-3
    @exchange_rate, @inflow_amount = resolve_amounts(
      outflow_amount: @outflow_amount,
      inflow_amount:  inflow_amount&.to_d,
      exchange_rate:  exchange_rate&.to_d
    )
  end

  def create
    transfer = Transfer.new(
      inflow_transaction:  build_inflow_transaction,
      outflow_transaction: build_outflow_transaction,
      status:              "confirmed",
      exchange_rate:       same_currency? ? nil : @exchange_rate,
      outflow_at:          @outflow_at,
      inflow_at:           @inflow_at
    )

    if transfer.save
      source_account.sync_later
      destination_account.sync_later
    end

    transfer
  end

  private
    attr_reader :family, :source_account, :destination_account,
                :outflow_amount, :inflow_amount, :exchange_rate,
                :outflow_at, :inflow_at

    # Возвращает [exchange_rate, inflow_amount] с учётом логики 2-из-3.
    def resolve_amounts(outflow_amount:, inflow_amount:, exchange_rate:)
      if same_currency?
        return [nil, outflow_amount]
      end

      if inflow_amount.present? && exchange_rate.present?
        # Оба заданы — доверяем inflow_amount, exchange_rate пересчитываем для консистентности
        rate = outflow_amount / inflow_amount
        [rate, inflow_amount]
      elsif exchange_rate.present?
        [exchange_rate, (outflow_amount * exchange_rate).round(4)]
      elsif inflow_amount.present?
        rate = inflow_amount.positive? ? outflow_amount / inflow_amount : 1.0
        [rate, inflow_amount]
      else
        # Ничего не задано — fallback через exchange_rates, как раньше
        converted = Money.new(outflow_amount, source_account.currency)
                         .exchange_to(destination_account.currency, date: outflow_at, fallback_rate: 1.0)
        rate = converted.rate || 1.0
        [rate, converted.amount.abs.round(4)]
      end
    end

    def same_currency?
      source_account.currency == destination_account.currency
    end

    def build_outflow_transaction
      Transaction.new(
        kind: outflow_kind,
        entry: source_account.entries.build(
          amount:   outflow_amount.abs,
          currency: source_account.currency,
          date:     outflow_at,
          name:     "#{name_prefix} to #{destination_account.name}"
        )
      )
    end

    def build_inflow_transaction
      Transaction.new(
        kind: "funds_movement",
        entry: destination_account.entries.build(
          amount:   inflow_amount.abs * -1,
          currency: destination_account.currency,
          date:     inflow_at,
          name:     "#{name_prefix} from #{source_account.name}"
        )
      )
    end

    def outflow_kind
      if destination_account.loan?
        "loan_payment"
      elsif destination_account.liability?
        "cc_payment"
      else
        "funds_movement"
      end
    end

    def name_prefix
      destination_account.liability? ? "Payment" : "Transfer"
    end
end
