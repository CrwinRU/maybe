class CreateAccountCashes < ActiveRecord::Migration[7.2]
  def change
    create_table :cashes, id: :uuid do |t|
      t.timestamps
    end
  end
end
