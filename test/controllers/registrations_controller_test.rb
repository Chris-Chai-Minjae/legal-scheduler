require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  # @TASK T1.1 - Registration controller tests
  # @SPEC REQ-AUTH-01: User registration with email and password

  test "should get new" do
    get new_registration_url
    assert_response :success
    assert_select "h1", "Legal Scheduler AI"
  end

  test "should create user with valid params" do
    assert_difference("User.count", 1) do
      post registrations_url, params: {
        user: {
          name: "Test User",
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to onboarding_path
    follow_redirect!
    assert_equal "Welcome! Please complete your setup.", flash[:notice]
  end

  test "should not create user with invalid email" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          name: "Test User",
          email_address: "",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with short password" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          name: "Test User",
          email_address: "test@example.com",
          password: "pass123",
          password_confirmation: "pass123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with password without alphanumeric" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          name: "Test User",
          email_address: "test@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with duplicate email" do
    User.create!(
      name: "Existing User",
      email_address: "existing@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          name: "New User",
          email_address: "existing@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with mismatched password confirmation" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          name: "Test User",
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "different123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should start session after successful registration" do
    post registrations_url, params: {
      user: {
        name: "Test User",
        email_address: "test@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_not_nil cookies[:session_id]
  end
end
