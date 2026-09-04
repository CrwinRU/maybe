class CreateEntrySplits < ActiveRecord::Migration[7.2]
  def change
    create_table :entry_splits, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :entry, null: false, foreign_key: true, type: :uuid
      t.references :category, null: true, foreign_key: true, type: :uuid
      t.decimal :amount, precision: 19, scale: 4, null: false
      t.boolean :locked, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :entry_splits, [:entry_id, :position], name: "index_entry_splits_on_entry_id_and_position"
  end
end
