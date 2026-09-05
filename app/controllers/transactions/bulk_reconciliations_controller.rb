module Transactions
  class BulkReconciliationsController < ApplicationController
    def create
      entries = Current.family.entries.where(id: bulk_params[:entry_ids])

      if bulk_params[:reconciled] == "true"
        entries.update_all(reconciled_at: Time.current)
      else
        entries.update_all(reconciled_at: nil)
      end

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.action(:refresh, "") }
        format.html { redirect_back_or_to transactions_path }
      end
    end

    private

      def bulk_params
        params.require(:bulk_reconciliation).permit(:reconciled, entry_ids: [])
      end
  end
end
