class AddReconciledAtToEntries < ActiveRecord::Migration[7.2]
  def change
    add_column :entries, :reconciled_at, :datetime
  end
end
