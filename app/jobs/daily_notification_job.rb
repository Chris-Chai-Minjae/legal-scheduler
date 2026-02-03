# frozen_string_literal: true

# DailyNotificationJob - 매일 오전 7시 (Asia/Seoul) 일정 알림
# 오늘 마감 일정 + 이번 주 예정 일정 요약

class DailyNotificationJob < ApplicationJob
  queue_as :notifications

  # Process all users or specific user
  def perform(user_id = nil)
    users = if user_id
      [User.find(user_id)]
    else
      User.where.not(telegram_chat_id: nil)
    end

    users.each do |user|
      send_daily_notification(user)
    rescue => e
      Rails.logger.error("[DailyNotificationJob] Error for user #{user.id}: #{e.message}")
    end
  end

  private

  def send_daily_notification(user)
    return unless user.telegram_chat_id.present?

    today = Time.current.in_time_zone("Asia/Seoul").to_date
    week_end = today.end_of_week

    # 오늘 마감 일정 (synced 또는 approved 상태)
    schedules_today = user.schedules
      .where(status: [:approved, :synced])
      .where(scheduled_date: today)
      .order(:scheduled_date)

    # 이번 주 남은 일정 (내일부터)
    schedules_upcoming = user.schedules
      .where(status: [:approved, :synced])
      .where(scheduled_date: (today + 1.day)..week_end)
      .order(:scheduled_date)

    # 일정이 없으면 알림 생략 (설정에 따라 변경 가능)
    return if schedules_today.empty? && schedules_upcoming.empty? && user.schedules.pending.empty?

    telegram = TelegramService.new(user)
    telegram.send_daily_notification(schedules_today, schedules_upcoming)

    Rails.logger.info("[DailyNotificationJob] Sent daily notification to user #{user.id}")
  end
end
