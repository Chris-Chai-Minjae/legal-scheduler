# @TASK T9.2 - Settings Controller
# Handles notification and scheduling settings

class SettingsController < ApplicationController
  before_action :require_authentication
  before_action :load_recent_sessions, only: %i[account update_account]
  layout "dashboard"

  # 비밀번호 변경 시도 제한 (브루트포스 방지)
  rate_limit to: 5, within: 1.hour, only: :update_password,
    with: -> { redirect_to account_settings_path, alert: "비밀번호 변경 시도가 너무 많습니다. 1시간 후 다시 시도해주세요." }

  def notifications
    @user = Current.user
    @settings = @user.settings || @user.build_settings
  end

  # 계정 설정 페이지
  def account
    @user = Current.user
  end

  # 프로필 업데이트
  def update_account
    @user = Current.user

    if @user.update(account_params)
      redirect_to account_settings_path, notice: "프로필이 업데이트되었습니다."
    else
      render :account, status: :unprocessable_entity
    end
  end

  # 비밀번호 변경
  def update_password
    @user = Current.user

    unless @user.authenticate(params[:current_password])
      redirect_to account_settings_path, alert: "현재 비밀번호가 일치하지 않습니다."
      return
    end

    if params[:new_password] != params[:new_password_confirmation]
      redirect_to account_settings_path, alert: "새 비밀번호가 일치하지 않습니다."
      return
    end

    if @user.update(password: params[:new_password])
      redirect_to account_settings_path, notice: "비밀번호가 변경되었습니다."
    else
      redirect_to account_settings_path, alert: @user.errors.full_messages.join(", ")
    end
  end

  # 계정 삭제
  def destroy_account
    @user = Current.user

    unless @user.authenticate(params[:password])
      redirect_to account_settings_path, alert: "비밀번호가 일치하지 않습니다."
      return
    end

    @user.destroy
    reset_session
    redirect_to root_path, notice: "계정이 삭제되었습니다."
  end

  def telegram
    @user = Current.user
    @linking_code = generate_linking_code
  end

  def link_telegram
    @user = Current.user
    bot_token = params[:bot_token]
    chat_id = params[:chat_id]

    if bot_token.blank? || chat_id.blank?
      redirect_to telegram_settings_path, alert: "Bot Token과 Chat ID를 모두 입력해주세요."
      return
    end

    @user.update(telegram_bot_token: bot_token, telegram_chat_id: chat_id)
    redirect_to telegram_settings_path, notice: "Telegram이 연결되었습니다!"
  end

  def unlink_telegram
    Current.user.update(telegram_bot_token: nil, telegram_chat_id: nil)
    redirect_to telegram_settings_path, notice: "Telegram 연결이 해제되었습니다."
  end

  def test_telegram
    @user = Current.user

    unless @user.telegram_bot_token.present? && @user.telegram_chat_id.present?
      redirect_to telegram_settings_path, alert: "Telegram이 연결되어 있지 않습니다."
      return
    end

    # 백그라운드에서 메시지 전송 (응답 지연 방지)
    SendTelegramMessageJob.perform_later(
      @user.id,
      "Legal Scheduler AI 테스트 메시지입니다.\n연결이 정상적으로 완료되었습니다! 🎉"
    )

    redirect_to telegram_settings_path, notice: "테스트 메시지를 전송 중입니다. 잠시 후 Telegram을 확인해주세요."
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

  def account_params
    params.require(:user).permit(:name, :email_address)
  end

  def generate_linking_code
    # Generate a unique code for this user
    "LINK-#{Current.user.id}-#{SecureRandom.hex(4).upcase}"
  end

  # 최근 세션 목록 로드 (account 페이지용)
  def load_recent_sessions
    @sessions = Session.where(user_id: Current.user.id).order(created_at: :desc).limit(5)
  end
end
