class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    # @TASK T0.2 - Create settings table for user preferences
    # @SPEC docs/planning/04-database-design.md#settings-table

    create_table :settings do |t|
      t.references :user, null: false, foreign_key: true
      t.time :alert_time, default: "08:00", comment: "Daily alert time for notifications"
      t.integer :max_per_week, default: 3, comment: "Maximum writing schedules per week"
      t.integer :lead_days, default: 14, comment: "Days before court date to schedule writing"
      t.boolean :exclude_weekends, default: true, comment: "Exclude weekends from scheduling"

      t.timestamps
    end

    # Unique index to ensure one settings per user
    add_index :settings, :user_id, unique: true
  end
end
