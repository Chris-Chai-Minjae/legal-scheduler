# frozen_string_literal: true

# CalendarSyncJob - 승인된 일정을 Google Calendar에 등록
# Schedule이 approved 상태가 되면 실행

class CalendarSyncJob < ApplicationJob
  queue_as :calendar

  # Sync single schedule or all approved schedules
  def perform(schedule_id = nil)
    if schedule_id
      sync_schedule(Schedule.find(schedule_id))
    else
      # Sync all approved schedules that haven't been synced yet
      Schedule.approved.where(created_event_id: nil).find_each do |schedule|
        sync_schedule(schedule)
      end
    end
  end

  private

  def sync_schedule(schedule)
    return unless schedule.approved? || schedule.needs_sync?

    user = schedule.user
    work_calendar = user.calendars.find_by(calendar_type: :work)

    unless work_calendar
      Rails.logger.error("[CalendarSyncJob] No work calendar for user #{user.id}")
      return
    end

    Rails.logger.info("[CalendarSyncJob] Syncing schedule #{schedule.id} to calendar")

    service = GoogleCalendarService.new(user)
    event = service.create_event(
      calendar_id: work_calendar.google_id,
      summary: schedule.title,
      description: build_description(schedule),
      start_date: schedule.scheduled_date,
      end_date: schedule.scheduled_date
    )

    if event && event[:id]
      schedule.sync!(created_event_id: event[:id])
      TelegramNotificationJob.perform_later(schedule.id, :approved)
      Rails.logger.info("[CalendarSyncJob] Successfully synced schedule #{schedule.id}")
    else
      Rails.logger.error("[CalendarSyncJob] Failed to create calendar event for schedule #{schedule.id}")
    end
  rescue => e
    Rails.logger.error("[CalendarSyncJob] Error syncing schedule #{schedule.id}: #{e.message}")
  end

  def build_description(schedule)
    <<~DESC
      📋 서면작성 일정

      원본 변론일: #{schedule.original_date.strftime("%Y년 %m월 %d일")}
      사건번호: #{schedule.case_number || "N/A"}
      사건명: #{schedule.case_name || "N/A"}

      --
      Legal Scheduler AI에 의해 자동 생성됨
    DESC
  end
end
