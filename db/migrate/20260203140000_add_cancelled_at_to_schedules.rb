# frozen_string_literal: true

class AddCancelledAtToSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :schedules, :cancelled_at, :datetime
    add_index :schedules, :cancelled_at
  end
end
