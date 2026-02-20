class CreateExpenseReports < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :card_statement, foreign_key: true
      t.string :title, null: false
      t.integer :status, default: 0, null: false
      t.integer :expense_count, default: 0
      t.integer :total_amount, default: 0
      t.text :error_message

      t.timestamps
    end
  end
end
