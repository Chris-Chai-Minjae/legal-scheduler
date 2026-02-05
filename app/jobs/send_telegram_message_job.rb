# 텔레그램 메시지 전송을 백그라운드에서 처리하는 Job
# 동기식 HTTP 호출로 인한 응답 지연 방지
class SendTelegramMessageJob < ApplicationJob
  queue_as :default

  # 재시도 설정: 네트워크 오류 시 3회 재시도
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(user_id, text, notify_success: false)
    user = User.find_by(id: user_id)
    return unless user&.telegram_bot_token.present? && user&.telegram_chat_id.present?

    result = send_message(user, text)

    # 성공/실패 로깅 (토큰 정보 제외)
    if result[:ok]
      Rails.logger.info("[SendTelegramMessageJob] Message sent to user #{user_id}")
    else
      Rails.logger.warn("[SendTelegramMessageJob] Failed for user #{user_id}: #{sanitize_error(result[:description])}")
    end

    result
  end

  private

  def send_message(user, text)
    uri = URI("https://api.telegram.org/bot#{user.telegram_bot_token}/sendMessage")

    # 타임아웃 설정 (네트워크 지연 방지)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10  # 연결 타임아웃 10초
    http.read_timeout = 15  # 읽기 타임아웃 15초

    request = Net::HTTP::Post.new(uri)
    request.set_form_data({
      chat_id: user.telegram_chat_id,
      text: text,
      parse_mode: "HTML"
    })

    response = http.request(request)
    JSON.parse(response.body, symbolize_names: true)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    { ok: false, description: "네트워크 타임아웃" }
  rescue JSON::ParserError => e
    { ok: false, description: "응답 파싱 오류" }
  rescue => e
    { ok: false, description: sanitize_error(e.message) }
  end

  # 에러 메시지에서 민감 정보 제거
  def sanitize_error(message)
    return "알 수 없는 오류" if message.blank?

    # bot token이 포함된 URL 마스킹
    message.gsub(/bot[0-9]+:[A-Za-z0-9_-]+/, "bot[FILTERED]")
           .gsub(/token[=:]\s*\S+/i, "token=[FILTERED]")
  end
end
