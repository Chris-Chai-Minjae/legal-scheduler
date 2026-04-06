# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

class ExpenseClassifierService
  MAX_RETRIES = 3
  RETRY_DELAY = 1
  TIMEOUT = 30

  CATEGORIES = %w[출장비 소모품구입비 임금 잡비 보험료 복리후생비 관리비 임차료 통신비 교통비 식비].freeze

  # 규칙 기반 사전 분류 — AI 호출 전에 매칭하여 즉시 반환
  MERCHANT_RULES = [
    { pattern: /지에스네트웍스|GS25|지에스25/i, category: "복리후생비", memo: "GS 편의점", remarks: "GS 편의점" },
    { pattern: /payco|페이코/i, category: "식비", memo: "식비", remarks: "식비" },
    { pattern: /주유소?|충전소|오일스테이션|SK에너지|GS칼텍스/i, category: "교통비", memo: "차량주유비", remarks: "차량주유비" },
    { pattern: /삼성전자.{0,3}정기과금|삼성전자_정기과금/i, category: "보험료", memo: "삼성전자 보험료", remarks: "삼성전자 보험료" },
    { pattern: /주차/i, category: "교통비", memo: "주차료", remarks: "주차료" },
    { pattern: /매머드|매머드익스프레스|mammoth/i, category: "복리후생비", memo: "커피 구입", remarks: "커피 구입" },
    { pattern: /병원|의원|클리닉|약국|치과|한의원|정형외과|내과|외과|피부과|안과|이비인후과/i, category: "복리후생비", memo: "의료비", remarks: "의료비" },
    { pattern: /네이버페이|naverpay|쿠팡|11번가|옥션|지마켓|인터파크|위메프|티몬/i, category: "소모품구입비", memo: "소모품 구입비", remarks: "소모품 구입비" },
    { pattern: /유튜브|youtube|넷플릭스|netflix|디즈니플러스|왓챠|구독/i, category: "복리후생비", memo: "구독료", remarks: "구독료" },
  ].freeze

  # 제외 대상 — 비용회계에 포함하지 않는 거래
  EXCLUDED_PATTERNS = [
    /아파트.*관리비|관리비.*아파트|아파트관리/i,
    /가스비|도시가스|가스공사/i,
    /포인트리.*충전|포인트리충전/i,
    /지방세|재산세|주민세|자동차세|취득세|등록세|세금납부|지방소득세/i,
  ].freeze

  SYSTEM_PROMPT = <<~PROMPT
    당신은 회계 분류 전문가입니다. 아래 거래를 반드시 11개 카테고리 중 하나로 분류하고, 짧은 한국어 메모를 생성하세요.

    **필수 규칙:**
    1. 반드시 JSON 형식으로만 응답: {"category":"<분류>","memo":"<메모>"}
    2. category는 반드시 다음 중 하나: 출장비, 소모품구입비, 임금, 잡비, 보험료, 복리후생비, 관리비, 임차료, 통신비, 교통비, 식비
    3. memo는 2~6단어 한국어 명사구 (예: "직원 식대", "사무실 청소용품")
    4. 불확실하면 가장 가까운 카테고리 선택 (절대 실패하지 말 것)
    5. 다른 설명이나 텍스트 추가 금지

    **분류 가이드:**
    - 출장비: 숙박, 식대(출장 시)
    - 소모품구입비: 사무용품, 청소용품, 소모성 물품, 온라인 구매
    - 임금: 급여, 상여금, 수당
    - 잡비: 분류 불가능한 기타 지출
    - 보험료: 4대보험, 손해보험, 정기과금 보험
    - 복리후생비: 직원 식사, 회식, 경조사, 편의점, 커피, 의료비, 구독료
    - 관리비: 건물 관리비, 청소비, 경비비
    - 임차료: 사무실/주거지 임대료
    - 통신비: 인터넷, 전화, 우편
    - 교통비: 주유비, 주차료, 대중교통, 택시
    - 식비: 음식 배달, 결제 플랫폼 식비
  PROMPT

  FALLBACK = { category: "잡비", memo: "기타지출" }.freeze

  # 제외 대상 여부 확인
  def self.excluded?(merchant)
    merchant_str = merchant.to_s.strip
    return false if merchant_str.blank?

    EXCLUDED_PATTERNS.any? { |pattern| merchant_str.match?(pattern) }
  end

  # 규칙 기반 분류 — 매칭 시 즉시 반환, 미매칭 시 nil
  def self.rule_based_classify(merchant:)
    merchant_str = merchant.to_s.strip
    return nil if merchant_str.blank?

    matched = MERCHANT_RULES.find { |rule| merchant_str.match?(rule[:pattern]) }
    return nil unless matched

    { category: matched[:category], memo: matched[:memo], remarks: matched[:remarks] }
  end

  def self.classify(merchant:, amount:, card_name:)
    new.classify(merchant: merchant, amount: amount, card_name: card_name)
  end

  def classify(merchant:, amount:, card_name:)
    # 규칙 기반 사전 분류 우선 적용
    rule_result = self.class.rule_based_classify(merchant: merchant)
    return rule_result if rule_result

    return FALLBACK.dup if api_key.blank?

    user_payload = {
      merchant: merchant.to_s,
      amount: amount,
      card: card_name,
      categories: CATEGORIES
    }.to_json

    request_body = {
      model: api_model,
      system: SYSTEM_PROMPT,
      messages: [
        { role: "user", content: user_payload }
      ],
      temperature: 0.1,
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
    ENV.fetch("CLASSIFIER_API_URL", "https://api.anthropic.com/v1/messages")
  end

  def api_key
    ENV.fetch("CLASSIFIER_API_KEY", "")
  end

  def api_model
    ENV.fetch("CLASSIFIER_MODEL", "claude-haiku-4-5-20251001")
  end

  def make_request(body)
    uri = URI(api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.read_timeout = TIMEOUT
    http.open_timeout = TIMEOUT

    request = Net::HTTP::Post.new(uri)
    request["x-api-key"] = api_key
    request["anthropic-version"] = "2023-06-01"
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
    # Anthropic Messages API 응답 형식
    content = data.dig("content", 0, "text")
    # JSON 블록 추출 (마크다운 코드블록 안에 있을 수 있음)
    json_str = content[/\{[^}]+\}/] || content
    parsed = JSON.parse(json_str)

    category = parsed["category"]
    memo = parsed["memo"]

    unless CATEGORIES.include?(category)
      Rails.logger.warn("[ExpenseClassifierService] 유효하지 않은 카테고리 '#{category}' → '잡비'로 변경")
      category = "잡비"
    end

    memo = "기타지출" if memo.blank?

    { category: category, memo: memo.strip }
  rescue JSON::ParserError => e
    Rails.logger.error("[ExpenseClassifierService] JSON 파싱 실패: #{e.message}, content: #{content}")
    FALLBACK.dup
  end
end
