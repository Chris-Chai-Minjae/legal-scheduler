# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# BlogAiService
# FastAPI 백엔드와 통신하는 서비스 클래스
#
# 환경변수:
# - BLOG_AI_API_URL: FastAPI 엔드포인트 (기본값: http://localhost:8000)
# - BLOG_AI_API_KEY: API 인증 키
class BlogAiService
  # legal-scheduler 컨테이너의 기존 env 는 BLOG_AI_URL, blog-ai 스펙 문서는 BLOG_AI_API_URL
  # 양쪽 모두 지원 + Docker network 기본값
  API_URL = ENV["BLOG_AI_API_URL"] || ENV["BLOG_AI_URL"] || "http://blog-ai:8001"
  API_KEY = ENV.fetch("BLOG_AI_API_KEY", "change_me_in_production")
  TIMEOUT = 300 # 초 (이미지 2장 생성까지 최대 140초)

  # 블로그 글 생성 (SSE 스트리밍)
  #
  # @param prompt [String] 생성할 블로그 글의 주제
  # @param tone [String] 톤 (professional, easy, storytelling)
  # @param length [String] 길이 (short, medium, long)
  # @param document_ids [Array<Integer>] 참고 문서 ID 리스트
  # @param include_images [Boolean] 이미지 자동 생성 여부
  # @param image_count [Integer] 이미지 개수 (0-4)
  # @param image_preset [String] 이미지 카테고리 (auto/justice/documents/courthouse/abstract/library)
  # @param image_style [String] 이미지 유형 (auto/symbol/infographic/code_card/process_icon)
  # @param post_id [Integer, nil] BlogPost ID (이미지 저장 디렉터리 구분용)
  # @yield [String] SSE 스트림 청크
  # @return [void]
  def self.generate(
    prompt:, tone:, length:,
    document_ids: [],
    include_images: true,
    image_count: 2,
    image_preset: "auto",
    image_style: "auto",
    post_id: nil,
    &block
  )
    uri = URI.join(API_URL, "/api/generate")

    payload = {
      prompt: prompt,
      tone: tone,
      length: length,
      document_ids: document_ids,
      include_images: include_images,
      image_count: image_count,
      image_preset: image_preset,
      image_style: image_style,
    }
    payload[:post_id] = post_id if post_id

    stream_request(uri, payload, &block)
  end

  # AI 채팅 (SSE 스트리밍)
  #
  # @param message [String] 사용자 메시지
  # @param context [String] 블로그 글 컨텍스트
  # @param history [Array<Hash>] 대화 히스토리
  # @yield [String] SSE 스트림 청크
  # @return [void]
  def self.chat(message:, context: "", history: [], &block)
    uri = URI.join(API_URL, "/api/blog/chat")

    payload = {
      message: message,
      context: context,
      history: history
    }

    stream_request(uri, payload, &block)
  end

  # 문서 임베딩 생성 (RAG)
  #
  # @param file_path [String] 문서 파일 경로
  # @param file_type [String] 문서 타입 (pdf, docx, txt)
  # @param user_id [Integer] 사용자 ID
  # @param tag [String] 문서 태그
  # @return [Hash] { success: Boolean, document_id: Integer, chunk_count: Integer }
  def self.ingest(file_path:, file_type:, user_id:, tag: "")
    uri = URI.join(API_URL, "/api/blog/ingest")

    # 파일 업로드 (multipart/form-data)
    request = Net::HTTP::Post.new(uri)
    request["X-API-Key"] = API_KEY

    form_data = [
      ["file", File.open(file_path)],
      ["file_type", file_type],
      ["user_id", user_id.to_s],
      ["tag", tag]
    ]

    request.set_form(form_data, "multipart/form-data")

    response = http_client(uri).request(request)
    handle_response(response)
  rescue StandardError => e
    Rails.logger.error("BlogAiService.ingest failed: #{e.message}")
    { success: false, error: e.message }
  end

  private

  # SSE 스트리밍 요청
  def self.stream_request(uri, payload)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-API-Key"] = API_KEY
    request["Accept"] = "text/event-stream"
    request.body = payload.to_json

    http = http_client(uri)

    # 스트리밍 요청
    http.request(request) do |response|
      unless response.is_a?(Net::HTTPSuccess)
        raise "FastAPI error: #{response.code} #{response.message}"
      end

      # SSE 스트림 읽기
      response.read_body do |chunk|
        yield chunk if block_given?
      end
    end
  rescue StandardError => e
    Rails.logger.error("BlogAiService stream_request failed: #{e.message}")
    raise
  end

  # HTTP 클라이언트 설정
  def self.http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.read_timeout = TIMEOUT
    http.open_timeout = TIMEOUT
    http
  end

  # JSON 응답 처리
  def self.handle_response(response)
    unless response.is_a?(Net::HTTPSuccess)
      raise "FastAPI error: #{response.code} #{response.message}"
    end

    JSON.parse(response.body, symbolize_names: true)
  rescue JSON::ParserError => e
    Rails.logger.error("BlogAiService JSON parse failed: #{e.message}")
    { success: false, error: "Invalid JSON response" }
  end
end
