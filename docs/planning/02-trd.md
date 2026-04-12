# 02-trd.md — 기술 요구사항 문서 (TRD)

## 메타 정보
- **프로젝트**: Legal Scheduler AI - SEO 평가 시스템
- **버전**: 1.0
- **작성일**: 2026-04-06
- **담당**: Technical Lead

---

## 1. 개요

SEO 평가 시스템은 **FastAPI (blog-ai 백엔드) + Rails 8 (메인 애플리케이션) + Hotwire (프론트엔드)** 3계층으로 구성된다. 분석 및 재작성 로직은 FastAPI에서 처리하고, 점수 저장 및 UI는 Rails에서 담당한다.

---

## 2. 아키텍처 설계

### 2.1 시스템 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│                    Rails 8 (Main App)                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  BlogPost Model         Blog::SeoController                │
│  ├─ seo_score (int)     ├─ POST /analyze                   │
│  ├─ seo_details (jsonb) ├─ POST /optimize/:item            │
│  └─ ...                 └─ PATCH /apply                    │
│                                                             │
│  Views (Hotwire)        Stimulus Controller                │
│  ├─ blog/show.html.erb  ├─ seo_panel_controller.js         │
│  ├─ _seo_panel.html.erb ├─ seo_comparison_controller.js    │
│  └─ _seo_item.html.erb  └─ ...                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                    HTTP POST (JSON)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│          FastAPI (blog-ai Backend, Python)                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  /api/seo/analyze                                          │
│  ├─ Input: { content, title, description, ... }           │
│  ├─ Process: SEO 평가 계산                                  │
│  └─ Output: { score, items: [...] }                        │
│                                                             │
│  /api/seo/optimize/{item}                                  │
│  ├─ Input: { content, title, target_keywords, ... }       │
│  ├─ Process: Claude AI 재작성 요청                          │
│  └─ Output: { suggested_value, reason }                    │
│                                                             │
│  Claude AI SDK (anthropic-sdk-python)                      │
│  └─ messages.create() with system prompt                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                    HTTP Response (JSON)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│            PostgreSQL 16 (Data Persistence)                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  blog_posts                                                │
│  ├─ id, user_id, title, content, slug                      │
│  ├─ seo_score (NEW)                                        │
│  ├─ seo_details (NEW)                                      │
│  └─ updated_at (triggers SEO re-analysis)                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 정보 흐름

```
1. 사용자가 글 상세 페이지(show) 진입
                    ▼
2. Rails: view 렌더링 + _seo_panel.html.erb 포함
                    ▼
3. Stimulus: seo_panel_controller.js 초기화
                    ▼
4. JavaScript: fetch() → POST /blog_posts/:id/seo/analyze
                    ▼
5. Rails SeoController: 요청 → FastAPI로 프록시
   POST http://localhost:8000/api/seo/analyze
                    ▼
6. FastAPI: 글 내용 분석 → JSON 반환
   { score: 65, items: [{name: "title_keyword", score: 8, ...}, ...] }
                    ▼
7. Rails: 응답을 BlogPost.seo_score, seo_details에 저장
                    ▼
8. Turbo Stream: 패널 UI 업데이트 (새로고침 없음)
                    ▼
9. 사용자: SEO 패널에서 항목 확인 및 "적용" 버튼 클릭
                    ▼
10. Stimulus: 선택한 항목에 대해
    POST /blog_posts/:id/seo/optimize/{item}
                    ▼
11. FastAPI: AI로 재작성 → 제안 값 반환
    { suggested_value: "기업 소송 변론일 일정 관리법", reason: "..." }
                    ▼
12. Rails: 비교 모달 표시 (현재 vs 제안)
                    ▼
13. 사용자: "확인" 클릭 → PATCH /blog_posts/:id/seo/apply
                    ▼
14. Rails: 제안 값을 BlogPost에 저장
                    ▼
15. Turbo Stream: 본문 + 패널 즉시 업데이트
```

---

## 3. API 설계

### 3.1 FastAPI Endpoints

