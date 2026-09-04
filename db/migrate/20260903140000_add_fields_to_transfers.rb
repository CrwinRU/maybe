class AddFieldsToTransfers < ActiveRecord::Migration[7.2]
  def change
    add_column :transfers, :exchange_rate, :decimal, precision: 19, scale: 6
    add_column :transfers, :outflow_at, :datetime
    add_column :transfers, :inflow_at, :datetime
  end
end
