# @TASK T9.2 - Settings Controller
# Handles notification and scheduling settings

class SettingsController < ApplicationController
  before_action :require_authentication
  layout "dashboard"

  def notifications
    @user = Current.user
    @settings = @user.settings || @user.build_settings
  end

  # 계정 설정 페이지
  def account
    @user = Current.user
    @sessions = Session.where(user_id: @user.id).order(created_at: :desc).limit(5)
  end

  # 프로필 업데이트
  def update_account
    @user = Current.user

    if @user.update(account_params)
      redirect_to account_settings_path, notice: "프로필이 업데이트되었습니다."
    else
      @sessions = Session.where(user_id: @user.id).order(created_at: :desc).limit(5)
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

    # Send test message
    result = send_telegram_message(
      @user.telegram_bot_token,
      @user.telegram_chat_id,
      "Legal Scheduler AI 테스트 메시지입니다.\n연결이 정상적으로 완료되었습니다! 🎉"
    )

    if result[:ok]
      redirect_to telegram_settings_path, notice: "테스트 메시지가 전송되었습니다!"
    else
      redirect_to telegram_settings_path, alert: "메시지 전송 실패: #{result[:description]}"
    end
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

  def send_telegram_message(bot_token, chat_id, text)
    uri = URI("https://api.telegram.org/bot#{bot_token}/sendMessage")
    response = Net::HTTP.post_form(uri, {
      chat_id: chat_id,
      text: text,
      parse_mode: "HTML"
    })
    JSON.parse(response.body, symbolize_names: true)
  rescue => e
    { ok: false, description: e.message }
  end
end
