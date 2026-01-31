# @TASK T0.2 - Settings model for user preferences
# @SPEC docs/planning/04-database-design.md#settings-table

class Settings < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true
  validates :alert_time, :max_per_week, :lead_days, presence: true
  validates :max_per_week, :lead_days, numericality: { only_integer: true, greater_than: 0 }
  validates :exclude_weekends, inclusion: { in: [true, false] }

  # Onboarding is considered complete if user has at least one calendar connected
  def onboarding_completed?
    user.calendars.exists?
  end
end
