class CreateCalendars < ActiveRecord::Migration[8.1]
  def change
    # @TASK T0.2 - Create calendars table for Google Calendar integration
    # @SPEC docs/planning/04-database-design.md#calendars-table

    create_table :calendars do |t|
      t.references :user, null: false, foreign_key: true
      t.string :google_id, null: false, comment: "Google Calendar ID"
      t.integer :calendar_type, default: 0, comment: "0: lbox, 1: work, 2: personal"
      t.string :name
      t.string :color

      t.timestamps
    end

    # Indexes for calendar lookups
    add_index :calendars, [:user_id, :google_id], unique: true
    add_index :calendars, :calendar_type
  end
end