#### POST /api/seo/analyze

**목적**: 글의 SEO 점수 분석

**요청 본문**:
```json
{
  "content": "기업 소송의 변론일은...",
  "title": "기업 소송 변론일 일정 관리법",
  "description": "변론일 일정을 효율적으로 관리하는 방법을 알아보세요.",
  "slug": "변론일-일정-관리법",
  "images": [
    {
      "url": "/uploads/image1.jpg",
      "alt_text": "변론일 달력 예시"
    }
  ],
  "internal_links": [
    {
      "text": "변론일 준비 서면",
      "url": "/blog/변론일-준비-서면"
    }
  ],
  "target_keywords": ["변론일", "기업 소송", "일정 관리"]
}
```

**응답**:
```json
{
  "score": 65,
  "total_points": 100,
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
      "current_value": ["변론일 일정 확인하는 방법", "변론일 준비 서면 작성", "변론일 직후 체크리스트", "변론일 관련 법률 정보"],
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
      "current_value": ["변론일 달력 예시", "(없음)"],
      "suggestion": ["변론일 달력 예시", "기업 소송 변론일 일정 관리 가이드"]
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
    "keyword_optimization": { "score": 25, "max": 40 },
    "technical_seo": { "score": 24, "max": 40 },
    "bonus": { "score": 18, "max": 20 }
  }
}
```

**에러 응답** (400):
```json
{
  "error": "InvalidInput",
  "message": "content가 비어있습니다.",
  "details": {
    "field": "content",
    "value": null
  }
}
```

---

#### POST /api/seo/optimize/{item}

**목적**: 특정 항목에 대한 AI 재작성 제안

**경로 파라미터**:
- `item` (string): 항목 ID (예: `title_keyword`, `meta_description`, `keyword_density`, ...)

**요청 본문**:
```json
{
  "content": "기업 소송의 변론일은...",
  "title": "기업 소송 변론일 일정 관리법과 실무 팁",
  "description": null,
  "slug": "변론일-일정-관리법",
  "target_keywords": ["변론일", "기업 소송", "일정 관리"],
  "item_type": "meta_description"
}
```

**응답**:
```json
{
  "item_id": "meta_description",
  "item_name": "메타 디스크립션",
  "current_value": null,
  "suggested_value": "변론일 일정을 효율적으로 관리하는 방법을 알아보세요.",
  "ai_reasoning": "메타 디스크립션이 없어서 추가했습니다. 80자 이내로 유지하고, 타겟 키워드 '변론일'과 행동 유도(알아보세요)를 포함했습니다.",
  "before": {
    "length": 0,
    "keyword_match": 0
  },
  "after": {
    "length": 34,
    "keyword_match": true,
    "estimated_score_change": "+10점"
  }
}
```

---

### 3.2 Rails Endpoints

#### POST /blog_posts/:id/seo/analyze

**담당**: `Blog::SeoController#analyze`

**동작**:
1. BlogPost 조회
2. FastAPI `/api/seo/analyze` 호출
3. 응답 저장 (seo_score, seo_details)
4. Turbo Stream으로 패널 렌더링

**응답**:
```html
<!-- Turbo Stream MIME type: text/vnd.turbo-stream.html -->
<turbo-stream action="replace" target="seo-panel">
  <template>
    <!-- _seo_panel.html.erb 렌더링 -->
  </template>
</turbo-stream>
```

---

#### POST /blog_posts/:id/seo/optimize/:item

**담당**: `Blog::SeoController#optimize`

**동작**:
1. FastAPI `/api/seo/optimize/{item}` 호출
2. 응답을 JSON으로 반환

**응답**:
```json
{
  "item_id": "meta_description",
  "current_value": null,
  "suggested_value": "변론일 일정을 효율적으로 관리하는 방법을 알아보세요.",
  "ai_reasoning": "..."
}
```

---

#### PATCH /blog_posts/:id/seo/apply

**담당**: `Blog::SeoController#apply`

