# frozen_string_literal: true

# SequentialNotificationJob - pending 일정을 하나씩 순차적으로 알림
# 스캔 완료 후 또는 승인/거절 처리 후 다음 일정 알림

class SequentialNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(user_id)
    user = User.find(user_id)
    return unless user.telegram_chat_id.present?

    # 가장 가까운 pending 일정 조회 (scheduled_date 기준 오름차순)
    next_schedule = user.schedules
      .pending
      .order(:scheduled_date)
      .first

    return unless next_schedule

    # 텔레그램으로 승인 요청 알림
    telegram = TelegramService.new(user)

    # 남은 pending 일정 수
    remaining_count = user.schedules.pending.count

    telegram.send_approval_request_with_count(next_schedule, remaining_count)

    Rails.logger.info("[SequentialNotificationJob] Sent notification for schedule #{next_schedule.id} to user #{user.id} (#{remaining_count} remaining)")
  end
end
