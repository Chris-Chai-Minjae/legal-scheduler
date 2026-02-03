# frozen_string_literal: true

# SyncDeletedEventsJob - Google Calendar에서 삭제된 이벤트를 DB와 동기화
#
# 양방향 동기화:
# - Google Calendar에서 직접 삭제한 이벤트 -> DB에서 cancelled 처리
# - 주기적으로 실행하거나 수동으로 호출 가능
#
# Rails 8 Solid Queue 사용
class SyncDeletedEventsJob < ApplicationJob
  queue_as :calendar

  # 단일 사용자 또는 전체 사용자 동기화
  # @param user_id [Integer, nil] 특정 사용자 ID, nil이면 전체 사용자
  def perform(user_id = nil)
    if user_id
      sync_user(User.find(user_id))
    else
      # 모든 Google 연동 사용자 동기화
      User.where.not(google_access_token: nil).find_each do |user|
        sync_user(user)
      end
    end
  end

  private

  def sync_user(user)
    Rails.logger.info("[SyncDeletedEvents] Starting sync for user #{user.id}")

    result = { checked: 0, cancelled: 0, errors: 0 }

    # original_event_id가 있는 활성 스케줄만 확인
    schedules = user.schedules.with_original_event.not_cancelled

    if schedules.empty?
      Rails.logger.info("[SyncDeletedEvents] No schedules to check for user #{user.id}")
      return result
    end

    service = GoogleCalendarService.new(user)

    # 각 캘린더별로 그룹화하여 처리
    schedules.includes(:calendar).find_each do |schedule|
      result[:checked] += 1

      begin
        calendar_id = schedule.calendar.google_id
        event_exists = service.event_exists?(
          calendar_id: calendar_id,
          event_id: schedule.original_event_id
        )

        unless event_exists
          Rails.logger.info("[SyncDeletedEvents] Event #{schedule.original_event_id} deleted from Calendar, cancelling schedule #{schedule.id}")
          schedule.cancel!
          result[:cancelled] += 1

          # 텔레그램 알림 (선택적)
          notify_cancelled(schedule)
        end
      rescue => e
        Rails.logger.error("[SyncDeletedEvents] Error checking schedule #{schedule.id}: #{e.message}")
        result[:errors] += 1
      end
    end

    Rails.logger.info("[SyncDeletedEvents] Sync complete for user #{user.id}: checked=#{result[:checked]}, cancelled=#{result[:cancelled]}, errors=#{result[:errors]}")
    result
  end

  def notify_cancelled(schedule)
    # 텔레그램 알림 (user에게 telegram_chat_id가 있는 경우)
    user = schedule.user
    return unless user.telegram_chat_id.present?

    message = <<~MSG
      📅 일정이 취소되었습니다

      제목: #{schedule.title}
      예정일: #{schedule.scheduled_date.strftime("%Y년 %m월 %d일")}
      사유: Google Calendar에서 원본 변론 일정이 삭제됨
    MSG

    TelegramService.new.send_message(
      chat_id: user.telegram_chat_id,
      text: message
    )
  rescue => e
    Rails.logger.error("[SyncDeletedEvents] Failed to send telegram notification: #{e.message}")
  end
end
