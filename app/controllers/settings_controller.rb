# @TASK T9.2 - Settings Controller
# Handles notification and scheduling settings

class SettingsController < ApplicationController
  before_action :require_authentication
  layout "dashboard"

  def notifications
    @user = Current.user
    @settings = @user.settings || @user.build_settings
  end

  def telegram
    @user = Current.user
    @linking_code = generate_linking_code
  end

  def link_telegram
    @user = Current.user
    chat_id = params[:chat_id]

    if chat_id.present?
      @user.update(telegram_chat_id: chat_id)
      redirect_to telegram_settings_path, notice: "Telegram이 연결되었습니다!"
    else
      redirect_to telegram_settings_path, alert: "Chat ID를 입력해주세요."
    end
  end

  def unlink_telegram
    Current.user.update(telegram_chat_id: nil)
    redirect_to telegram_settings_path, notice: "Telegram 연결이 해제되었습니다."
  end

  def update_notifications
    @user = Current.user
    @settings = @user.settings || @user.build_settings

    if @settings.update(settings_params)
      redirect_to notifications_settings_path, notice: "알림 설정이 저장되었습니다!"
    else
      render :notifications, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:settings).permit(
      :morning_notification_time,
      :weekly_schedule_limit,
      :lead_days,
      :exclude_weekends
    )
  end

  def generate_linking_code
    # Generate a unique code for this user
    "LINK-#{Current.user.id}-#{SecureRandom.hex(4).upcase}"
  end
end
