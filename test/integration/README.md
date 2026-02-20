# Rails ↔ FastAPI 통합 테스트

## 개요

이 디렉토리는 Rails 애플리케이션과 FastAPI 백엔드 간의 통합 테스트를 포함합니다.

### 주요 테스트 파일

- **blog_ai_integration_test.rb** (27개 테스트)
  - Generate 엔드포인트: SSE 스트리밍
  - Chat 엔드포인트: SSE 스트리밍
  - Ingest 엔드포인트: 파일 업로드
  - API 헤더 및 인증
  - 에러 핸들링
  - 환경변수 관리
  - 고급 통합 시나리오

---

## 빠른 시작

### 1. 의존성 설치
```bash
cd /Users/minjaechai/legal-scheduler-ai/new-project/legal-scheduler
bundle install
```

### 2. 모든 통합 테스트 실행
```bash
bundle exec rails test test/integration/blog_ai_integration_test.rb
```

### 3. 특정 테스트만 실행
```bash
# Generate 테스트만
bundle exec rails test test/integration/blog_ai_integration_test.rb -n test_generate_sends_correct_request

# 모든 Generate 테스트
bundle exec rails test test/integration/blog_ai_integration_test.rb -n /generate/

# 모든 에러 처리 테스트
bundle exec rails test test/integration/blog_ai_integration_test.rb -n /error/
```

### 4. 상세 출력
```bash
bundle exec rails test test/integration/blog_ai_integration_test.rb -v
```

---

## 테스트 구조

### BlogAiIntegrationTest
```ruby
class BlogAiIntegrationTest < ActiveSupport::TestCase
  # 1. Generate 엔드포인트 테스트 (3개)
  # 2. Chat 엔드포인트 테스트 (4개)
  # 3. Ingest 엔드포인트 테스트 (4개)
  # 4. API 헤더 및 인증 테스트 (3개)
  # 5. 에러 핸들링 테스트 (8개)
  # 6. 환경변수 테스트 (2개)
  # 7. 고급 통합 시나리오 테스트 (4개)
end
```

---

## 테스트 카테고리

### 1️⃣ Generate 엔드포인트 (블로그 글 생성)
| 테스트 | 설명 |
|--------|------|
| `test_generate_sends_correct_request` | 올바른 URL, 헤더, 페이로드로 요청 |
| `test_generate_streams_response_correctly` | SSE 멀티 청크 응답 처리 |
| `test_generate_handles_empty_document_ids` | 빈 document_ids 배열 처리 |

**검증 항목**:
- POST /api/blog/generate 호출
- Content-Type: application/json
- X-API-Key 헤더 포함
- Accept: text/event-stream
- SSE 스트림 읽기

### 2️⃣ Chat 엔드포인트 (AI 채팅)
| 테스트 | 설명 |
|--------|------|
| `test_chat_sends_correct_request` | 올바른 URL, 헤더, 페이로드로 요청 |
| `test_chat_streams_response_correctly` | SSE 청크 스트리밍 응답 처리 |
| `test_chat_handles_empty_history` | 빈 history 배열 처리 |
| `test_chat_handles_long_context` | 5000자 긴 컨텍스트 처리 |

**검증 항목**:
- POST /api/blog/chat 호출
- 대화 히스토리 전송
- SSE 스트림 읽기

### 3️⃣ Ingest 엔드포인트 (문서 업로드)
| 테스트 | 설명 |
|--------|------|
| `test_ingest_sends_multipart_form_data` | multipart/form-data 파일 업로드 |
| `test_ingest_returns_document_metadata` | 업로드 결과 메타데이터 반환 |
| `test_ingest_handles_missing_file` | 존재하지 않는 파일 처리 |
| `test_ingest_with_empty_tag` | 빈 tag 처리 |

**검증 항목**:
- POST /api/blog/ingest 호출
- multipart/form-data 인코딩
- 파일, file_type, user_id, tag 전송
- X-API-Key 헤더 포함

### 4️⃣ API 헤더 및 인증
| 테스트 | 설명 |
|--------|------|
| `test_api_key_header_included_in_all_requests` | 모든 요청에 X-API-Key 포함 |
| `test_content_type_headers_correct` | Content-Type 헤더 검증 |
| `test_accept_event_stream_header` | Accept 헤더 검증 |

**검증 항목**:
- X-API-Key 헤더 일관성
- Content-Type: application/json
- Accept: text/event-stream

### 5️⃣ 에러 핸들링
| 테스트 | 설명 | 기대 동작 |
|--------|------|----------|
| `test_generate_handles_connection_failure` | 연결 실패 (Errno::ECONNREFUSED) | StandardError raise |
| `test_generate_handles_timeout` | 타임아웃 (30초) | StandardError raise |
| `test_chat_handles_network_error` | 네트워크 에러 (SocketError) | StandardError raise |
| `test_generate_handles_server_error` | HTTP 500 | RuntimeError raise |
| `test_chat_handles_bad_request` | HTTP 400 | RuntimeError raise |
| `test_ingest_handles_server_error` | Ingest HTTP 503 | {success: false, error: "..."} |
| `test_ingest_handles_invalid_json_response` | 잘못된 JSON | {success: false, error: "Invalid JSON"} |

