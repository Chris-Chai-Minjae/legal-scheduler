# 05-api-spec.md — API 명세 및 스키마

## 메타 정보
- **프로젝트**: Legal Scheduler AI - SEO 평가 시스템
- **버전**: 1.0
- **작성일**: 2026-04-06
- **담당**: API Design Lead

---

## 1. API 개요

SEO 평가 시스템은 2개 계층의 API로 구성됩니다:
- **FastAPI** (blog-ai): SEO 분석 및 AI 재작성 로직
- **Rails**: 프론트엔드 UI 및 데이터 저장 프록시

---

## 2. FastAPI Endpoints

### 2.1 기본 정보

- **Base URL**: `http://blog-ai-service:8000` (내부 통신) / `https://api.example.com` (외부)
- **인증**: 없음 (내부 API) / API Key (향후 추가 가능)
- **Content-Type**: `application/json` (모든 요청/응답)
- **타임아웃**: 30초 (API 호출)

---

### 2.2 POST /api/seo/analyze

**목적**: 글의 SEO 점수 자동 분석

**요청**:
```http
POST /api/seo/analyze HTTP/1.1
Host: blog-ai-service:8000
Content-Type: application/json

{
  "content": "기업 소송의 변론일은 법정 공판 기일을 의미합니다...",
  "title": "기업 소송 변론일 일정 관리법과 실무 팁",
  "description": null,
  "slug": "변론일-일정-관리법",
  "images": [
    {
      "url": "/uploads/image-1.jpg",
      "alt_text": "변론일 달력 예시"
    },
    {
      "url": "/uploads/image-2.jpg",
      "alt_text": null
    }
  ],
  "internal_links": [
    {
      "text": "변론일 준비 서면 작성",
      "url": "/blog/변론일-준비-서면"
    }
  ],
  "target_keywords": ["변론일", "기업 소송", "일정 관리"]
}
```

**응답** (200 OK):
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "score": 65,
  "total_points": 100,
  "analyzed_at": "2026-04-06T14:30:00Z",
  "items": [
    {
      "id": "title_keyword",
      "name": "제목 키워드",
      "category": "keyword_optimization",
      "score": 8,
      "max_score": 10,
      "status": "warning",
      "feedback": "제목이 35자로 32자 제한을 초과했습니다.",
      "current_value": "기업 소송 변론일 일정 관리법과 실무 팁",
      "suggestion": "기업 소송 변론일 관리법"
    },
    {
      "id": "meta_description",
      "name": "메타 디스크립션",
      "category": "keyword_optimization",
      "score": 0,
      "max_score": 10,
      "status": "error",
      "feedback": "메타 디스크립션이 없습니다.",
      "current_value": null,
      "suggestion": "변론일 일정을 효율적으로 관리하는 방법을 알아보세요."
    },
    {
      "id": "keyword_density",
      "name": "키워드 밀도",
      "category": "keyword_optimization",
      "score": 7,
      "max_score": 10,
      "status": "warning",
      "feedback": "타겟 키워드 '변론일'이 1.2%로 1.5~2.5% 범위 이하입니다.",
      "current_value": "1.2%",
      "suggestion": "2.0% (추가 5회 등장 필요)"
    },
    {
      "id": "h2_structure",
      "name": "H2 소제목 구조",
      "category": "keyword_optimization",
      "score": 10,
      "max_score": 10,
      "status": "success",
      "feedback": "좋습니다. H2 소제목이 4개이고 모두 키워드를 포함합니다.",
      "current_value": [
        "변론일 일정 확인하는 방법",
        "변론일 준비 서면 작성",
        "변론일 직후 체크리스트",
        "변론일 관련 법률 정보"
      ],
      "suggestion": null
    },
    {
      "id": "url_slug",
      "name": "URL 구조/슬러그",
      "category": "technical_seo",
      "score": 10,
      "max_score": 10,
      "status": "success",
      "feedback": "좋습니다. 슬러그가 명확하고 키워드를 포함합니다.",
      "current_value": "변론일-일정-관리법",
      "suggestion": null
    },
    {
      "id": "image_alt",
      "name": "이미지 Alt 태그",
      "category": "technical_seo",
      "score": 5,
      "max_score": 10,
      "status": "warning",
      "feedback": "2개 이미지 중 1개만 alt 태그가 있습니다.",
      "current_value": [
        "변론일 달력 예시",
        "(없음)"
      ],
      "suggestion": [
        "변론일 달력 예시",
        "기업 소송 변론일 일정 관리 가이드"
      ]
    },
    {
      "id": "internal_links",
      "name": "내부 링크",
      "category": "technical_seo",
      "score": 3,
      "max_score": 10,
      "status": "error",
      "feedback": "내부 링크가 1개입니다. 최소 2개 이상 필요합니다.",
      "current_value": 1,
      "suggestion": "2개 이상 추가 (예: 변론일 준비 서면, 변론일 후 업무)"
    },
    {
      "id": "meta_tags",
      "name": "메타 태그 최적화",
      "category": "technical_seo",
      "score": 6,
      "max_score": 10,
      "status": "warning",
      "feedback": "og:image가 없습니다. OG 태그를 모두 추가하세요.",
      "current_value": {
        "og:title": "기업 소송 변론일 일정 관리법",
        "og:description": null,
        "og:image": null,
        "canonical": "/blog/변론일-일정-관리법"
      },
      "suggestion": {
        "og:description": "변론일 일정을 효율적으로 관리하는 방법 가이드",
        "og:image": "/uploads/og-image-변론일.jpg"
      }
    },
    {
      "id": "content_length",
      "name": "글 길이",
      "category": "bonus",
      "score": 10,
      "max_score": 10,
      "status": "success",
      "feedback": "좋습니다. 2,500자로 2,000자 이상입니다.",
      "current_value": "2,500자",
      "suggestion": null
    },
    {
      "id": "readability",
      "name": "가독성",
      "category": "bonus",
      "score": 8,
      "max_score": 10,
      "status": "success",
      "feedback": "좋습니다. 평균 문장 길이 35자, 단락 구조 명확합니다.",
      "current_value": {
        "avg_sentence_length": 35,
        "avg_paragraph_sentences": 4,
        "has_lists": true
      },
      "suggestion": null
    }
  ],
  "summary": {
    "keyword_optimization": {
      "score": 25,
      "max": 40
    },
    "technical_seo": {
      "score": 24,
      "max": 40
    },
    "bonus": {
      "score": 18,
      "max": 20
    }
  }
}
```

**에러 응답** (400 Bad Request):
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "ValidationError",
  "message": "Request validation failed",
  "details": {
    "field": "content",
    "error": "content is required and must be non-empty"
  }
}
```

