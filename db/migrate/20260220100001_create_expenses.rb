class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :card_statement, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :transaction_date, null: false
      t.string :merchant
      t.integer :amount, null: false
      t.string :currency, default: "KRW"
      t.string :card_name, null: false
      t.string :category
      t.string :memo
      t.string :description
      t.integer :vat
      t.boolean :cancelled, default: false
      t.integer :classification_status, default: 0, null: false

      t.timestamps
    end

    add_index :expenses, :transaction_date
    add_index :expenses, :category
    add_index :expenses, :card_name
  end
end
