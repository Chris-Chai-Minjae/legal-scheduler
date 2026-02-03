# @TASK T0.2 & T9.2 - Settings model for user preferences
# @SPEC docs/planning/04-database-design.md#settings-table

class Settings < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true
  validates :alert_time, :max_per_week, :lead_days, presence: true
  validates :max_per_week, :lead_days, numericality: { only_integer: true, greater_than: 0 }
  validates :exclude_weekends, inclusion: { in: [true, false] }

  # Alias methods for UI compatibility (T9.2)
  alias_attribute :morning_notification_time, :alert_time
  alias_attribute :weekly_schedule_limit, :max_per_week

  # Check if Google is connected
  def google_connected?
    user.google_access_token.present?
  end

  # Check if Telegram is connected
  def telegram_connected?
    user.telegram_chat_id.present?
  end

  # Onboarding is considered complete if user has at least one calendar connected
  def onboarding_completed?
    (respond_to?(:onboarding_completed_at) && onboarding_completed_at.present?) || user.calendars.exists?
  end
end
