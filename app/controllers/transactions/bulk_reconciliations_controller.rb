class Transactions::BulkReconciliationsController < ApplicationController
  # POST /transactions/bulk_reconciliation
  # params: entry_ids[], reconciled (true/false)
  def create
    entry_ids = params[:entry_ids] || []
    reconciled = ActiveModel::Type::Boolean.new.cast(params[:reconciled])

    entries = Current.family.entries
                     .joins(:account)
                     .where(id: entry_ids)

    new_value = reconciled ? Time.current : nil
    entries.update_all(reconciled_at: new_value)

    respond_to do |format|
      format.turbo_stream do
        streams = entries.map do |entry|
          turbo_stream.replace(
            dom_id(entry),
            partial: "transactions/transaction",
            locals: { entry: entry, balance_trend: nil, view_ctx: "global" }
          )
        end
        render turbo_stream: streams
      end
      format.html { redirect_back_or_to transactions_path }
    end
  end
end
