# frozen_string_literal: true

# @TASK T2.1 & T9.2 - Calendars Controller for calendar list management
# @SPEC REQ-CAL-01: Retrieve and refresh calendar list
# @SPEC REQ-CAL-02: Designate calendars as lbox/work/personal

class CalendarsController < ApplicationController
  before_action :resume_session
  before_action :check_google_auth, except: [:index]
  layout "dashboard"

  # GET /calendars
  # Display user's Google Calendar list with settings page style
  def index
    @calendars = fetch_calendars
    @lbox_calendar = Current.user.calendars.find_by(calendar_type: :lbox)
    @work_calendar = Current.user.calendars.find_by(calendar_type: :work)
    @personal_calendar = Current.user.calendars.find_by(calendar_type: :personal)
    @last_sync = nil  # TODO: Add last_calendar_sync column to settings table
  rescue StandardError => e
    flash.now[:alert] = "캘린더를 불러오는데 실패했습니다: #{e.message}"
    @calendars = []
  end

  # POST /calendars/refresh
  # Force refresh calendar list from Google API
  def refresh
    fetch_calendars(force_refresh: true)
    redirect_to calendars_path, notice: "캘린더가 새로고침되었습니다."
  rescue StandardError => e
    redirect_to calendars_path, alert: "새로고침 실패: #{e.message}"
  end

  # PATCH /calendars/:google_id
  # Update calendar type assignment
  def update
    selected_google_id = params[:id]
    new_type = params[:calendar_type]

    # Fetch calendar info from Google API
    service = GoogleCalendarService.new(Current.user)
    all_calendars = service.list_calendars
    selected_cal = all_calendars.find { |cal| cal[:id] == selected_google_id }

    unless selected_cal
      flash[:alert] = "선택한 캘린더를 찾을 수 없습니다"
      redirect_back fallback_location: calendars_path and return
    end

    # Clear existing assignment for this type
    Current.user.calendars.where(calendar_type: new_type).update_all(calendar_type: nil)

    # Find or create calendar and assign type
    calendar = Current.user.calendars.find_or_initialize_by(google_id: selected_google_id)
    calendar.assign_attributes(
      name: selected_cal[:summary],
      color: selected_cal[:background_color],
      calendar_type: new_type
    )

    if calendar.save
      respond_to do |format|
        format.html { redirect_back fallback_location: calendars_path, notice: "캘린더가 업데이트되었습니다." }
        format.turbo_stream do
          @calendars = all_calendars
          @lbox_calendar = Current.user.calendars.find_by(calendar_type: :lbox)
          @work_calendar = Current.user.calendars.find_by(calendar_type: :work)
          @personal_calendar = Current.user.calendars.find_by(calendar_type: :personal)
          render turbo_stream: turbo_stream.replace(
            "calendars-list",
            partial: "calendars/settings_list",
            locals: {
              calendars: @calendars,
              lbox_calendar: @lbox_calendar,
              work_calendar: @work_calendar,
              personal_calendar: @personal_calendar
            }
          )
        end
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: calendars_path, alert: "업데이트 실패: #{calendar.errors.full_messages.join(', ')}" }
        format.turbo_stream
      end
    end
  rescue StandardError => e
    redirect_back fallback_location: calendars_path, alert: "오류: #{e.message}"
  end

  # PATCH /onboarding/calendars
  # Update calendars from onboarding flow
  def update_from_onboarding
    service = GoogleCalendarService.new(Current.user)
    all_calendars = service.list_calendars

    errors = []

    # Update LBOX calendar
    if params[:lbox_calendar_id].present?
      update_calendar_type(params[:lbox_calendar_id], :lbox, all_calendars) || errors << "LBOX"
    end

    # Update Work calendar
    if params[:work_calendar_id].present?
      update_calendar_type(params[:work_calendar_id], :work, all_calendars) || errors << "업무"
    end

    # Update Personal calendar (optional)
    if params[:personal_calendar_id].present?
      update_calendar_type(params[:personal_calendar_id], :personal, all_calendars)
    end

    if errors.empty?
      redirect_to onboarding_path(step: 4), notice: "캘린더가 설정되었습니다."
    else
      redirect_to onboarding_path(step: 3), alert: "#{errors.join(', ')} 캘린더 설정에 실패했습니다."
    end
  rescue StandardError => e
    redirect_to onboarding_path(step: 3), alert: "오류: #{e.message}"
  end

  private

  def update_calendar_type(google_id, calendar_type, all_calendars)
    selected_cal = all_calendars.find { |cal| cal[:id] == google_id }
    return false unless selected_cal

    # Clear existing assignment for this type
    Current.user.calendars.where(calendar_type: calendar_type).update_all(calendar_type: nil)

    # Find or create calendar and assign type
    calendar = Current.user.calendars.find_or_initialize_by(google_id: google_id)
    calendar.assign_attributes(
      name: selected_cal[:summary],
      color: selected_cal[:background_color],
      calendar_type: calendar_type
    )
    calendar.save
  end

  def fetch_calendars(force_refresh: false)
    return [] unless Current.user.google_access_token.present?

    service = GoogleCalendarService.new(Current.user)
    service.list_calendars(force_refresh: force_refresh)
  rescue StandardError
    []
  end

  def check_google_auth
    unless Current.user.google_access_token.present?
      redirect_to onboarding_path, alert: "먼저 Google 캘린더를 연결해주세요."
    end
  end
end
