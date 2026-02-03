class User < ApplicationRecord
  # @TASK T0.2 & T9.2 - User model with OAuth, Telegram, and schedule management
  # @SPEC docs/planning/04-database-design.md#users-table

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :calendars, dependent: :destroy
  has_many :schedules, through: :calendars
  has_many :keywords, dependent: :destroy
  has_one :settings, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # OAuth and Telegram tokens (encryption disabled for now)
  # TODO: Enable encryption with proper key management
  # encrypts :google_access_token
  # encrypts :google_refresh_token
  # encrypts :telegram_bot_token

  # Validations
  validates :email_address, presence: true, uniqueness: true
  validates :telegram_chat_id, uniqueness: { allow_nil: true }, if: :telegram_chat_id_changed?

  # Password complexity validation (REQ-AUTH-01)
  validates :password, length: { minimum: 8 }, format: {
    with: /\A(?=.*[a-zA-Z])(?=.*\d)/,
    message: "must include at least one letter and one number"
  }, if: :password_digest_changed?

  # Callback to create settings and default keywords when user is created
  after_create :create_default_settings
  after_create :create_default_keywords

  # Onboarding step tracking (T9.2)
  def update_onboarding_step(step)
    # Could store in settings or just rely on actual data state
    # For now, we use data state to determine step
  end

  # Check if onboarding is complete
  def onboarding_complete?
    settings&.onboarding_completed? ||
      (calendars.find_by(calendar_type: :lbox).present? &&
       calendars.find_by(calendar_type: :work).present? &&
       keywords.any?)
  end

  private

  def create_default_settings
    Settings.create!(user: self)
  rescue ActiveRecord::RecordInvalid
    # Settings may fail due to validation, create with defaults
    Settings.create(
      user: self,
      alert_time: "08:00",
      max_per_week: 3,
      lead_days: 14,
      exclude_weekends: true
    )
  end

  def create_default_keywords
    # REQ-SET-01: Default keywords
    %w[변론 검찰조사 재판].each do |keyword|
      keywords.create!(name: keyword, is_active: true)
    rescue ActiveRecord::RecordInvalid
      # Skip if keyword already exists or validation fails
      next
    end
  end
end
