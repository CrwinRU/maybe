class IncomeStatement::FamilyStats
  def initialize(family, interval: "month")
    @family = family
    @interval = interval
  end

  def call
    ActiveRecord::Base.connection.select_all(sanitized_query_sql).map do |row|
      StatRow.new(
        classification: row["classification"],
        median: row["median"],
        avg: row["avg"]
      )
    end
  end

  private
    StatRow = Data.define(:classification, :median, :avg)

    def sanitized_query_sql
      ActiveRecord::Base.sanitize_sql_array([
        query_sql,
        {
          target_currency: @family.currency,
          interval: @interval,
          family_id: @family.id
        }
      ])
    end

    def query_sql
      <<~SQL
        -- FIX (step2-income-statement-stats): классификация income/expense считается
        -- по знаку нетированной суммы всех транзакций за период, а не по знаку каждой строки.
        WITH period_totals AS (
          SELECT
            date_trunc(:interval, ae.date) as period,
            SUM(ae.amount * COALESCE(er.rate, 1)) as net_total
          FROM transactions t
          JOIN entries ae ON ae.entryable_id = t.id AND ae.entryable_type = 'Transaction'
          JOIN accounts a ON a.id = ae.account_id
          LEFT JOIN exchange_rates er ON (
            er.date = ae.date AND
            er.from_currency = ae.currency AND
            er.to_currency = :target_currency
          )
          WHERE a.family_id = :family_id
            AND t.kind NOT IN ('funds_movement', 'one_time', 'cc_payment')
            AND ae.excluded = false
          GROUP BY period
        )
        SELECT
          CASE WHEN net_total < 0 THEN 'income' ELSE 'expense' END as classification,
          ABS(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY net_total)) as median,
          ABS(AVG(net_total)) as avg
        FROM period_totals
        GROUP BY CASE WHEN net_total < 0 THEN 'income' ELSE 'expense' END;
      SQL
    end
end