**동작**:
1. 요청 본문에서 항목ID, 제안값 추출
2. BlogPost 업데이트 (title, description, content, ... 등)
3. SEO 점수 재계산 (FastAPI 호출)
4. Turbo Stream으로 패널 + 본문 즉시 업데이트

**요청 본문**:
```json
{
  "item_id": "meta_description",
  "field_name": "description",
  "new_value": "변론일 일정을 효율적으로 관리하는 방법을 알아보세요."
}
```

**응답**:
```html
<turbo-stream action="replace" target="blog-post-content">
  <template>
    <!-- 업데이트된 본문 -->
  </template>
</turbo-stream>

<turbo-stream action="replace" target="seo-panel">
  <template>
    <!-- 업데이트된 SEO 패널 -->
  </template>
</turbo-stream>
```

---

## 4. 데이터베이스 스키마

### 4.1 BlogPost 모델 변경

```sql
-- 신규 컬럼 추가
ALTER TABLE blog_posts ADD COLUMN seo_score INTEGER DEFAULT NULL;
ALTER TABLE blog_posts ADD COLUMN seo_details JSONB DEFAULT NULL;
ALTER TABLE blog_posts ADD COLUMN seo_analyzed_at TIMESTAMP DEFAULT NULL;

-- 인덱스 추가 (쿼리 성능)
CREATE INDEX idx_blog_posts_seo_score ON blog_posts(seo_score DESC);
```

### 4.2 seo_details 구조 (JSONB)

```json
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
    ...
  ],
  "summary": {
    "keyword_optimization": { "score": 25, "max": 40 },
    "technical_seo": { "score": 24, "max": 40 },
    "bonus": { "score": 18, "max": 20 }
  }
}
```

### 4.3 Rails Migration

```ruby
# db/migrate/[timestamp]_add_seo_fields_to_blog_posts.rb
class AddSeoFieldsToBlogPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :blog_posts, :seo_score, :integer, default: nil
    add_column :blog_posts, :seo_details, :jsonb, default: nil
    add_column :blog_posts, :seo_analyzed_at, :datetime, default: nil

    add_index :blog_posts, :seo_score
  end
end
```

---

## 5. FastAPI 구현 설계

### 5.1 디렉토리 구조

```
python/
├── src/
│   ├── api/
│   │   ├── __init__.py
│   │   ├── main.py              # FastAPI 앱
│   │   └── seo/                 # 신규
│   │       ├── __init__.py
│   │       ├── endpoints.py      # 라우터
│   │       ├── schemas.py        # Pydantic 모델
│   │       └── service.py        # 비즈니스 로직
│   ├── agents/
│   │   ├── seo_analyzer.py       # 신규: SEO 분석 로직
│   │   └── seo_optimizer.py      # 신규: AI 재작성 로직
│   └── ...
└── ...
```

### 5.2 FastAPI 엔드포인트 구현 (의사코드)

```python
# src/api/seo/endpoints.py
from fastapi import APIRouter, HTTPException
from src.api.seo.schemas import AnalyzeRequest, AnalyzeResponse
from src.api.seo.service import SeoService

router = APIRouter(prefix="/api/seo", tags=["seo"])

@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze_seo(request: AnalyzeRequest):
    """글의 SEO 점수 분석"""
    try:
        service = SeoService()
        result = service.analyze(request)
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/optimize/{item}")
async def optimize_item(item: str, request: OptimizeRequest):
    """특정 항목에 대한 AI 재작성 제안"""
    try:
        service = SeoService()
        result = service.optimize(item, request)
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
```

### 5.3 SEO 분석 알고리즘 (의사코드)

