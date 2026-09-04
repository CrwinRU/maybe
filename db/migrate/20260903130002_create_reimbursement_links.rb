class CreateReimbursementLinks < ActiveRecord::Migration[7.2]
  def change
    create_table :reimbursement_links, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      # Расходная транзакция (entry), которую покрывает возмещение
      t.references :expense_entry, null: false, foreign_key: { to_table: :entries }, type: :uuid
      # Доходная транзакция (entry), которая является возмещением
      t.references :income_entry, null: false, foreign_key: { to_table: :entries }, type: :uuid
      # Сумма покрытия (может быть частичной — many-to-many с частичными суммами)
      t.decimal :amount, precision: 19, scale: 4, null: false

      t.timestamps
    end

    # Одна пара expense+income — одна запись (нельзя дважды связать одну и ту же пару)
    add_index :reimbursement_links,
              [:expense_entry_id, :income_entry_id],
              unique: true,
              name: "index_reimbursement_links_on_expense_and_income"
  end
end
