class IncomeStatement::Totals
  def initialize(family, transactions_scope:)
    @family = family
    @transactions_scope = transactions_scope
  end

  def call
    ActiveRecord::Base.connection.select_all(query_sql).map do |row|
      TotalsRow.new(
        parent_category_id: row["parent_category_id"],
        category_id: row["category_id"],
        classification: row["classification"],
        total: row["total"],
        transactions_count: row["transactions_count"]
      )
    end
  end

  private
    TotalsRow = Data.define(:parent_category_id, :category_id, :classification, :total, :transactions_count)

    def query_sql
      ActiveRecord::Base.sanitize_sql_array([
        optimized_query_sql,
        sql_params
      ])
    end

    # OPTIMIZED: Direct SUM aggregation without unnecessary time bucketing
    # Eliminates CTE and intermediate date grouping for maximum performance
    #
    # FIX (Фаза 3, step3-income-statement-totals): классификация income/expense
    # считается по знаку УЖЕ НЕТИРОВАННОЙ суммы категории, а не по знаку каждой
    # отдельной строки. Раньше GROUP BY включал CASE по ae.amount, из-за чего
    # возврат (отрицательная сумма) в расходной категории улетал в отдельную
    # строку 'income' вместо того, чтобы уменьшить итоговый расход.
    def optimized_query_sql
      <<~SQL
        SELECT
          category_id,
          parent_category_id,
          CASE WHEN net_total < 0 THEN 'income' ELSE 'expense' END as classification,
          ABS(net_total) as total,
          transactions_count
        FROM (
          SELECT
            c.id as category_id,
            c.parent_id as parent_category_id,
            SUM(ae.amount * COALESCE(er.rate, 1)) as net_total,
            COUNT(ae.id) as transactions_count
          FROM (#{@transactions_scope.to_sql}) at
          JOIN entries ae ON ae.entryable_id = at.id AND ae.entryable_type = 'Transaction'
          LEFT JOIN categories c ON c.id = at.category_id
          LEFT JOIN exchange_rates er ON (
            er.date = ae.date AND
            er.from_currency = ae.currency AND
            er.to_currency = :target_currency
          )
          WHERE at.kind NOT IN ('funds_movement', 'one_time', 'cc_payment')
            AND ae.excluded = false
          GROUP BY c.id, c.parent_id
        ) category_totals;
      SQL
    end

    def sql_params
      {
        target_currency: @family.currency
      }
    end
end
