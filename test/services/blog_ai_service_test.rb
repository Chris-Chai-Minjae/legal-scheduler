# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class BlogAiServiceTest < ActiveSupport::TestCase
  setup do
    @api_url = "http://localhost:8000"
    @api_key = "test-api-key"

    ENV["BLOG_AI_API_URL"] = @api_url
    ENV["BLOG_AI_API_KEY"] = @api_key

    WebMock.disable_net_connect!(allow_localhost: false)
  end

  teardown do
    WebMock.reset!
  end

  # Generate 메서드 테스트
  test "generate should stream SSE chunks" do
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .with(
        body: hash_including(
          prompt: "Test prompt",
          tone: "professional",
          length: "medium"
        ),
        headers: {
          "Content-Type" => "application/json",
          "X-API-Key" => @api_key,
          "Accept" => "text/event-stream"
        }
      )
      .to_return(
        status: 200,
        body: "data: chunk1\n\ndata: chunk2\n\n",
        headers: { "Content-Type" => "text/event-stream" }
      )

    chunks = []
    BlogAiService.generate(
      prompt: "Test prompt",
      tone: "professional",
      length: "medium"
    ) do |chunk|
      chunks << chunk
    end

    assert_equal "data: chunk1\n\ndata: chunk2\n\n", chunks.join
  end

  test "generate should handle API errors" do
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_return(status: 500, body: "Internal Server Error")

    assert_raises(RuntimeError) do
      BlogAiService.generate(
        prompt: "Test",
        tone: "professional",
        length: "short"
      ) { |chunk| }
    end
  end

  # Chat 메서드 테스트
  test "chat should stream SSE chunks" do
    stub_request(:post, "#{@api_url}/api/blog/chat")
      .with(
        body: hash_including(
          message: "Hello",
          context: "Blog context",
          history: []
        ),
        headers: {
          "Content-Type" => "application/json",
          "X-API-Key" => @api_key,
          "Accept" => "text/event-stream"
        }
      )
      .to_return(
        status: 200,
        body: "data: response\n\n",
        headers: { "Content-Type" => "text/event-stream" }
      )

    chunks = []
    BlogAiService.chat(
      message: "Hello",
      context: "Blog context",
      history: []
    ) do |chunk|
      chunks << chunk
    end

    assert_equal "data: response\n\n", chunks.join
  end

  # Ingest 메서드 테스트
  test "ingest should upload file and return document info" do
    file_path = Rails.root.join("test/fixtures/files/test.txt")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "Test document content")

    stub_request(:post, "#{@api_url}/api/blog/ingest")
      .with(
        headers: {
          "X-API-Key" => @api_key
        }
      )
      .to_return(
        status: 200,
        body: { success: true, document_id: 123, chunk_count: 5 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = BlogAiService.ingest(
      file_path: file_path.to_s,
      file_type: "txt",
      user_id: 1,
      tag: "test"
    )

    assert result[:success]
    assert_equal 123, result[:document_id]
    assert_equal 5, result[:chunk_count]
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end

  test "ingest should handle file upload errors" do
    stub_request(:post, "#{@api_url}/api/blog/ingest")
      .to_return(status: 400, body: "Bad Request")

    result = BlogAiService.ingest(
      file_path: Rails.root.join("test/fixtures/files/nonexistent.txt").to_s,
      file_type: "txt",
      user_id: 1,
      tag: "test"
    )

    assert_equal false, result[:success]
    assert result[:error].present?
  end

  # API 연결 실패 테스트
  test "should handle connection timeout" do
    stub_request(:post, "#{@api_url}/api/blog/generate")
      .to_timeout

    assert_raises(StandardError) do
      BlogAiService.generate(
        prompt: "Test",
        tone: "professional",
        length: "short"
      ) { |chunk| }
    end
  end

  test "should handle network errors" do
    stub_request(:post, "#{@api_url}/api/blog/chat")
      .to_raise(SocketError)

    assert_raises(StandardError) do
      BlogAiService.chat(
        message: "Test",
        context: "",
        history: []
      ) { |chunk| }
    end
  end
end
