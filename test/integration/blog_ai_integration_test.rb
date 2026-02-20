# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

# P3-INT: Rails ↔ FastAPI 통합 테스트
#
# 이 테스트는 Rails 애플리케이션과 FastAPI 백엔드 간의 통합을 검증합니다.
# - BlogAiService가 FastAPI 엔드포인트를 올바르게 호출
# - SSE 스트리밍 응답을 정상적으로 수신
# - multipart/form-data 파일 업로드 처리
# - 에러 핸들링 및 타임아웃 처리
class BlogAiIntegrationTest < ActiveSupport::TestCase
  setup do
    @api_url = "http://localhost:8000"
    @api_key = "test-api-key"

    ENV["BLOG_AI_API_URL"] = @api_url
    ENV["BLOG_AI_API_KEY"] = @api_key

    # WebMock 설정: localhost 제외 모든 외부 요청 차단
    WebMock.disable_net_connect!(allow_localhost: false)
  end

  teardown do
    WebMock.reset!
  end

  # ========================================
  # 1. Generate 엔드포인트 - 블로그 글 생성
  # ========================================

  test "test_generate_sends_correct_request" do
    # FastAPI /api/blog/generate 엔드포인트 스텁
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .with(
        body: hash_including(
          prompt: "AI 기술 트렌드",
          tone: "professional",
          length: "medium",
          document_ids: [1, 2]
        ),
        headers: {
          "Content-Type" => "application/json",
          "X-API-Key" => @api_key,
          "Accept" => "text/event-stream"
        }
      )
      .to_return(
        status: 200,
        body: "data: {\"text\":\"생성된 텍스트...\"}\n\n",
        headers: { "Content-Type" => "text/event-stream" }
      )

    # BlogAiService.generate 호출
    chunks = []
    BlogAiService.generate(
      prompt: "AI 기술 트렌드",
      tone: "professional",
      length: "medium",
      document_ids: [1, 2]
    ) do |chunk|
      chunks << chunk
    end

    # 검증
    assert_not_empty chunks
    assert_includes chunks.join, "text"
    assert_requested :post, "#{@api_url}/api/blog/generate"
  end

  test "test_generate_streams_response_correctly" do
    # SSE 멀티 청크 응답 시뮬레이션
    sse_response = [
      "data: {\"text\":\"첫번째 \"}",
      "data: {\"text\":\"두번째 \"}",
      "data: {\"text\":\"세번째\"}"
    ].join("\n\n") + "\n\n"

    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_return(
        status: 200,
        body: sse_response,
        headers: { "Content-Type" => "text/event-stream" }
      )

    chunks = []
    BlogAiService.generate(
      prompt: "Test",
      tone: "easy",
      length: "short"
    ) do |chunk|
      chunks << chunk
    end

    # SSE 형식 검증
    result = chunks.join
    assert_includes result, "첫번째"
    assert_includes result, "두번째"
    assert_includes result, "세번째"
  end

  test "test_generate_handles_empty_document_ids" do
    # document_ids 없이 호출 (기본값: [])
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .with(
        body: hash_including(
          prompt: "새로운 주제",
          tone: "storytelling",
          length: "long",
          document_ids: []
        )
      )
      .to_return(status: 200, body: "data: generated\n\n")

    chunks = []
    BlogAiService.generate(
      prompt: "새로운 주제",
      tone: "storytelling",
      length: "long"
    ) do |chunk|
      chunks << chunk
    end

    assert_requested :post, "#{@api_url}/api/blog/generate" do |req|
      body = JSON.parse(req.body)
      assert_empty body["document_ids"]
    end
  end

  # ========================================
  # 2. Chat 엔드포인트 - AI 채팅
  # ========================================

  test "test_chat_sends_correct_request" do
    # FastAPI /api/blog/chat 엔드포인트 스텁
    stub_request(:post, "#{@api_url}/api/blog/chat")
      .with(
        body: hash_including(
          message: "이 글을 더 길게 작성할 수 있나요?",
          context: "AI와 기술",
          history: [
            { role: "user", content: "첫 번째 메시지" },
            { role: "assistant", content: "첫 번째 응답" }
          ]
        ),
        headers: {
          "Content-Type" => "application/json",
          "X-API-Key" => @api_key,
          "Accept" => "text/event-stream"
        }
      )
      .to_return(
        status: 200,
        body: "data: {\"response\":\"네, 가능합니다...\"}\n\n",
        headers: { "Content-Type" => "text/event-stream" }
      )

    chunks = []
    history = [
      { role: "user", content: "첫 번째 메시지" },
      { role: "assistant", content: "첫 번째 응답" }
    ]

    BlogAiService.chat(
      message: "이 글을 더 길게 작성할 수 있나요?",
      context: "AI와 기술",
      history: history
    ) do |chunk|
      chunks << chunk
    end

    assert_not_empty chunks
    assert_includes chunks.join, "response"
    assert_requested :post, "#{@api_url}/api/blog/chat"
  end

  test "test_chat_streams_response_correctly" do
    # SSE 청크 응답
    stub_request(:post, "#{@api_url}/api/blog/chat")
      .to_return(
        status: 200,
        body: "data: 청크1\n\ndata: 청크2\n\ndata: 청크3\n\n",
        headers: { "Content-Type" => "text/event-stream" }
      )

    chunks = []
    BlogAiService.chat(
      message: "Test",
      context: "Context",
      history: []
    ) do |chunk|
      chunks << chunk
    end

    result = chunks.join
    assert_includes result, "청크1"
    assert_includes result, "청크2"
    assert_includes result, "청크3"
  end

  test "test_chat_handles_empty_history" do
    # history 없이 호출 (기본값: [])
    stub_request(:post, "#{@api_url}/api/blog/chat")
      .with(
        body: hash_including(
          message: "Hello",
          context: "",
          history: []
        )
      )
      .to_return(status: 200, body: "data: OK\n\n")

    chunks = []
    BlogAiService.chat(
      message: "Hello",
      context: "",
      history: []
    ) do |chunk|
      chunks << chunk
    end

    assert_requested :post, "#{@api_url}/api/blog/chat" do |req|
      body = JSON.parse(req.body)
      assert_empty body["history"]
    end
  end

  test "test_chat_handles_long_context" do
    # 긴 컨텍스트 전송 검증
    long_context = "A" * 5000

    stub_request(:post, "#{@api_url}/api/blog/chat")
      .with(
        body: hash_including(
          message: "More content?",
          context: long_context
        )
      )
      .to_return(status: 200, body: "data: response\n\n")

    chunks = []
    BlogAiService.chat(
      message: "More content?",
      context: long_context
    ) do |chunk|
      chunks << chunk
    end

    assert_requested :post, "#{@api_url}/api/blog/chat" do |req|
      body = JSON.parse(req.body)
      assert_equal long_context, body["context"]
    end
  end

  # ========================================
  # 3. Ingest 엔드포인트 - 문서 업로드
  # ========================================

  test "test_ingest_sends_multipart_form_data" do
    # 테스트 파일 생성
    file_path = Rails.root.join("test/fixtures/files/ingest_test.txt")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "Test document for ingestion")

    # multipart/form-data 검증
    stub_request(:post, "#{@api_url}/api/blog/ingest")
      .with(
        headers: {
          "X-API-Key" => @api_key
        }
      )
      .to_return(
        status: 200,
        body: {
          success: true,
          document_id: 42,
          chunk_count: 3,
          tags: ["test"]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = BlogAiService.ingest(
      file_path: file_path.to_s,
      file_type: "txt",
      user_id: 99,
      tag: "test"
    )

    assert result[:success]
    assert_equal 42, result[:document_id]
    assert_equal 3, result[:chunk_count]
    assert_requested :post, "#{@api_url}/api/blog/ingest"
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end

  test "test_ingest_returns_document_metadata" do
    file_path = Rails.root.join("test/fixtures/files/test_doc.pdf")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "%PDF-1.4 mock pdf content")

    stub_request(:post, "#{@api_url}/api/blog/ingest")
      .to_return(
        status: 200,
        body: {
          success: true,
          document_id: 123,
          chunk_count: 10,
          file_size: 500,
          processed_at: "2025-02-07T10:00:00Z"
        }.to_json
      )

    result = BlogAiService.ingest(
      file_path: file_path.to_s,
      file_type: "pdf",
      user_id: 1,
      tag: "legal"
    )

    assert result[:success]
    assert_equal 123, result[:document_id]
    assert_equal 10, result[:chunk_count]
    assert result[:file_size].present?
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end

  test "test_ingest_handles_missing_file" do
    stub_request(:post, "#{@api_url}/api/blog/ingest")
      .to_return(status: 400, body: { error: "File not found" }.to_json)

    result = BlogAiService.ingest(
      file_path: "/nonexistent/file.txt",
      file_type: "txt",
      user_id: 1,
      tag: ""
    )

    # 파일이 없으면 File.open에서 StandardError 발생
    assert_equal false, result[:success]
    assert result[:error].present?
  end

  test "test_ingest_with_empty_tag" do
    file_path = Rails.root.join("test/fixtures/files/no_tag.txt")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "Content without tag")

    stub_request(:post, "#{@api_url}/api/blog/ingest")
      .to_return(
        status: 200,
        body: { success: true, document_id: 1, chunk_count: 1 }.to_json
      )

    result = BlogAiService.ingest(
      file_path: file_path.to_s,
      file_type: "txt",
      user_id: 1,
      tag: ""
    )

    assert result[:success]
    assert_requested :post, "#{@api_url}/api/blog/ingest"
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end

  # ========================================
  # 4. API 헤더 및 인증 검증
  # ========================================

  test "test_api_key_header_included_in_all_requests" do
    # Generate
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_return(status: 200, body: "data: test\n\n")

    BlogAiService.generate(
      prompt: "Test",
      tone: "professional",
      length: "short"
    ) { |_| }

    assert_requested :post, "#{@api_url}/api/blog/generate" do |req|
      assert_equal @api_key, req.headers["X-API-Key"]
    end

    WebMock.reset!

    # Chat
    stub_request(:post, "#{@api_url}/api/blog/chat")
      .to_return(status: 200, body: "data: test\n\n")

    BlogAiService.chat(
      message: "Test",
      context: "",
      history: []
    ) { |_| }

    assert_requested :post, "#{@api_url}/api/blog/chat" do |req|
      assert_equal @api_key, req.headers["X-API-Key"]
    end

    WebMock.reset!

    # Ingest
    file_path = Rails.root.join("test/fixtures/files/header_test.txt")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "Test")

    stub_request(:post, "#{@api_url}/api/blog/ingest")
      .to_return(status: 200, body: { success: true }.to_json)

    BlogAiService.ingest(
      file_path: file_path.to_s,
      file_type: "txt",
      user_id: 1
    )

    assert_requested :post, "#{@api_url}/api/blog/ingest" do |req|
      assert_equal @api_key, req.headers["X-API-Key"]
    end
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end

  test "test_content_type_headers_correct" do
    # Generate & Chat: application/json
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_return(status: 200, body: "data: test\n\n")

    BlogAiService.generate(
      prompt: "Test",
      tone: "professional",
      length: "short"
    ) { |_| }

    assert_requested :post, "#{@api_url}/api/blog/generate" do |req|
      assert_equal "application/json", req.headers["Content-Type"]
      assert_equal "text/event-stream", req.headers["Accept"]
    end
  end

  test "test_accept_event_stream_header" do
    stub_request(:post, "#{@api_url}/api/blog/chat")
      .to_return(status: 200, body: "data: test\n\n")

    BlogAiService.chat(
      message: "Test",
      context: "",
      history: []
    ) { |_| }

    assert_requested :post, "#{@api_url}/api/blog/chat" do |req|
      assert_equal "text/event-stream", req.headers["Accept"]
    end
  end

  # ========================================
  # 5. 에러 핸들링
  # ========================================

  test "test_generate_handles_connection_failure" do
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_raise(Errno::ECONNREFUSED)

    assert_raises(StandardError) do
      BlogAiService.generate(
        prompt: "Test",
        tone: "professional",
        length: "short"
      ) { |_| }
    end
  end

  test "test_generate_handles_timeout" do
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_timeout

    assert_raises(StandardError) do
      BlogAiService.generate(
        prompt: "Test",
        tone: "professional",
        length: "short"
      ) { |_| }
    end
  end

  test "test_chat_handles_network_error" do
    stub_request(:post, "#{@api_url}/api/blog/chat")
      .to_raise(SocketError)

    assert_raises(StandardError) do
      BlogAiService.chat(
        message: "Test",
        context: "",
        history: []
      ) { |_| }
    end
  end

  test "test_generate_handles_server_error" do
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_return(status: 500, body: "Internal Server Error")

    assert_raises(RuntimeError) do
      BlogAiService.generate(
        prompt: "Test",
        tone: "professional",
        length: "short"
      ) { |_| }
    end
  end

  test "test_chat_handles_bad_request" do
    stub_request(:post, "#{@api_url}/api/blog/chat")
      .to_return(status: 400, body: { error: "Invalid request" }.to_json)

    assert_raises(RuntimeError) do
      BlogAiService.chat(
        message: "Test",
        context: "",
        history: []
      ) { |_| }
    end
  end

  test "test_ingest_handles_server_error" do
    file_path = Rails.root.join("test/fixtures/files/error_test.txt")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "Test")

    stub_request(:post, "#{@api_url}/api/blog/ingest")
      .to_return(status: 503, body: "Service Unavailable")

    result = BlogAiService.ingest(
      file_path: file_path.to_s,
      file_type: "txt",
      user_id: 1
    )

    assert_equal false, result[:success]
    assert result[:error].present?
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end

  test "test_ingest_handles_invalid_json_response" do
    file_path = Rails.root.join("test/fixtures/files/json_error.txt")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "Test")

    stub_request(:post, "#{@api_url}/api/blog/ingest")
      .to_return(status: 200, body: "Invalid JSON {{{")

    result = BlogAiService.ingest(
      file_path: file_path.to_s,
      file_type: "txt",
      user_id: 1
    )

    assert_equal false, result[:success]
    assert_includes result[:error], "Invalid JSON"
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end

  # ========================================
  # 6. 환경변수 및 설정 검증
  # ========================================

  test "test_environment_variables_used_correctly" do
    custom_url = "http://custom-api.example.com:9000"
    custom_key = "custom-secret-key"

    ENV["BLOG_AI_API_URL"] = custom_url
    ENV["BLOG_AI_API_KEY"] = custom_key

    stub_request(:post, "#{custom_url}/api/blog/generate")
      .to_return(status: 200, body: "data: test\n\n")

    BlogAiService.generate(
      prompt: "Test",
      tone: "professional",
      length: "short"
    ) { |_| }

    assert_requested :post, "#{custom_url}/api/blog/generate" do |req|
      assert_equal custom_key, req.headers["X-API-Key"]
    end

    # 원래 값으로 복원
    ENV["BLOG_AI_API_URL"] = @api_url
    ENV["BLOG_AI_API_KEY"] = @api_key
  end

  test "test_default_environment_variables" do
    # 환경변수 초기화
    ENV["BLOG_AI_API_URL"] = nil
    ENV["BLOG_AI_API_KEY"] = nil

    # 기본값으로 호출되는지 확인
    default_url = "http://localhost:8000"
    default_key = "default-api-key"

    stub_request(:post, "#{default_url}/api/blog/generate")
      .to_return(status: 200, body: "data: test\n\n")

    BlogAiService.generate(
      prompt: "Test",
      tone: "professional",
      length: "short"
    ) { |_| }

    assert_requested :post, "#{default_url}/api/blog/generate" do |req|
      assert_equal default_key, req.headers["X-API-Key"]
    end

    # 원래 값으로 복원
    ENV["BLOG_AI_API_URL"] = @api_url
    ENV["BLOG_AI_API_KEY"] = @api_key
  end

  # ========================================
  # 7. 고급 통합 시나리오
  # ========================================

  test "test_sequential_generate_and_chat" do
    # 순차적으로 generate 후 chat 호출
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_return(status: 200, body: "data: generated content\n\n")

    stub_request(:post, "#{@api_url}/api/blog/chat")
      .to_return(status: 200, body: "data: chat response\n\n")

    # Generate 호출
    generate_chunks = []
    BlogAiService.generate(
      prompt: "생성 주제",
      tone: "professional",
      length: "medium"
    ) do |chunk|
      generate_chunks << chunk
    end

    assert_not_empty generate_chunks

    # Chat 호출
    chat_chunks = []
    BlogAiService.chat(
      message: "질문",
      context: generate_chunks.join,
      history: []
    ) do |chunk|
      chat_chunks << chunk
    end

    assert_not_empty chat_chunks
    assert_requested :post, "#{@api_url}/api/blog/generate"
    assert_requested :post, "#{@api_url}/api/blog/chat"
  end

  test "test_ingest_then_generate_with_document_ids" do
    # Ingest로 문서 업로드 후, generate에서 document_ids 사용
    file_path = Rails.root.join("test/fixtures/files/ingest_generate.txt")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "Source document for RAG")

    stub_request(:post, "#{@api_url}/api/blog/ingest")
      .to_return(
        status: 200,
        body: { success: true, document_id: 789, chunk_count: 5 }.to_json
      )

    result = BlogAiService.ingest(
      file_path: file_path.to_s,
      file_type: "txt",
      user_id: 1,
      tag: "rag-test"
    )

    document_id = result[:document_id]

    stub_request(:post, "#{@api_url}/api/blog/generate")
      .with(
        body: hash_including(
          document_ids: [document_id]
        )
      )
      .to_return(status: 200, body: "data: rag-generated\n\n")

    chunks = []
    BlogAiService.generate(
      prompt: "RAG 기반 생성",
      tone: "professional",
      length: "short",
      document_ids: [document_id]
    ) do |chunk|
      chunks << chunk
    end

    assert_not_empty chunks
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end

  test "test_multiple_concurrent_streams" do
    # 동시에 여러 generate/chat 요청 처리
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_return(status: 200, body: "data: stream1\n\n")

    stub_request(:post, "#{@api_url}/api/blog/chat")
      .to_return(status: 200, body: "data: stream2\n\n")

    results = []

    # Generate
    BlogAiService.generate(
      prompt: "Test1",
      tone: "professional",
      length: "short"
    ) do |chunk|
      results << chunk
    end

    # Chat
    BlogAiService.chat(
      message: "Test2",
      context: "",
      history: []
    ) do |chunk|
      results << chunk
    end

    assert_equal 2, results.length
  end

  test "test_large_response_streaming" do
    # 큰 SSE 응답 스트리밍 처리
    large_response = (0..100).map { |i| "data: chunk#{i}\n\n" }.join

    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_return(
        status: 200,
        body: large_response,
        headers: { "Content-Type" => "text/event-stream" }
      )

    chunks = []
    BlogAiService.generate(
      prompt: "Large",
      tone: "professional",
      length: "long"
    ) do |chunk|
      chunks << chunk
    end

    result = chunks.join
    (0..100).each do |i|
      assert_includes result, "chunk#{i}"
    end
  end
end