```python
# src/agents/seo_analyzer.py
class SeoAnalyzer:
    def analyze(self, content, title, description, slug, images, internal_links, target_keywords):
        results = {
            "score": 0,
            "items": []
        }

        # 1. 키워드 최적화 (40점)
        results["items"].append(self._analyze_title_keyword(title, target_keywords))
        results["items"].append(self._analyze_meta_description(description, target_keywords))
        results["items"].append(self._analyze_keyword_density(content, target_keywords))
        results["items"].append(self._analyze_h2_structure(content, target_keywords))

        # 2. 기술적 SEO (40점)
        results["items"].append(self._analyze_url_slug(slug, target_keywords))
        results["items"].append(self._analyze_image_alt(images, target_keywords))
        results["items"].append(self._analyze_internal_links(internal_links))
        results["items"].append(self._analyze_meta_tags(title, description))

        # 3. 보너스 (20점)
        results["items"].append(self._analyze_content_length(content))
        results["items"].append(self._analyze_readability(content))

        # 총점 계산
        results["score"] = sum(item["score"] for item in results["items"])

        return results

    def _analyze_title_keyword(self, title, target_keywords):
        # 제목이 32자 이내인가?
        # 핵심 키워드가 앞부분에 있는가?
        # 특수문자 과다한가?
        score = 10 if len(title) <= 32 and target_keywords[0] in title[:20] else 8
        return {
            "id": "title_keyword",
            "name": "제목 키워드",
            "category": "keyword_optimization",
            "score": score,
            "max_score": 10,
            "status": "success" if score == 10 else "warning",
            "feedback": "...",
            "current_value": title,
            "suggestion": "..." if score < 10 else None
        }

    # 다른 메서드들...
```

### 5.4 AI 재작성 로직 (Claude SDK 사용)

```python
# src/agents/seo_optimizer.py
from anthropic import Anthropic

class SeoOptimizer:
    def __init__(self):
        self.client = Anthropic()

    def optimize(self, item_id, content, title, description, target_keywords):
        if item_id == "meta_description":
            return self._optimize_meta_description(title, target_keywords)
        elif item_id == "title_keyword":
            return self._optimize_title(title, target_keywords)
        elif item_id == "keyword_density":
            return self._optimize_content_for_keywords(content, target_keywords)
        # ... 다른 항목들

    def _optimize_meta_description(self, title, target_keywords):
        prompt = f"""
        당신은 SEO 전문가입니다.

        다음 제목에 대한 메타 디스크립션을 작성하세요:
        제목: {title}
        타겟 키워드: {', '.join(target_keywords)}

        요구사항:
        1. 80자 이내
        2. 타겟 키워드 포함
        3. 행동 유도 포함 (예: 알아보세요, 배우세요, 확인하세요)
        4. 자연스러운 한국어

        응답 형식:
        <description>여기에 메타 디스크립션</description>
        <reason>왜 이렇게 작성했는지 설명</reason>
        """

        response = self.client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=500,
            messages=[
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        )

        # 응답 파싱
        text = response.content[0].text
        description = self._extract_xml_value(text, "description")
        reason = self._extract_xml_value(text, "reason")

        return {
            "item_id": "meta_description",
            "current_value": None,
            "suggested_value": description,
            "ai_reasoning": reason
        }
```

---

## 6. Rails 구현 설계

### 6.1 컨트롤러 구조

```ruby
# app/controllers/blog/seo_controller.rb
class Blog::SeoController < ApplicationController
  before_action :authenticate_user!
  before_action :set_blog_post

  def analyze
    # 1. FastAPI 호출
    response = SeoService.analyze(@blog_post)

    # 2. 데이터베이스 저장
    @blog_post.update(
      seo_score: response["score"],
      seo_details: response,
      seo_analyzed_at: Time.current
    )

    # 3. Turbo Stream 응답
    respond_to do |format|
      format.turbo_stream
    end
  end

  def optimize
    item = params[:item]

    # 1. FastAPI 호출
    response = SeoService.optimize(@blog_post, item)

    # 2. JSON 응답 (모달에서 사용)
    render json: response
  end

  def apply
    item_id = params[:item_id]
    new_value = params[:new_value]

    # 1. BlogPost 업데이트
    @blog_post.update(field_for_item(item_id) => new_value)

    # 2. SEO 재분석
    analyze_response = SeoService.analyze(@blog_post)
    @blog_post.update(
      seo_score: analyze_response["score"],
      seo_details: analyze_response
    )

    # 3. Turbo Stream 응답
    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def set_blog_post
    @blog_post = current_user.blog_posts.find(params[:blog_post_id])
  end

  def field_for_item(item_id)
    case item_id
    when "meta_description" then :description
    when "title_keyword" then :title
    when "content_*" then :content
    # ...
    end
  end
end
```

