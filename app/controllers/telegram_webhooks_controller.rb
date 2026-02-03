# frozen_string_literal: true

# TelegramWebhooksController - Telegram Bot 콜백 처리
# 승인/거부 버튼 클릭 시 호출됨

class TelegramWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  allow_unauthenticated_access

  # POST /telegram/webhook
  def callback
    data = JSON.parse(request.body.read, symbolize_names: true)

    if data[:callback_query]
      handle_callback_query(data[:callback_query])
    elsif data[:message]
      handle_message(data[:message])
    end

    head :ok
  rescue => e
    Rails.logger.error("[TelegramWebhook] Error: #{e.message}")
    head :ok # Always return 200 to Telegram
  end

  private

  def handle_callback_query(query)
    callback_data = query[:data]
    chat_id = query[:message][:chat][:id]
    message_id = query[:message][:message_id]

    case callback_data
    when /^approve_(\d+)$/
      handle_approve($1.to_i, chat_id, message_id)
    when /^reject_(\d+)$/
      handle_reject($1.to_i, chat_id, message_id)
    when /^reschedule_(\d+)$/
      handle_reschedule($1.to_i, chat_id, message_id)
    when /^set_date_(\d+)_(.+)$/
      handle_set_date($1.to_i, $2, chat_id, message_id)
    end

    # Answer callback query to remove loading state
    answer_callback_query(query[:id])
  end

  def handle_approve(schedule_id, chat_id, message_id)
    schedule = Schedule.find_by(id: schedule_id)
    return unless schedule

    user = User.find_by(telegram_chat_id: chat_id.to_s)
    return unless user && schedule.user == user

    # 이미 처리된 일정은 무시 (중복 클릭 방지)
    return unless schedule.pending?

    schedule.approve!

    # Sync to Google Calendar (즉시 실행)
    CalendarSyncJob.perform_now(schedule.id)

    # Update Telegram message
    update_message(chat_id, message_id, "✅ <b>승인됨:</b> #{schedule.title}\n\n📅 캘린더에 등록되었습니다.")

    # 다음 pending 일정 알림 (순차 알림) - 즉시 실행
    SequentialNotificationJob.perform_now(user.id)
  end

  def handle_reject(schedule_id, chat_id, message_id)
    schedule = Schedule.find_by(id: schedule_id)
    return unless schedule

    user = User.find_by(telegram_chat_id: chat_id.to_s)
    return unless user && schedule.user == user

    # 이미 처리된 일정은 무시 (중복 클릭 방지)
    return unless schedule.pending?

    schedule.reject!

    # Update Telegram message
    update_message(chat_id, message_id, "❌ <b>거부됨:</b> #{schedule.title}\n\n이 일정은 캘린더에 등록되지 않습니다.")

    # 다음 pending 일정 알림 (순차 알림) - 즉시 실행
    SequentialNotificationJob.perform_now(user.id)
  end

  def handle_reschedule(schedule_id, chat_id, message_id)
    schedule = Schedule.find_by(id: schedule_id)
    return unless schedule

    # Send reschedule options
    send_reschedule_options(chat_id, schedule)
  end

  def handle_set_date(schedule_id, new_date_str, chat_id, message_id)
    schedule = Schedule.find_by(id: schedule_id)
    return unless schedule

    user = User.find_by(telegram_chat_id: chat_id.to_s)
    return unless user && schedule.user == user

    # 이미 처리된 일정은 무시
    return unless schedule.pending?

    new_date = Date.parse(new_date_str)

    # 날짜 업데이트 후 승인 처리
    schedule.update!(scheduled_date: new_date)
    schedule.approve!

    # Sync to Google Calendar
    CalendarSyncJob.perform_now(schedule.id)

    # Update Telegram message
    update_message(chat_id, message_id, "✅ <b>날짜 변경 후 승인됨:</b> #{schedule.title}\n\n📅 새 마감일: #{new_date.strftime("%Y년 %m월 %d일 (%a)")}\n캘린더에 등록되었습니다.")

    # 다음 pending 일정 알림
    SequentialNotificationJob.perform_now(user.id)
  end

  def handle_message(message)
    # Handle text messages (future: natural language commands)
    chat_id = message[:chat][:id]
    text = message[:text]

    # Link Telegram account if not linked
    user = User.find_by(telegram_chat_id: chat_id.to_s)

    if user.nil? && text&.start_with?("/start")
      # Could implement linking flow here
      send_telegram_message(chat_id, "안녕하세요! Legal Scheduler AI입니다.\n\n웹사이트에서 먼저 로그인한 후, 설정에서 텔레그램을 연결해주세요.")
    elsif user
      send_telegram_message(chat_id, "👋 안녕하세요! 대기 중인 일정이 #{user.schedules.pending.count}건 있습니다.")
    end
  end

  def answer_callback_query(callback_query_id)
    post_to_telegram("answerCallbackQuery", { callback_query_id: callback_query_id })
  end

  def update_message(chat_id, message_id, text)
    post_to_telegram("editMessageText", {
      chat_id: chat_id,
      message_id: message_id,
      text: text,
      parse_mode: "HTML"
    })
  end

  def send_telegram_message(chat_id, text)
    post_to_telegram("sendMessage", {
      chat_id: chat_id,
      text: text,
      parse_mode: "HTML"
    })
  end

  def send_reschedule_options(chat_id, schedule)
    # Generate date options (next 7 weekdays)
    dates = []
    date = schedule.scheduled_date
    7.times do
      date += 1.day
      date += 1.day while date.saturday? || date.sunday?
      dates << date
    end

    keyboard = {
      inline_keyboard: dates.first(5).map do |d|
        [{ text: d.strftime("%m/%d (%a)"), callback_data: "set_date_#{schedule.id}_#{d.iso8601}" }]
      end
    }

    post_to_telegram("sendMessage", {
      chat_id: chat_id,
      text: "📅 새 날짜를 선택하세요:",
      reply_markup: keyboard.to_json
    })
  end

  def post_to_telegram(method, params)
    bot_token = ENV.fetch("TELEGRAM_BOT_TOKEN")
    uri = URI("https://api.telegram.org/bot#{bot_token}/#{method}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = params.to_json

    http.request(request)
  end
end
