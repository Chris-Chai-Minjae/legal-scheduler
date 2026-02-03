# @TASK T0.2 - Calendar model for Google Calendar integration
# @SPEC docs/planning/04-database-design.md#calendars-table

class Calendar < ApplicationRecord
  belongs_to :user
  has_many :schedules, dependent: :destroy

  enum :calendar_type, { lbox: 0, work: 1, personal: 2 }

  validates :user_id, :google_id, :name, presence: true
  validates :google_id, uniqueness: { scope: :user_id }
  validates :calendar_type, presence: true

  # @TASK T2.2 - REQ-CAL-02: Only one calendar per type per user
  validate :unique_calendar_type_per_user, if: :calendar_type_changed?

  private

  def unique_calendar_type_per_user
    existing = user.calendars.where(calendar_type: calendar_type).where.not(id: id).exists?
    if existing
      errors.add(:calendar_type, "already assigned to another calendar")
    end
  end
end