**에러 응답** (503 Service Unavailable):
```http
HTTP/1.1 503 Service Unavailable
Content-Type: application/json

{
  "error": "ServiceUnavailable",
  "message": "Claude API is temporarily unavailable",
  "retry_after": 30
}
```

**요청 스키마** (Pydantic):
```python
from pydantic import BaseModel
from typing import Optional, List

class ImageInfo(BaseModel):
    url: str
    alt_text: Optional[str] = None

class LinkInfo(BaseModel):
    text: str
    url: str

class AnalyzeRequest(BaseModel):
    content: str  # 필수, 비어있으면 안 됨
    title: str  # 필수
    description: Optional[str] = None
    slug: str  # 필수
    images: Optional[List[ImageInfo]] = []
    internal_links: Optional[List[LinkInfo]] = []
    target_keywords: List[str]  # 필수, 1개 이상
```

**응답 스키마** (Pydantic):
```python
class SeoItem(BaseModel):
    id: str
    name: str
    category: str  # "keyword_optimization", "technical_seo", "bonus"
    score: int
    max_score: int
    status: str  # "success", "warning", "error"
    feedback: str
    current_value: Optional[str | int | list | dict]
    suggestion: Optional[str | int | list | dict]

class AnalyzeSummary(BaseModel):
    keyword_optimization: dict  # { "score": int, "max": int }
    technical_seo: dict
    bonus: dict

class AnalyzeResponse(BaseModel):
    score: int
    total_points: int
    analyzed_at: str  # ISO 8601
    items: List[SeoItem]
    summary: AnalyzeSummary
```

---

### 2.3 POST /api/seo/optimize/{item}

**목적**: 특정 SEO 항목에 대한 AI 기반 재작성 제안

**경로 파라미터**:
- `item` (string, required): 항목 ID
  - `title_keyword`
  - `meta_description`
  - `keyword_density`
  - `h2_structure`
  - `url_slug`
  - `image_alt`
  - `internal_links`
  - `meta_tags`
  - `content_length`
  - `readability`

