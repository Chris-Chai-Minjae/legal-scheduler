# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

class ExpenseClassifierService
  MAX_RETRIES = 3
  RETRY_DELAY = 1
  TIMEOUT = 30

  CATEGORIES = %w[출장비 소모품구입비 임금 잡비 보험료 복리후생비 관리비 임차료 통신비].freeze

  SYSTEM_PROMPT = <<~PROMPT
    당신은 회계 분류 전문가입니다. 아래 거래를 반드시 9개 카테고리 중 하나로 분류하고, 짧은 한국어 메모를 생성하세요.

    **필수 규칙:**
    1. 반드시 JSON 형식으로만 응답: {"category":"<분류>","memo":"<메모>"}
    2. category는 반드시 다음 중 하나: 출장비, 소모품구입비, 임금, 잡비, 보험료, 복리후생비, 관리비, 임차료, 통신비
    3. memo는 2~6단어 한국어 명사구 (예: "직원 식대", "사무실 청소용품")
    4. 불확실하면 가장 가까운 카테고리 선택 (절대 실패하지 말 것)
    5. 다른 설명이나 텍스트 추가 금지

    **분류 가이드:**
    - 출장비: 교통비, 숙박, 식대(출장 시)
    - 소모품구입비: 사무용품, 청소용품, 소모성 물품
    - 임금: 급여, 상여금, 수당
    - 잡비: 분류 불가능한 기타 지출
    - 보험료: 4대보험, 손해보험
    - 복리후생비: 직원 식사, 회식, 경조사
    - 관리비: 건물 관리비, 청소비, 경비비
    - 임차료: 사무실/주거지 임대료, 주차비
    - 통신비: 인터넷, 전화, 우편
  PROMPT

  FALLBACK = { category: "잡비", memo: "기타지출" }.freeze

  def self.classify(merchant:, amount:, card_name:)
    new.classify(merchant: merchant, amount: amount, card_name: card_name)
  end

  def classify(merchant:, amount:, card_name:)
    return FALLBACK.dup if api_key.blank?

    user_payload = {
      merchant: merchant.to_s,
      amount: amount,
      card: card_name,
      categories: CATEGORIES
    }.to_json

    request_body = {
      model: api_model,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: user_payload }
      ],
      temperature: 0.1,
      response_format: { type: "json_object" },
      max_tokens: 100
    }

    attempt = 0
    while attempt < MAX_RETRIES
      begin
        response = make_request(request_body)
        return parse_response(response)
      rescue Net::HTTPClientException, Net::HTTPFatalError => e
        if e.respond_to?(:response) && e.response.code.to_i == 429
          sleep(RETRY_DELAY * (attempt + 2))
        elsif e.respond_to?(:response) && e.response.code.to_i == 401
          Rails.logger.error("[ExpenseClassifierService] API 키 인증 실패")
          return FALLBACK.dup
        else
          sleep(RETRY_DELAY * (attempt + 1))
        end
      rescue => e
        Rails.logger.error("[ExpenseClassifierService] 분류 실패 (시도 #{attempt + 1}): #{e.message}")
        sleep(RETRY_DELAY * (attempt + 1))
      end
      attempt += 1
    end

    FALLBACK.dup
  end

  def self.format_description(memo, merchant, card_name)
    merchant = merchant.to_s.strip
    card_name = card_name.to_s.strip
    if merchant.present?
      "#{memo}(#{merchant},#{card_name})"
    else
      "#{memo}(#{card_name})"
    end
  end

  private

  def api_url
    ENV.fetch("DEEPSEEK_API_URL", "https://api.deepseek.com/chat/completions")
  end

  def api_key
    ENV.fetch("DEEPSEEK_API_KEY", "")
  end

  def api_model
    ENV.fetch("DEEPSEEK_MODEL", "deepseek-chat")
  end

  def make_request(body)
    uri = URI(api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.read_timeout = TIMEOUT
    http.open_timeout = TIMEOUT

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      status_code = response.code.to_i
      error_class = status_code >= 500 ? Net::HTTPFatalError : Net::HTTPClientException
      raise error_class.new("#{response.code} #{response.message}", response)
    end

    response.body
  end

  def parse_response(response_body)
    data = JSON.parse(response_body)
    content = data.dig("choices", 0, "message", "content")
    parsed = JSON.parse(content)

    category = parsed["category"]
    memo = parsed["memo"]

    unless CATEGORIES.include?(category)
      Rails.logger.warn("[ExpenseClassifierService] 유효하지 않은 카테고리 '#{category}' → '잡비'로 변경")
      category = "잡비"
    end

    memo = "기타지출" if memo.blank?

    { category: category, memo: memo.strip }
  rescue JSON::ParserError => e
    Rails.logger.error("[ExpenseClassifierService] JSON 파싱 실패: #{e.message}")
    FALLBACK.dup
  end
end
