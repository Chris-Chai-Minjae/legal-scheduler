require "test_helper"

class UserTest < ActiveSupport::TestCase
  # @TASK T1.1 - User model validation tests
  # @SPEC REQ-AUTH-01: Password validation (minimum 8 characters with alphanumeric)

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "requires unique email_address" do
    User.create!(
      name: "User 1",
      email_address: "duplicate@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    duplicate_user = User.new(
      name: "User 2",
      email_address: "duplicate@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email_address], "has already been taken"
  end

  test "requires password minimum 8 characters" do
    user = User.new(
      name: "Test User",
      email_address: "test@example.com",
      password: "pass123",
      password_confirmation: "pass123"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "requires password to include letter and number" do
    user = User.new(
      name: "Test User",
      email_address: "test@example.com",
      password: "password",
      password_confirmation: "password"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], "must include at least one letter and one number"
  end

  test "accepts valid password with letters and numbers" do
    user = User.new(
      name: "Test User",
      email_address: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert user.valid?
  end

  test "creates default settings after user creation" do
    user = User.create!(
      name: "Test User",
      email_address: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not_nil user.settings
    assert_equal 3, user.settings.max_per_week
    assert_equal 14, user.settings.lead_days
    assert user.settings.exclude_weekends
  end
end