**요청**:
```http
POST /api/seo/optimize/meta_description HTTP/1.1
Host: blog-ai-service:8000
Content-Type: application/json

{
  "content": "기업 소송의 변론일은...",
  "title": "기업 소송 변론일 일정 관리법과 실무 팁",
  "description": null,
  "slug": "변론일-일정-관리법",
  "target_keywords": ["변론일", "기업 소송", "일정 관리"],
  "item_type": "meta_description"
}
```

**응답** (200 OK):
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "item_id": "meta_description",
  "item_name": "메타 디스크립션",
  "current_value": null,
  "suggested_value": "변론일 일정을 효율적으로 관리하는 방법을 알아보세요.",
  "ai_reasoning": "메타 디스크립션이 없어서 추가했습니다. 80자 이내로 유지하고, 타겟 키워드 '변론일'과 행동 유도(알아보세요)를 포함했습니다.",
  "before": {
    "length": 0,
    "keyword_match": false
  },
  "after": {
    "length": 34,
    "keyword_match": true,
    "estimated_score_change": "+10점"
  }
}
```

**에러 응답** (400 Bad Request):
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "InvalidItem",
  "message": "Unknown item type: invalid_item",
  "valid_items": [
    "title_keyword",
    "meta_description",
    ...
  ]
}
```

**에러 응답** (429 Too Many Requests):
```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json

{
  "error": "RateLimitExceeded",
  "message": "Too many requests. Please try again later.",
  "retry_after": 60
}
```

**요청 스키마**:
```python
class OptimizeRequest(BaseModel):
    content: str
    title: str
    description: Optional[str] = None
    slug: str
    target_keywords: List[str]
    item_type: str
```

**응답 스키마**:
```python
class OptimizeResponse(BaseModel):
    item_id: str
    item_name: str
    current_value: Optional[str | int | list | dict]
    suggested_value: Optional[str | int | list | dict]
    ai_reasoning: str
    before: dict  # { "length": int, "keyword_match": bool }
    after: dict   # { "length": int, "keyword_match": bool, "estimated_score_change": str }
```

---

## 3. Rails API Endpoints

### 3.1 기본 정보

- **Base URL**: `https://legal-scheduler.example.com`
- **인증**: Devise (기존 세션 기반)
- **Content-Type**: `application/json`
- **CSRF 보호**: X-CSRF-Token 헤더 필수 (POST, PATCH, DELETE)

---

### 3.2 POST /blog_posts/:blog_post_id/seo/analyze

**목적**: SEO 분석을 수동으로 트리거 (또는 자동 트리거 결과 수신)

**인증**: 로그인 필수, 글 소유자 또는 관리자

**요청**:
```http
POST /blog_posts/123/seo/analyze HTTP/1.1
Host: legal-scheduler.example.com
X-CSRF-Token: {{ csrf_token }}
Content-Type: application/json

{}
```

**응답** (Turbo Stream):
```http
HTTP/1.1 200 OK
Content-Type: text/vnd.turbo-stream.html; charset=utf-8

<turbo-stream action="replace" target="seo-panel">
  <template>
    <div id="seo-panel" class="seo-panel">
      <div class="seo-score">
        <div class="score-gauge">65/100</div>
        <div class="items">...</div>
      </div>
    </div>
  </template>
</turbo-stream>
```

**JSON 응답** (선택사항):
```json
{
  "status": "success",
  "seo_score": 65,
  "seo_details": { ... }
}
```

**에러 응답** (403 Forbidden):
```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "error": "Unauthorized",
  "message": "You don't have permission to analyze this post"
}
```

---

### 3.3 POST /blog_posts/:blog_post_id/seo/optimize/:item

**목적**: FastAPI 최적화 엔드포인트로 프록시 요청, 결과 반환

**인증**: 로그인 필수

**경로 파라미터**:
- `blog_post_id` (integer)
- `item` (string): 항목 ID

**요청**:
```http
POST /blog_posts/123/seo/optimize/meta_description HTTP/1.1
Host: legal-scheduler.example.com
X-CSRF-Token: {{ csrf_token }}
Content-Type: application/json

{}
```

