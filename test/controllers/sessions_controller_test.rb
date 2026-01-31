require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to dashboard_path
    assert cookies[:session_id]
  end

  test "redirect to onboarding if not completed" do
    user = User.create!(
      name: "New User",
      email_address: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post session_path, params: { email_address: user.email_address, password: "password123" }

    assert_redirected_to onboarding_path
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
