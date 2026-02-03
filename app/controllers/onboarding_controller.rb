# @TASK T9.2 - Onboarding Controller
# Multi-step onboarding flow for new users

class OnboardingController < ApplicationController
  before_action :require_authentication
  layout "onboarding"

  def index
    @step = (params[:step] || current_onboarding_step).to_i
    @user = Current.user

    case @step
    when 1
      # Google OAuth connection
    when 2
      # Telegram bot connection
    when 3
      # Calendar selection
      @calendars = fetch_calendars
    when 4
      # Keywords setup
      @keywords = @user.keywords.order(:name)
    end
  end

  def update_step
    step = params[:step].to_i

    case step
    when 1
      # Handle Google OAuth redirect
      redirect_to google_oauth_path, allow_other_host: true
    when 2
      # Telegram connection
      # Mark step as completed and proceed
      complete_step(2)
      redirect_to onboarding_path(step: 3)
    when 3
      # Validate calendar selection
      if calendars_configured?
        complete_step(3)
        redirect_to onboarding_path(step: 4)
      else
        flash[:alert] = "LBOX 캘린더와 업무 캘린더를 선택해주세요."
        redirect_to onboarding_path(step: 3)
      end
    when 4
      # Keywords setup
      if Current.user.keywords.any?
        complete_step(4)
        complete_onboarding
        redirect_to dashboard_path, notice: "온보딩이 완료되었습니다!"
      else
        flash[:alert] = "최소 1개 이상의 키워드를 등록해주세요."
        redirect_to onboarding_path(step: 4)
      end
    end
  end

  private

  def current_onboarding_step
    settings = Current.user.settings
    return 1 unless settings

    if !settings.google_connected?
      1
    elsif !settings.telegram_connected?
      2
    elsif !calendars_configured?
      3
    elsif Current.user.keywords.empty?
      4
    else
      5 # Completed
    end
  end

  def complete_step(step)
    # Mark step as completed in user settings
    Current.user.update_onboarding_step(step)
  end

  def complete_onboarding
    settings = Current.user.settings || Current.user.create_settings
    settings.update(onboarding_completed_at: Time.current)
  end

  def calendars_configured?
    lbox = Current.user.calendars.find_by(calendar_type: :lbox)
    work = Current.user.calendars.find_by(calendar_type: :work)
    lbox.present? && work.present?
  end

  def fetch_calendars
    return [] unless Current.user.settings&.google_connected?

    begin
      service = GoogleCalendarService.new(Current.user)
      service.list_calendars
    rescue => e
      Rails.logger.error("Failed to fetch calendars: #{e.message}")
      []
    end
  end
end
