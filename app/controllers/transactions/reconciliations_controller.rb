class Transactions::ReconciliationsController < ApplicationController
  before_action :set_entry

  # PATCH /transactions/:transaction_id/reconciliation
  # Тогл: если не сверено — ставим Time.current, если сверено — снимаем (nil)
  def update
    new_value = @entry.reconciled_at.present? ? nil : Time.current
    @entry.update!(reconciled_at: new_value)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@entry),
          partial: "transactions/transaction",
          locals: { entry: @entry, balance_trend: nil, view_ctx: params[:view_ctx] || "global" }
        )
      end
      format.html { redirect_back_or_to transactions_path }
    end
  end

  private

    def set_entry
      transaction = Current.family.transactions.find(params[:transaction_id])
      @entry = transaction.entry
    end
end
