class CreateExpenseReportItems < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_report_items do |t|
      t.references :expense_report, null: false, foreign_key: true
      t.references :expense, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end

    add_index :expense_report_items, [:expense_report_id, :position], unique: true
  end
end
