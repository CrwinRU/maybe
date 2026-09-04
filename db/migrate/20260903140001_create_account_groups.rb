class CreateAccountGroups < ActiveRecord::Migration[7.2]
  def change
    create_table :account_groups, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :account_groups, [:family_id, :name], unique: true, name: "index_account_groups_on_family_id_and_name"

    add_column :accounts, :account_group_id, :uuid
    add_foreign_key :accounts, :account_groups
    add_index :accounts, :account_group_id, name: "index_accounts_on_account_group_id"

    add_column :accounts, :include_in_group_balance, :boolean, null: false, default: true
  end
end