### 6.2 Service 클래스

```ruby
# app/services/seo_service.rb
class SeoService
  BASE_URL = ENV.fetch("BLOG_AI_API_URL", "http://localhost:8000")

  def self.analyze(blog_post)
    payload = {
      content: blog_post.content,
      title: blog_post.title,
      description: blog_post.description,
      slug: blog_post.slug,
      images: blog_post.extract_images,
      internal_links: blog_post.extract_internal_links,
      target_keywords: blog_post.extract_keywords
    }

    response = HTTParty.post(
      "#{BASE_URL}/api/seo/analyze",
      body: payload.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    JSON.parse(response.body)
  end

  def self.optimize(blog_post, item)
    payload = {
      content: blog_post.content,
      title: blog_post.title,
      description: blog_post.description,
      slug: blog_post.slug,
      target_keywords: blog_post.extract_keywords,
      item_type: item
    }

    response = HTTParty.post(
      "#{BASE_URL}/api/seo/optimize/#{item}",
      body: payload.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    JSON.parse(response.body)
  end
end
```

---

## 7. 프론트엔드 (Hotwire/Stimulus)

### 7.1 View 구조

```erb
<!-- app/views/blog/posts/show.html.erb -->
<div class="blog-post-container">
  <div class="blog-post-content">
    <!-- 기존 글 내용 -->
    <article id="blog-post-content">
      <h1><%= @blog_post.title %></h1>
      <div class="content"><%= @blog_post.content_html %></div>
    </article>
  </div>

  <!-- SEO 패널 (신규) -->
  <aside id="seo-panel" class="seo-panel" data-controller="seo-panel">
    <%= render "seo_panel", blog_post: @blog_post %>
  </aside>
</div>

<!-- 비교 모달 (신규) -->
<div id="seo-comparison-modal"
     class="modal"
     data-controller="seo-comparison"
     style="display: none;">
  <%= render "seo_comparison_modal" %>
</div>
```

### 7.2 Stimulus 컨트롤러

```javascript
// app/javascript/controllers/seo_panel_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "analyzeBtn", "optimizeBtn"]

  connect() {
    console.log("SEO Panel Controller connected")
    this.analyzeSeo()
  }

  async analyzeSeo() {
    const blogPostId = document.querySelector("[data-blog-post-id]").dataset.blogPostId

    const response = await fetch(`/blog_posts/${blogPostId}/seo/analyze`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      }
    })

    // Turbo Stream 응답 자동 처리
  }

  optimizeItem(event) {
    const itemId = event.target.dataset.itemId
    const blogPostId = document.querySelector("[data-blog-post-id]").dataset.blogPostId

    fetch(`/blog_posts/${blogPostId}/seo/optimize/${itemId}`, {
      method: "POST",
      headers: { "X-CSRF-Token": this.getCSRFToken() }
    })
    .then(r => r.json())
    .then(data => {
      this.showComparisonModal(data)
    })
  }

  showComparisonModal(data) {
    const modal = document.querySelector("#seo-comparison-modal")
    modal.querySelector(".current-value").textContent = data.current_value || "(없음)"
    modal.querySelector(".suggested-value").textContent = data.suggested_value
    modal.querySelector(".ai-reasoning").textContent = data.ai_reasoning
    modal.dataset.itemId = data.item_id
    modal.style.display = "block"
  }

  applyOptimization(event) {
    const modal = document.querySelector("#seo-comparison-modal")
    const itemId = modal.dataset.itemId
    const newValue = modal.querySelector(".suggested-value").textContent
    const blogPostId = document.querySelector("[data-blog-post-id]").dataset.blogPostId

    fetch(`/blog_posts/${blogPostId}/seo/apply`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken()
      },
      body: JSON.stringify({
        item_id: itemId,
        new_value: newValue
      })
    })

    modal.style.display = "none"
  }

  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }
}
```

