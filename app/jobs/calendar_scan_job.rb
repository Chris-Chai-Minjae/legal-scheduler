# frozen_string_literal: true

# CalendarScanJob - LBOX 캘린더에서 변론 일정 스캔 및 서면작성 일정 생성
# 매주 월요일 오전 7:30 (Asia/Seoul) 실행
# 다음 4주간의 일정을 스캔하고, 이미 처리된 일정은 중복 제외

class CalendarScanJob < ApplicationJob
  queue_as :default

  SCAN_WEEKS = 4  # 4주간 스캔

  # Scan all users or specific user
  def perform(user_id = nil)
    users = user_id ? [User.find(user_id)] : User.joins(:calendars).distinct

    users.each do |user|
      scan_user_calendar(user)
    rescue => e
      Rails.logger.error("[CalendarScanJob] Error scanning user #{user.id}: #{e.message}")
    end
  end

  private

  def scan_user_calendar(user)
    return unless user.google_access_token.present?

    lbox_calendar = user.calendars.find_by(calendar_type: :lbox)
    return unless lbox_calendar

    Rails.logger.info("[CalendarScanJob] Scanning calendar for user #{user.id} (next #{SCAN_WEEKS} weeks)")

    # Get events from LBOX calendar (next 4 weeks)
    service = GoogleCalendarService.new(user)
    events = service.list_events(
      calendar_id: lbox_calendar.google_id,
      time_min: Time.current,
      time_max: SCAN_WEEKS.weeks.from_now,
      max_results: 100
    )

    # Filter events matching keywords
    keywords = user.keywords.active.pluck(:name)
    matching_events = filter_events_by_keywords(events, keywords)

    # 이미 처리된 일정 제외 (original_event_id로 체크)
    existing_event_ids = user.schedules.pluck(:original_event_id).compact
    new_events = matching_events.reject { |e| existing_event_ids.include?(e[:id]) }

    Rails.logger.info("[CalendarScanJob] Found #{matching_events.count} matching events, #{new_events.count} are new")

    # Create schedules using ScheduleCreator
    results = ScheduleCreator.batch_create(user, new_events)

    Rails.logger.info("[CalendarScanJob] Created #{results[:created].count} schedules for user #{user.id}")

    # 스캔 완료 후 첫 번째 pending 일정 알림 발송 (순차 알림 시작)
    if results[:created].any? && user.telegram_chat_id.present?
      SequentialNotificationJob.perform_later(user.id)
    end
  end

  def filter_events_by_keywords(events, keywords)
    return [] if keywords.empty?

    keyword_pattern = Regexp.new(keywords.join("|"), Regexp::IGNORECASE)

    events.select do |event|
      summary = event[:summary] || event["summary"] || ""
      description = event[:description] || event["description"] || ""

      (summary + " " + description).match?(keyword_pattern)
    end
  end
end
