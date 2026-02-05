class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  before_action :redirect_if_authenticated, only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url(user)
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  private

  def after_authentication_url(user)
    # Check if onboarding is completed
    if user.settings&.onboarding_completed?
      session.delete(:return_to_after_authenticating) || dashboard_path
    else
      onboarding_path
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
