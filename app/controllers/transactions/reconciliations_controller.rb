module Transactions
  class ReconciliationsController < ApplicationController
    before_action :set_entry

    def update
      if @entry.reconciled_at.present?
        @entry.update!(reconciled_at: nil)
      else
        @entry.update!(reconciled_at: Time.current)
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(@entry)
        end
        format.html { redirect_back_or_to transactions_path }
      end
    end

    private

      def set_entry
        @entry = Current.family.entries.find(params[:transaction_id])
      end
  end
end
