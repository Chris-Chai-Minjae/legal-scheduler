class User < ApplicationRecord
  # @TASK T0.2 - User model with OAuth, Telegram, and schedule management
  # @SPEC docs/planning/04-database-design.md#users-table

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :calendars, dependent: :destroy
  has_many :schedules, through: :calendars
  has_many :keywords, dependent: :destroy
  has_one :settings, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Encrypt sensitive OAuth and Telegram tokens
  encrypts :google_access_token
  encrypts :google_refresh_token
  encrypts :telegram_bot_token

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

  private

  def create_default_settings
    Settings.create!(user: self)
  end

  def create_default_keywords
    # REQ-SET-01: Default keywords
    %w[변론 검찰조사 재판].each do |keyword|
      keywords.create!(keyword: keyword, is_active: true)
    end
  end
end
