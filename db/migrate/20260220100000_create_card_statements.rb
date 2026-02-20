class CreateCardStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :card_statements do |t|
      t.references :user, null: false, foreign_key: true
      t.string :filename, null: false
      t.integer :status, default: 0, null: false
      t.integer :total_transactions, default: 0
      t.integer :classified_transactions, default: 0
      t.jsonb :card_summary, default: {}
      t.text :error_message

      t.timestamps
    end
  end
end
