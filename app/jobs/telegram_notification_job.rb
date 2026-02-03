# frozen_string_literal: true

# TelegramNotificationJob - 텔레그램으로 알림 발송
# 새 일정 승인 요청, 승인/거부 확인 등

class TelegramNotificationJob < ApplicationJob
  queue_as :notifications

  # notification_type: :new_schedule, :approved, :rejected, :reminder
  def perform(schedule_id, notification_type = :new_schedule)
    schedule = Schedule.find(schedule_id)
    user = schedule.user

    return unless user.telegram_chat_id.present?

    telegram = TelegramService.new(user)

    case notification_type.to_sym
    when :new_schedule
      telegram.send_approval_request(schedule)
    when :approved
      telegram.send_approval_confirmation(schedule)
    when :rejected
      telegram.send_rejection_confirmation(schedule)
    when :reminder
      send_reminder(telegram, schedule)
    end
  rescue => e
    Rails.logger.error("[TelegramNotificationJob] Error: #{e.message}")
  end

  private

  def send_reminder(telegram, schedule)
    days_left = schedule.days_until

    text = if days_left <= 0
      "⚠️ <b>마감일이 지났습니다!</b>\n\n#{schedule.title}"
    elsif days_left == 1
      "⏰ <b>내일 마감입니다!</b>\n\n#{schedule.title}"
    elsif days_left <= 3
      "📢 <b>#{days_left}일 후 마감</b>\n\n#{schedule.title}"
    else
      "📅 #{schedule.title}\n마감까지 #{days_left}일 남았습니다."
    end

    telegram.send_message(text)
  end
end
