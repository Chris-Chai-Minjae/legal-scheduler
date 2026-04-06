class AddForeignAmountToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :foreign_amount, :decimal, precision: 12, scale: 2
    add_column :expenses, :foreign_currency, :string
  end
end
