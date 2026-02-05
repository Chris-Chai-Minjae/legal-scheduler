# frozen_string_literal: true

# Telegram Bot Service for sending notifications
# Uses Telegram Bot API directly (no gem dependency)

class TelegramService
  BASE_URL = "https://api.telegram.org/bot"

  attr_reader :user

  def initialize(user)
    @user = user
    # 사용자별 봇 토큰 우선, 없으면 시스템 환경변수 사용
    @bot_token = user.telegram_bot_token.presence || ENV["TELEGRAM_BOT_TOKEN"]
  end

  # 봇 토큰이 설정되어 있는지 확인
  def configured?
    @bot_token.present? && user.telegram_chat_id.present?
  end

  # Send a text message to user's Telegram
  def send_message(text, parse_mode: "HTML", reply_markup: nil)
    return false unless configured?

    params = {
      chat_id: user.telegram_chat_id,
      text: text,
      parse_mode: parse_mode
    }

    params[:reply_markup] = reply_markup.to_json if reply_markup

    response = post("sendMessage", params)
    response["ok"]
  rescue => e
    Rails.logger.error("Telegram API error: #{e.message}")
    false
  end

  # Send schedule approval request with inline keyboard
  def send_approval_request(schedule)
    send_approval_request_with_count(schedule, 1)
  end

  # Send schedule approval request with remaining count (순차 알림용)
  def send_approval_request_with_count(schedule, remaining_count)
    count_text = remaining_count > 1 ? " (#{remaining_count}건 중 1번째)" : ""

    text = <<~MSG
      📋 <b>서면작성 일정 승인 요청</b>#{count_text}

      <b>제목:</b> #{schedule.title}
      <b>작성 마감일:</b> #{schedule.scheduled_date.strftime("%Y년 %m월 %d일 (%a)")}
      <b>변론일:</b> #{schedule.original_date.strftime("%Y년 %m월 %d일 (%a)")}
      <b>남은 일수:</b> #{schedule.days_until}일

      ✅ 승인 → 업무 캘린더에 등록
      ❌ 거부 → 등록하지 않음
    MSG

    keyboard = {
      inline_keyboard: [
        [
          { text: "✅ 승인", callback_data: "approve_#{schedule.id}" },
          { text: "❌ 거부", callback_data: "reject_#{schedule.id}" }
        ],
        [
          { text: "📅 날짜 변경", callback_data: "reschedule_#{schedule.id}" }
        ]
      ]
    }

    send_message(text, reply_markup: keyboard)
  end

  # Send daily morning notification
  def send_daily_notification(schedules_today, schedules_upcoming)
    today = Time.current.in_time_zone("Asia/Seoul").to_date

    text = <<~MSG
      🌅 <b>#{today.strftime("%Y년 %m월 %d일")} 오늘의 일정</b>

    MSG

    if schedules_today.any?
      text += "<b>📝 오늘 마감 서면:</b>\n"
      schedules_today.each do |s|
        text += "  • #{s.title}\n"
      end
      text += "\n"
    else
      text += "오늘 마감 서면이 없습니다.\n\n"
    end

    if schedules_upcoming.any?
      text += "<b>📅 이번 주 예정:</b>\n"
      schedules_upcoming.first(5).each do |s|
        text += "  • #{s.scheduled_date.strftime("%m/%d")} #{s.title}\n"
      end
    end

    # Add pending approval count
    pending_count = user.schedules.pending.count
    if pending_count > 0
      text += "\n⏳ <b>승인 대기 중:</b> #{pending_count}건"
    end

    send_message(text)
  end

  # Send confirmation after approval
  def send_approval_confirmation(schedule)
    text = <<~MSG
      ✅ <b>일정이 승인되었습니다</b>

      #{schedule.title}
      📅 #{schedule.scheduled_date.strftime("%Y년 %m월 %d일")}

      업무 캘린더에 등록되었습니다.
    MSG

    send_message(text)
  end

  # Send confirmation after rejection
  def send_rejection_confirmation(schedule)
    text = <<~MSG
      ❌ <b>일정이 거부되었습니다</b>

      #{schedule.title}

      이 일정은 캘린더에 등록되지 않습니다.
    MSG

    send_message(text)
  end

  private

  def post(method, params)
    uri = URI("#{BASE_URL}#{@bot_token}/#{method}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    # 타임아웃 설정 (네트워크 지연으로 인한 응답 지연 방지)
    http.open_timeout = 10  # 연결 타임아웃 10초
    http.read_timeout = 15  # 읽기 타임아웃 15초

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = params.to_json

    response = http.request(request)
    JSON.parse(response.body)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[TelegramService] Timeout for user #{user.id}")
    { "ok" => false, "description" => "네트워크 타임아웃" }
  rescue JSON::ParserError => e
    Rails.logger.error("[TelegramService] JSON parse error for user #{user.id}")
    { "ok" => false, "description" => "응답 파싱 오류" }
  end
end
