class ChangeEntriesDateToDatetime < ActiveRecord::Migration[7.2]
  def up
    # Удаляем индексы по колонке date перед изменением типа
    remove_index :entries, column: [:account_id, :date], name: "index_entries_on_account_id_and_date"
    remove_index :entries, column: :date, name: "index_entries_on_date"

    # Меняем тип date -> timestamp (PostgreSQL кастует date в timestamp at midnight автоматически)
    change_column :entries, :date, :datetime, using: "date::timestamp"

    # Пересоздаём индексы под новый тип
    add_index :entries, [:account_id, :date], name: "index_entries_on_account_id_and_date"
    add_index :entries, :date, name: "index_entries_on_date"
  end

  def down
    remove_index :entries, column: [:account_id, :date], name: "index_entries_on_account_id_and_date"
    remove_index :entries, column: :date, name: "index_entries_on_date"

    # При откате обрезаем время — усечение до даты
    change_column :entries, :date, :date, using: "date::date"

    add_index :entries, [:account_id, :date], name: "index_entries_on_account_id_and_date"
    add_index :entries, :date, name: "index_entries_on_date"
  end
end