**응답** (200 OK, JSON):
```json
{
  "item_id": "meta_description",
  "item_name": "메타 디스크립션",
  "current_value": null,
  "suggested_value": "변론일 일정을 효율적으로 관리하는 방법을 알아보세요.",
  "ai_reasoning": "..."
}
```

**모달 표시 로직** (클라이언트):
```javascript
// app/javascript/controllers/seo_panel_controller.js
async optimizeItem(event) {
  const itemId = event.target.dataset.itemId
  const response = await fetch(
    `/blog_posts/${blogPostId}/seo/optimize/${itemId}`,
    { method: "POST" }
  )
  const data = await response.json()
  // 비교 모달 표시
  showComparisonModal(data)
}
```

---

### 3.4 PATCH /blog_posts/:blog_post_id/seo/apply

**목적**: AI 제안을 글에 적용하고 재저장

**인증**: 로그인 필수, 글 소유자

**요청**:
```http
PATCH /blog_posts/123/seo/apply HTTP/1.1
Host: legal-scheduler.example.com
X-CSRF-Token: {{ csrf_token }}
Content-Type: application/json

{
  "item_id": "meta_description",
  "field_name": "description",
  "new_value": "변론일 일정을 효율적으로 관리하는 방법을 알아보세요."
}
```

**응답** (Turbo Stream):
```html
<turbo-stream action="replace" target="blog-post-content">
  <template>
    <!-- 업데이트된 글 본문 -->
  </template>
</turbo-stream>

<turbo-stream action="replace" target="seo-panel">
  <template>
    <!-- 업데이트된 SEO 패널 -->
  </template>
</turbo-stream>
```

**부작용**:
1. BlogPost 업데이트 (필드 변경)
2. FastAPI 재분석 (새로운 seo_score, seo_details)
3. BlogPost 저장 (seo_score, seo_details 업데이트)

**에러 응답** (422 Unprocessable Entity):
```json
{
  "error": "ValidationError",
  "message": "Failed to update blog post",
  "details": {
    "field": "description",
    "error": "is too long (maximum is 160 characters)"
  }
}
```

---

## 4. 요청/응답 헤더

### 4.1 FastAPI 헤더

**요청**:
```http
POST /api/seo/analyze HTTP/1.1
Host: blog-ai-service:8000
Content-Type: application/json
User-Agent: Rails/8.0 (legal-scheduler-ai)
X-Request-ID: 550e8400-e29b-41d4-a716-446655440000

{...}
```

**응답**:
```http
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 5234
X-Process-Time: 3.456
Date: Sat, 06 Apr 2026 14:30:00 GMT

{...}
```

### 4.2 Rails 헤더

**요청**:
```http
POST /blog_posts/123/seo/analyze HTTP/1.1
Host: legal-scheduler.example.com
X-CSRF-Token: 3aG7nq9xK2pL5mB8vC1zD4...
X-Requested-With: XMLHttpRequest
Content-Type: application/json
Accept: text/vnd.turbo-stream.html, application/json

{...}
```

**응답**:
```http
HTTP/1.1 200 OK
Content-Type: text/vnd.turbo-stream.html; charset=utf-8
X-CSRF-Token: (새로운 토큰)
Cache-Control: no-cache, no-store
X-Frame-Options: SAMEORIGIN

{...}
```

---

## 5. 상태 코드 및 에러 처리

### 5.1 HTTP 상태 코드

| 코드 | 의미 | 예시 |
|------|------|------|
| 200 | 성공 | SEO 분석 완료 |
| 201 | 생성됨 | (사용 안 함) |
| 400 | 잘못된 요청 | 필수 필드 누락 |
| 401 | 인증 필요 | 로그인 필요 |
| 403 | 접근 금지 | 다른 사용자의 글 편집 시도 |
| 404 | 찾을 수 없음 | 존재하지 않는 블로그 글 |
| 422 | 처리 불가 | 검증 오류 |
| 429 | 요청 제한 | 분당 10개 초과 |
| 500 | 서버 오류 | FastAPI 오류 |
| 503 | 서비스 이용 불가 | Claude API 타임아웃 |

### 5.2 에러 응답 포맷