### 6️⃣ 환경변수 관리
| 테스트 | 설명 |
|--------|------|
| `test_environment_variables_used_correctly` | 커스텀 환경변수 사용 |
| `test_default_environment_variables` | 기본값 사용 |

**검증 항목**:
- BLOG_AI_API_URL
- BLOG_AI_API_KEY
- 기본값: http://localhost:8000, default-api-key

### 7️⃣ 고급 통합 시나리오
| 테스트 | 설명 |
|--------|------|
| `test_sequential_generate_and_chat` | Generate → Chat 순차 호출 |
| `test_ingest_then_generate_with_document_ids` | Ingest → Generate RAG 파이프라인 |
| `test_multiple_concurrent_streams` | 동시 여러 스트림 처리 |
| `test_large_response_streaming` | 100개 청크 대용량 응답 처리 |

---

## 기술 세부사항

### WebMock 사용
```ruby
# HTTP 요청 스텁 처리
stub_request(:post, "http://localhost:8000/api/blog/generate")
  .with(
    body: hash_including(...),
    headers: { "X-API-Key" => "test-api-key" }
  )
  .to_return(status: 200, body: "data: response\n\n")

# 요청 검증
assert_requested :post, "http://localhost:8000/api/blog/generate" do |req|
  assert_equal "test-api-key", req.headers["X-API-Key"]
end
```

### SSE 스트림 처리
```ruby
# 테스트에서 블록으로 청크 수신
chunks = []
BlogAiService.generate(...) do |chunk|
  chunks << chunk
end
# chunks = ["data: chunk1\n\n", "data: chunk2\n\n", ...]
```

### 파일 업로드 테스트
```ruby
# 임시 파일 생성
file_path = Rails.root.join("test/fixtures/files/test.txt")
FileUtils.mkdir_p(File.dirname(file_path))
File.write(file_path, "Test content")

# Ingest 호출
result = BlogAiService.ingest(
  file_path: file_path.to_s,
  file_type: "txt",
  user_id: 1,
  tag: "test"
)

# 정리
File.delete(file_path) if File.exist?(file_path)
```

---

## 검증 체크리스트

### 실행 전
- [ ] Ruby 3.3.0 설치 (또는 rbenv로 버전 전환)
- [ ] `bundle install` 실행
- [ ] WebMock gem 설치 확인

### 테스트 실행
- [ ] 모든 테스트 통과 (`27/27`)
- [ ] 0 failures, 0 errors
- [ ] 타임아웃 없음

### 코드 품질
- [ ] Ruby 문법 정상 (`ruby -c`)
- [ ] 일관성 있는 들여쓰기
- [ ] 명확한 테스트명 및 주석

---

## 환경 설정

### 테스트 환경변수 (test/test_helper.rb에서 설정)
```ruby
ENV["BLOG_AI_API_URL"] = "http://localhost:8000"
ENV["BLOG_AI_API_KEY"] = "test-api-key"
```

### 실제 환경 (development/production)
```bash
# .env 파일 또는 환경 변수
BLOG_AI_API_URL=http://fastapi-service:8000
BLOG_AI_API_KEY=${SECURE_API_KEY}
```

---

## 주의사항

### WebMock 설정
```ruby
# 모든 네트워크 요청 차단 (테스트 격리)
WebMock.disable_net_connect!(allow_localhost: false)

# teardown에서 상태 초기화
WebMock.reset!
```

### 파일 처리
- 임시 파일은 ensure 블록에서 정리
- Rails.root.join으로 절대 경로 사용
- 파일이 없으면 File.open에서 StandardError 발생

### 환경변수
- setup에서 설정
- 테스트 후 원래 값 복원
- 테스트 간 상태 격리 필수

---

## 문제 해결

### WebMock 에러
```
WebMock::NetConnectNotAllowedError: Real HTTP connections are disabled
```
→ 스텁이 요청 URL과 정확히 일치하는지 확인

### 타임아웃 에러
```
Net::OpenTimeout: execution expired
```
→ WebMock 스텁이 `:post` 메서드를 올바르게 정의했는지 확인

### JSON 파싱 에러
```
JSON::ParserError: unexpected token
```
→ 응답 body의 JSON 형식 검증, `to_json` 사용

---

## 관련 문서

- 검증 보고서: `test/verification/P3-INT_integration.md`
- BlogAiService 구현: `app/services/blog_ai_service.rb`
- 서비스 단위 테스트: `test/services/blog_ai_service_test.rb`

---

## 참고자료

- Rails Testing Guide: https://guides.rubyonrails.org/testing.html
- WebMock Gem: https://github.com/bblimke/webmock
- Minitest Documentation: https://ruby-doc.org/stdlib/libdoc/minitest/rdoc/Minitest.html
