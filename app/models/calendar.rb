# @TASK T0.2 - Calendar model for Google Calendar integration
# @SPEC docs/planning/04-database-design.md#calendars-table

class Calendar < ApplicationRecord
  belongs_to :user
  has_many :schedules, dependent: :destroy

  enum :calendar_type, { lbox: 0, work: 1, personal: 2 }

  validates :user_id, :google_id, :name, presence: true
  validates :google_id, uniqueness: { scope: :user_id }
  validates :calendar_type, presence: true
end