```json
{
  "error": "ErrorType",
  "message": "사용자 친화적 메시지",
  "details": {
    "field": "필드명",
    "error": "상세 설명"
  },
  "timestamp": "2026-04-06T14:30:00Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

## 6. 레이트 리미팅

### 6.1 FastAPI 레이트 제한

- **SEO 분석**: 분당 10개 (IP 당)
- **최적화**: 분당 20개 (IP 당)
- **전체**: 시간당 500개 (IP 당)

**헤더**:
```http
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 8
X-RateLimit-Reset: 1712409060
```

### 6.2 Rails 레이트 제한 (선택사항)

- 사용자당 일일 분석 횟수: 무제한 (또는 100회)
- 사용자당 일일 최적화 횟수: 무제한 (또는 500회)

---

## 7. 캐싱 전략

### 7.1 SEO 분석 캐싱

```ruby
# Rails에서 구현
def analyze
  content_hash = Digest::MD5.hexdigest(@blog_post.content)
  cache_key = "seo_analysis:#{content_hash}"

  cached_result = Rails.cache.read(cache_key)
  if cached_result.present?
    return cached_result
  end

  # FastAPI 호출
  result = call_fastapi_analyze()

  # 1시간 캐싱
  Rails.cache.write(cache_key, result, expires_in: 1.hour)

  result
end
```

### 7.2 브라우저 캐싱

```http
Cache-Control: private, max-age=300
ETag: "550e8400-e29b-41d4-a716-446655440000"
```

---

## 8. API 문서

### 8.1 FastAPI 자동 문서

- **Swagger UI**: `http://blog-ai-service:8000/docs`
- **ReDoc**: `http://blog-ai-service:8000/redoc`
- **OpenAPI JSON**: `http://blog-ai-service:8000/openapi.json`

### 8.2 Rails API 문서

Rails YARD 문서 또는 Swagger 젬으로 생성 (선택사항)

---

## 9. 버전 관리

### 9.1 API 버전 전략

**현재**: v1.0 (마이너 버전은 기존 호환성 유지)

**향후 변경 시**:
- 경로 변경: `/api/seo/v2/analyze`
- 응답 구조 변경: 메이저 버전 업데이트

### 9.2 하위 호환성

- 응답에 신규 필드 추가: 기존 클라이언트 호환
- 기존 필드 제거: 금지 (또는 메이저 버전 업데이트)
- 응답 필드 순서 변경: 안전

---

## 10. 보안 고려사항

### 10.1 입력 검증

```python
# FastAPI
from pydantic import BaseModel, Field, validator

class AnalyzeRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=100000)
    title: str = Field(..., min_length=1, max_length=255)
    # ...

    @validator('content')
    def validate_content(cls, v):
        if '<script>' in v.lower():
            raise ValueError('Script tags not allowed')
        return v
```

### 10.2 CORS 설정

```python
# FastAPI
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://legal-scheduler.example.com"],
    allow_methods=["POST"],
    allow_headers=["Content-Type"],
)
```

### 10.3 기밀성

- FastAPI ← → Rails: 내부 네트워크 (VPC)
- Rails ← → 브라우저: HTTPS + CSRF 토큰
- API 키: 환경변수 (secrets)

---

## 11. 모니터링 및 로깅

### 11.1 로깅 포맷

```python
# FastAPI
import logging

logger = logging.getLogger(__name__)

logger.info(f"SEO Analysis: post_id={blog_post_id}, score={score}, duration={duration}s")
logger.error(f"Analysis failed: {error}", exc_info=True)
```

### 11.2 메트릭 수집

- 분석 요청 수 (시간/일 단위)
- 평균 응답 시간
- 에러율
- 사용자별 요청 수

---

## 12. 테스트 데이터

### 12.1 Sample Request

```bash
curl -X POST http://localhost:8000/api/seo/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "content": "기업 소송의 변론일은 법정 공판 기일을 의미합니다.",
    "title": "기업 소송 변론일 관리법",
    "description": null,
    "slug": "변론일-관리법",
    "images": [],
    "internal_links": [],
    "target_keywords": ["변론일", "기업 소송"]
  }'
```

### 12.2 Sample Response

[위의 `/api/seo/analyze` 응답 참조]

---

## 13. 마이그레이션 가이드 (향후)

- **v1.0 → v2.0**: 응답 스키마 확장 (기존 호환)
- **폐지된 엔드포인트**: 6개월 경고 기간 후 제거

---

**작성자**: API Design Lead
**검토자**: Backend Lead, Security Engineer
**마지막 업데이트**: 2026-04-06
