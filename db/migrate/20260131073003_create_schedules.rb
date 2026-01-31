class CreateSchedules < ActiveRecord::Migration[8.1]
  def change
    # @TASK T0.2 - Create schedules table for managing writing deadlines
    # @SPEC docs/planning/04-database-design.md#schedules-table

    create_table :schedules do |t|
      t.references :calendar, null: false, foreign_key: true
      t.string :title, null: false, comment: "Format: [업무] {case_number} {case_name} 서면작성"
      t.string :case_number, comment: "Case number from calendar event"
      t.string :case_name, comment: "Case name from calendar event"
      t.date :original_date, null: false, comment: "Original court date (변론일)"
      t.date :scheduled_date, null: false, comment: "Generated writing deadline (서면작성일)"
      t.integer :status, default: 0, comment: "0: pending, 1: approved, 2: rejected"
      t.string :original_event_id, comment: "Google Calendar event ID of original event (REQ-SCHED-06)"
      t.string :created_event_id, comment: "Google Calendar event ID of created writing deadline"

      t.timestamps
    end

    # Indexes for schedule lookups
    add_index :schedules, [:calendar_id, :original_date]
    add_index :schedules, :original_event_id, unique: true, where: "original_event_id IS NOT NULL"
    add_index :schedules, :created_event_id, unique: true, where: "created_event_id IS NOT NULL"
    add_index :schedules, :status
    add_index :schedules, :scheduled_date
  end
end