---

## 8. 배포 및 성능

### 8.1 응답 시간 목표

| 작업 | 목표 | 전략 |
|------|------|------|
| SEO 분석 | 5초 이내 | 비동기 작업 + 캐싱 |
| AI 재작성 제안 | 10초 이내 | 스트리밍 응답 |
| UI 업데이트 | 500ms 이내 | Turbo Stream |

### 8.2 캐싱 전략

```ruby
# 같은 content에 대한 분석 결과 캐싱 (1시간)
content_hash = Digest::MD5.hexdigest(blog_post.content)
cache_key = "seo_analysis:#{content_hash}"
cached_result = Rails.cache.read(cache_key)

if cached_result.nil?
  result = SeoService.analyze(blog_post)
  Rails.cache.write(cache_key, result, expires_in: 1.hour)
end
```

### 8.3 에러 핸들링

```ruby
# FastAPI 연결 실패 시 graceful degradation
begin
  response = SeoService.analyze(blog_post)
rescue StandardError => e
  Rails.logger.error("SEO Analysis failed: #{e.message}")

  # SEO 패널 비활성화 또는 기본값 표시
  @seo_error = "SEO 분석에 일시적 문제가 발생했습니다. 나중에 다시 시도해주세요."
  respond_to do |format|
    format.turbo_stream
  end
end
```

---

## 9. 보안 고려사항

### 9.1 인증/인가
- 블로그 글 작성자만 SEO 패널 접근 가능
- 기존 `authorize_user!` 미들웨어 활용

### 9.2 입력 검증
- FastAPI에서 요청 본문 검증 (Pydantic)
- Rails에서 업데이트 전 권한 확인

### 9.3 CSRF 보호
- Turbo Stream 요청에 X-CSRF-Token 헤더 필수

### 9.4 Rate Limiting
- FastAPI: 분당 최대 10건 분석 요청 (IP별)
- Rails: 사용자별 일일 분석 횟수 제한 (선택사항)

---

## 10. 모니터링 & 로깅

### 10.1 메트릭 수집

```python
# FastAPI - Prometheus 메트릭
from prometheus_client import Counter, Histogram

seo_analyze_duration = Histogram('seo_analyze_duration_seconds', '분석 소요 시간')
seo_optimize_duration = Histogram('seo_optimize_duration_seconds', '재작성 소요 시간')
api_errors = Counter('seo_api_errors_total', 'API 에러 수', ['endpoint'])
```

### 10.2 로그 레벨

```python
# FastAPI
import logging
logger = logging.getLogger(__name__)

logger.info(f"SEO Analysis started: {blog_post_id}")
logger.error(f"Analysis failed: {e}")
```

---

## 11. 외부 의존성

| 라이브러리 | 버전 | 용도 |
|-----------|------|------|
| FastAPI | 0.104+ | API 프레임워크 |
| Pydantic | 2.0+ | 요청/응답 검증 |
| anthropic | 0.25+ | Claude AI SDK |
| httpx | 0.25+ | HTTP 클라이언트 |
| HTTParty | 0.21+ | Rails HTTP 클라이언트 |
| Turbo Rails | 8.0+ | Turbo Stream |
| Stimulus | 3.13+ | JavaScript 프레임워크 |

---

## 12. 다음 단계

1. **API 스펙 검증**: Swagger 문서 생성 (FastAPI 자동 문서)
2. **데이터베이스 마이그레이션**: BlogPost 테이블 수정
3. **단위 테스트**: SEO 분석 알고리즘 테스트 작성
4. **통합 테스트**: Rails ↔ FastAPI 통신 테스트
5. **E2E 테스트**: 사용자 시나리오 기반 테스트

---

**작성자**: Technical Lead
**검토자**: Senior Backend Engineer, Frontend Lead
**마지막 업데이트**: 2026-04-06
