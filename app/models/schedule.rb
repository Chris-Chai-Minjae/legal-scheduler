# @TASK T0.2 - Schedule model for managing writing deadlines
# @SPEC docs/planning/04-database-design.md#schedules-table

class Schedule < ApplicationRecord
  belongs_to :calendar
  has_one :user, through: :calendar

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :calendar_id, :title, :original_date, :scheduled_date, presence: true
  validates :original_event_id, uniqueness: { allow_nil: true }
  validates :created_event_id, uniqueness: { allow_nil: true }

  scope :pending_approval, -> { where(status: :pending) }
  scope :approved, -> { where(status: :approved) }
  scope :rejected, -> { where(status: :rejected) }
  scope :upcoming, -> { where("scheduled_date >= ?", Date.today).order(:scheduled_date) }
  scope :by_calendar, ->(calendar_id) { where(calendar_id: calendar_id) }
end
