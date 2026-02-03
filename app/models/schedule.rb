# @TASK T0.2 - Schedule model for managing writing deadlines
# @TASK T5.2 - Enhanced with business logic for schedule creation
# @SPEC docs/planning/04-database-design.md#schedules-table
# @SPEC .sdd/specs/schedule/spec.md#REQ-SCHED-01, REQ-SCHED-02, REQ-SCHED-06

class Schedule < ApplicationRecord
  belongs_to :calendar
  has_one :user, through: :calendar

  enum :status, { pending: 0, approved: 1, rejected: 2, synced: 3, cancelled: 4 }

  validates :calendar_id, :title, :original_date, :scheduled_date, presence: true
  validates :original_event_id, uniqueness: { allow_nil: true }
  validates :created_event_id, uniqueness: { allow_nil: true }

  # REQ-SCHED-01: Validate scheduled_date is before original_date
  validate :scheduled_date_before_original_date

  # Scopes for querying schedules
  scope :pending_approval, -> { where(status: :pending) }
  scope :approved, -> { where(status: :approved) }
  scope :rejected, -> { where(status: :rejected) }
  scope :upcoming, -> { where("scheduled_date >= ?", Date.today).order(:scheduled_date) }
  scope :by_calendar, ->(calendar_id) { where(calendar_id: calendar_id) }

  # T5.2: Additional scopes for business logic
  scope :for_week, ->(date) {
    week_start = date.beginning_of_week
    week_end = date.end_of_week
    where(scheduled_date: week_start..week_end)
  }
  scope :active, -> { where(status: [:pending, :approved]) }
  scope :by_original_event, ->(event_id) { where(original_event_id: event_id) }
  scope :cancelled, -> { where(status: :cancelled) }
  scope :with_original_event, -> { where.not(original_event_id: nil) }
  scope :not_cancelled, -> { where.not(status: :cancelled) }

  # REQ-SCHED-04: Approve a schedule and optionally set the created event ID
  def approve!(created_event_id: nil)
    update!(status: :approved, created_event_id: created_event_id)
  end

  # REQ-SCHED-05: Reject a schedule
  def reject!
    update!(status: :rejected)
  end

  # Mark as synced when calendar event is created
  def sync!(created_event_id:)
    update!(
      status: :synced,
      created_event_id: created_event_id,
      synced_at: Time.current
    )
  end

  # Cancel schedule (when original event is deleted from Google Calendar)
  def cancel!
    update!(status: :cancelled, cancelled_at: Time.current)
  end

  # Check if schedule needs to be synced to calendar
  def needs_sync?
    approved? && created_event_id.blank?
  end

  # Check if schedule falls on a weekend
  def on_weekend?
    scheduled_date.saturday? || scheduled_date.sunday?
  end

  # Get the week number for this schedule
  def week_number
    scheduled_date.cweek
  end

  # Days until the scheduled date
  def days_until
    (scheduled_date - Date.today).to_i
  end

  # Days remaining until original court date
  def days_until_court
    (original_date - Date.today).to_i
  end

  # Human-readable status in Korean
  def status_text
    case status
    when "pending" then "대기중"
    when "approved" then "승인됨"
    when "rejected" then "거부됨"
    when "synced" then "캘린더 등록됨"
    when "cancelled" then "취소됨"
    else status
    end
  end

  # REQ-SCHED-02: Generate formatted title
  def self.format_title(case_number: nil, case_name: nil)
    parts = ["[업무]"]
    parts << case_number if case_number.present?
    parts << case_name if case_name.present?
    parts << "서면작성"
    parts.join(" ")
  end

  private

  def scheduled_date_before_original_date
    return unless scheduled_date.present? && original_date.present?

    if scheduled_date >= original_date
      errors.add(:scheduled_date, "must be before the original court date (변론일)")
    end
  end
end
