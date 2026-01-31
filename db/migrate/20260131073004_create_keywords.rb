class CreateKeywords < ActiveRecord::Migration[8.1]
  def change
    # @TASK T0.2 - Create keywords table for calendar filtering
    # @SPEC docs/planning/04-database-design.md#keywords-table

    create_table :keywords do |t|
      t.references :user, null: false, foreign_key: true
      t.string :keyword, null: false, comment: "Keyword to filter calendar events"
      t.boolean :is_active, default: true

      t.timestamps
    end

    # Indexes for keyword lookups
    add_index :keywords, [:user_id, :keyword], unique: true
    add_index :keywords, :is_active
  end
end
