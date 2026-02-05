class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_if_authenticated
  rate_limit to: 5, within: 1.hour, only: :create, with: -> { redirect_to new_registration_path, alert: "Too many registration attempts. Please try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user
      redirect_to onboarding_path, notice: "Welcome! Please complete your setup."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
  end
end
