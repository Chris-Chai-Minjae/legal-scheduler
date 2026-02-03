# Add synced status to schedules
# synced = schedule has been created in Google Calendar
class AddSyncedStatusToSchedules < ActiveRecord::Migration[8.0]
  def change
    # Status enum: pending: 0, approved: 1, rejected: 2, synced: 3
    # No schema change needed - enum values are stored as integers
    # Just documenting the new value here

    # Add synced_at timestamp to track when calendar event was created
    add_column :schedules, :synced_at, :datetime, null: true
  end
end
