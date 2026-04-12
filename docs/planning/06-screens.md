# 06-screens.md — 화면 명세 및 컴포넌트 목록

## 메타 정보
- **프로젝트**: Legal Scheduler AI - SEO 평가 시스템
- **버전**: 1.0
- **작성일**: 2026-04-06
- **담당**: UI/UX Designer

---

## 1. 화면 목록

| 화면 ID | 화면명 | 타입 | 변경 범위 | 상태 |
|---------|--------|------|---------|------|
| S1 | 블로그 글 목록 | 목록 | 변경 없음 | 기존 |
| S2 | 블로그 글 상세 (신규) | 상세 | 신규 추가 (SEO 패널) | 신규 |
| S3 | 블로그 글 작성/편집 | 양식 | 변경 없음 | 기존 |
| S4 | SEO 비교 모달 | 모달 | 신규 | 신규 |
| S5 | SEO 최적화 진행률 모달 | 모달 | 신규 | 신규 |
| S6 | SEO 분석 오류 모달 | 모달 | 신규 | 신규 |

---

## 2. 주요 화면 상세 설계

### S1: 블로그 글 목록 (index)

**경로**: `GET /blogs` 또는 `GET /blog_posts`

**변경**: 없음 (기존 유지)

**컴포넌트**:
- 글 검색 폼
- 글 필터링 (태그, 작성자, 발행 상태)
- 글 목록 (테이블 또는 카드)
  - 제목
  - 작성자
  - 발행일
  - 조회수
  - 작업 (편집, 삭제)

---

### S2: 블로그 글 상세 (show) - **핵심 화면 신규 변경**

**경로**: `GET /blog_posts/:id`

**상태**: 신규 추가 - SEO 패널

**레이아웃**:
```
┌────────────────────────────────────────────────────────┐
│                      Header (고정)                      │
│  [← Back] "기업 소송 변론일 관리법" [편집] [삭제]      │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────┐  ┌─────────────────┐  │
│  │ 글 본문 (70%)            │  │ SEO 패널 (30%)  │  │
│  │                          │  │ (신규)          │  │
│  │ ┌─────────────────────┐  │  │ ┌─────────────┐ │  │
│  │ │ <h1>제목</h1>       │  │  │ │  SEO 점수   │ │  │
│  │ │ <p>Meta 디스크립션</p>│ │  │ │  65/100     │ │  │
│  │ │ (보이지 않음, head)  │  │  │ └─────────────┘ │  │
│  │ │                     │  │  │ ┌─────────────┐ │  │
│  │ │ <h2>소제목 1</h2>   │  │  │ │ 세부 점수   │ │  │
│  │ │ <p>내용...</p>      │  │  │ │ - 제목: 8/10│ │  │
│  │ │ <img alt="...">     │  │  │ │ [적용]      │ │  │
│  │ │                     │  │  │ │ - 메타: 0/10│ │  │
│  │ │ <h2>소제목 2</h2>   │  │  │ │ [적용]      │ │  │
│  │ │ <p>내용...</p>      │  │  │ │ ...         │ │  │
│  │ │                     │  │  │ ├─────────────┤ │  │
│  │ │ ...                 │  │  │ │[모든 항목   │ │  │
│  │ │                     │  │  │ │ 최적화]     │ │  │
│  │ │                     │  │  │ └─────────────┘ │  │
│  │ │ AI 채팅 (기존)      │  │  │                 │  │
│  │ │ ┌─────────────────┐ │  │  │                 │  │
│  │ │ │ 챗봇 메시지...  │ │  │  │                 │  │
│  │ │ └─────────────────┘ │  │  │                 │  │
│  │ └─────────────────────┘  │  │                 │  │
│  │                          │  │                 │  │
│  └──────────────────────────┘  └─────────────────┘  │
│                                                        │
├────────────────────────────────────────────────────────┤
│                      Footer (고정)                      │
│ [공유] [좋아요] [댓글]                                 │
└────────────────────────────────────────────────────────┘
```

**데스크톱 (1200px 이상)**:
- 본문: 70% (좌측)
- SEO 패널: 30% (우측, 고정 사이드바)

**태블릿 (768px ~ 1199px)**:
- 본문: 전체 너비
- SEO 패널: 하단 드로어 또는 토글 가능

**모바일 (< 768px)**:
- 본문: 전체 너비
- SEO 패널: 하단 플로팅 FAB → 전체 화면 모달

**컴포넌트 트리**:

```
<div class="blog-post-container">
  <!-- 기존 헤더 -->
  <header class="blog-post-header">
    <a href="/blogs" class="back-link">← Back</a>
    <h1 class="post-title"><%= @blog_post.title %></h1>
    <div class="actions">
      <a href="..." class="btn-edit">편집</a>
      <a href="..." class="btn-delete">삭제</a>
    </div>
  </header>

  <!-- 메인 콘텐츠 -->
  <div class="blog-post-content-wrapper">
    <!-- 기존 글 내용 -->
    <article class="blog-post-content" id="blog-post-content">
      <!-- Meta 태그 (head에 포함, 보이지 않음) -->
      <h1><%= @blog_post.title %></h1>
      <meta name="description" content="<%= @blog_post.description %>" />
      <meta property="og:title" content="..." />
      <!-- ... -->

      <div class="post-body">
        <%= render_markdown(@blog_post.content) %>
      </div>
    </article>

    <!-- SEO 패널 (신규) -->
    <aside id="seo-panel" class="seo-panel" data-controller="seo-panel">
      <%= render "seo_panel", blog_post: @blog_post %>
    </aside>
  </div>

  <!-- AI 채팅 (기존) -->
  <section class="ai-chat" data-controller="ai-chat">
    <%= render "ai_chat", blog_post: @blog_post %>
  </section>

  <!-- 기존 푸터 -->
  <footer class="blog-post-footer">
    <!-- 공유, 좋아요, 댓글 -->
  </footer>
</div>

<!-- 비교 모달 (신규) -->
<div id="seo-comparison-modal" class="modal" data-controller="seo-comparison">
  <%= render "seo_comparison_modal" %>
</div>

<!-- 최적화 진행률 모달 (신규) -->
<div id="seo-progress-modal" class="modal" data-controller="seo-progress">
  <%= render "seo_progress_modal" %>
</div>
```

---

### S3: 블로그 글 작성/편집 (new/edit)

**경로**: `GET/POST /blog_posts/new`, `GET/PATCH /blog_posts/:id/edit`

**변경**: 없음 (기존 유지)

---

### S4: SEO 비교 모달 (새로운 컴포넌트)

**시나리오**: 사용자가 SEO 패널에서 항목의 [적용] 버튼 클릭

**트리거**: JavaScript 이벤트 → FastAPI 호출 → 모달 표시

**컴포넌트**:

```erb
<!-- app/views/blog/posts/_seo_comparison_modal.html.erb -->
<div class="seo-comparison-modal-overlay" id="seo-comparison-overlay">
  <div class="seo-comparison-modal">
    <!-- 헤더 -->
    <div class="modal-header">
      <h2 id="seo-item-name">메타 디스크립션</h2>
      <button class="btn-close" data-action="click->seo-comparison#close">×</button>
    </div>

    <!-- 현재 값 -->
    <div class="modal-section">
      <label class="section-title">현재 값</label>
      <div class="value-box current-value">
        <span id="current-value">(없음)</span>
        <span class="meta-info" id="current-meta"></span>
      </div>
    </div>

    <!-- 구분선 -->
    <div class="divider">▼ ▼ ▼</div>

    <!-- 제안된 값 -->
    <div class="modal-section">
      <label class="section-title">제안된 값</label>
      <div class="value-box suggested-value">
        <span id="suggested-value"></span>
        <span class="meta-info" id="suggested-meta"></span>
      </div>
    </div>

    <!-- AI 설명 -->
    <div class="modal-section">
      <label class="section-title">AI 설명</label>
      <div class="explanation-box">
        <p id="ai-reasoning"></p>
      </div>
    </div>

    <!-- 버튼 -->
    <div class="modal-actions">
      <button class="btn btn-secondary" data-action="click->seo-comparison#close">
        취소
      </button>
      <button class="btn btn-primary" data-action="click->seo-comparison#apply">
        확인 및 적용
      </button>
    </div>
  </div>
</div>
```

**스타일링**:
```css
.seo-comparison-modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.seo-comparison-modal {
  background: white;
  border-radius: 8px;
  padding: 24px;
  width: 90%;
  max-width: 600px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
  max-height: 80vh;
  overflow-y: auto;
}

.value-box {
  background: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 6px;
  padding: 12px;
  line-height: 1.5;
  word-wrap: break-word;
}

.current-value {
  background: #fff3cd;
  border-color: #ffc107;
}

.suggested-value {
  background: #d4edda;
  border-color: #28a745;
}

.divider {
  text-align: center;
  color: #999;
  margin: 16px 0;
  font-size: 12px;
}
```

---

### S5: SEO 최적화 진행률 모달

**시나리오**: 사용자가 [모든 항목 최적화] 버튼 클릭

**컴포넌트**:

```erb
<!-- app/views/blog/posts/_seo_progress_modal.html.erb -->
<div class="seo-progress-modal-overlay">
  <div class="seo-progress-modal">
    <h2>최적화 진행 중</h2>

    <!-- 진행률 바 -->
    <div class="progress-container">
      <div class="progress-info">
        <span id="progress-count">1/8</span>
        <span id="progress-percent">12.5%</span>
      </div>
      <div class="progress-bar">
        <div class="progress-fill" id="progress-fill" style="width: 12.5%"></div>
      </div>
    </div>

    <!-- 현재 처리 항목 -->
    <div class="current-item">
      <p id="current-item-name">
        <span class="spinner"></span>
        제목 키워드 최적화 중...
      </p>
    </div>

    <!-- 완료된 항목 목록 -->
    <div class="completed-items">
      <h3>완료된 항목</h3>
      <ul id="completed-list">
        <li><span class="icon-success">✓</span> 메타 디스크립션 (완료)</li>
        <li><span class="icon-success">✓</span> 키워드 밀도 (완료)</li>
      </ul>
    </div>

    <!-- 대기 중인 항목 목록 -->
    <div class="pending-items">
      <h3>대기 중인 항목</h3>
      <ul id="pending-list">
        <li><span class="icon-pending">○</span> H2 소제목</li>
        <li><span class="icon-pending">○</span> URL 슬러그</li>
        <!-- ... -->
      </ul>
    </div>

    <!-- 취소 버튼 -->
    <div class="modal-actions">
      <button class="btn btn-secondary" data-action="click->seo-progress#cancel">
        취소
      </button>
    </div>
  </div>
</div>
```

---

### S6: SEO 분석 오류 모달

**시나리오**: FastAPI 호출 실패 또는 타임아웃

**컴포넌트**:

```erb
<!-- app/views/blog/posts/_seo_error_modal.html.erb -->
<div class="seo-error-modal-overlay">
  <div class="seo-error-modal">
    <div class="modal-header error">
      <span class="icon-error">⚠️</span>
      <h2>SEO 분석 오류</h2>
    </div>

    <div class="modal-body">
      <p id="error-message">분석 중 일시적 오류가 발생했습니다.</p>
      <p class="help-text">잠시 후 다시 시도해주세요.</p>
    </div>

    <div class="modal-actions">
      <button class="btn btn-secondary" data-action="click->seo-error#close">
        나중에
      </button>
      <button class="btn btn-primary" data-action="click->seo-error#retry">
        다시 시도
      </button>
    </div>
  </div>
</div>
```

---

## 3. SEO 패널 상세 설계

### 3.1 패널 전체 구조

```erb
<!-- app/views/blog/posts/_seo_panel.html.erb -->
<aside id="seo-panel" class="seo-panel">
  <!-- 점수 게이지 섹션 -->
  <%= render "seo_panel/score_gauge", blog_post: @blog_post %>

  <!-- 세부 항목 섹션 -->
  <div class="seo-items">
    <!-- 키워드 최적화 -->
    <%= render "seo_panel/category_section",
               category: "keyword_optimization",
               title: "키워드 최적화",
               max_score: 40,
               items: @blog_post.seo_details["items"].select { |i| i["category"] == "keyword_optimization" },
               seo_details: @blog_post.seo_details %>

    <!-- 기술적 SEO -->
    <%= render "seo_panel/category_section",
               category: "technical_seo",
               title: "기술적 SEO",
               max_score: 40,
               items: @blog_post.seo_details["items"].select { |i| i["category"] == "technical_seo" },
               seo_details: @blog_post.seo_details %>

    <!-- 보너스 -->
    <%= render "seo_panel/category_section",
               category: "bonus",
               title: "보너스",
               max_score: 20,
               items: @blog_post.seo_details["items"].select { |i| i["category"] == "bonus" },
               seo_details: @blog_post.seo_details %>
  </div>

  <!-- 액션 버튼 -->
  <div class="seo-actions">
    <button class="btn btn-block btn-primary"
            data-action="click->seo-panel#optimizeAll"
            id="optimize-all-btn">
      모든 항목 최적화
    </button>
  </div>
</aside>
```

### 3.2 점수 게이지 컴포넌트

```erb
<!-- app/views/blog/posts/_seo_panel/score_gauge.html.erb -->
<div class="score-gauge-section">
  <h3>SEO 점수</h3>

  <!-- SVG 원형 게이지 -->
  <div class="score-gauge">
    <svg viewBox="0 0 100 100" class="gauge-svg">
      <!-- 배경 원 -->
      <circle cx="50" cy="50" r="45" fill="none" stroke="#e0e0e0" stroke-width="8" />
      <!-- 채워진 원 -->
      <circle cx="50" cy="50" r="45" fill="none"
              stroke-dasharray="<%= (blog_post.seo_score / 100.0 * 282.7).to_i %> 282.7"
              stroke="<%= color_for_score(blog_post.seo_score) %>"
              stroke-width="8"
              transform="rotate(-90 50 50)" />
      <!-- 텍스트 -->
      <text x="50" y="50" text-anchor="middle" dy="0.3em" class="gauge-text">
        <tspan x="50" dy="0">
          <tspan class="gauge-score"><%= blog_post.seo_score %></tspan>
          <tspan class="gauge-max">/100</tspan>
        </tspan>
      </text>
    </svg>
  </div>

  <!-- 개선도 표시 (선택사항) -->
  <% if blog_post.seo_score.present? %>
    <p class="improvement-text">
      <%= icon_for_change(previous_score, blog_post.seo_score) %>
      <%= change_text(previous_score, blog_post.seo_score) %>
    </p>
  <% end %>
</div>
```

### 3.3 카테고리 섹션 컴포넌트

```erb
<!-- app/views/blog/posts/_seo_panel/category_section.html.erb -->
<div class="category-section" data-category="<%= category %>">
  <!-- 헤더 -->
  <div class="category-header" data-toggle="<%= category %>">
    <span class="toggle-icon">▼</span>
    <span class="category-title"><%= title %></span>
    <span class="category-score">
      <%= items.sum { |i| i["score"] } %>/<%= max_score %>
    </span>
  </div>

  <!-- 항목 목록 -->
  <div class="category-items" id="category-<%= category %>">
    <% items.each do |item| %>
      <%= render "seo_panel/item", item: item, blog_post_id: blog_post.id %>
    <% end %>
  </div>
</div>
```

### 3.4 개별 항목 컴포넌트

```erb
<!-- app/views/blog/posts/_seo_panel/item.html.erb -->
<div class="seo-item" data-item-id="<%= item["id"] %>">
  <!-- 항목 헤더 -->
  <div class="item-header">
    <span class="item-icon" id="icon-<%= item["id"] %>">
      <%= icon_for_status(item["status"]) %>
    </span>
    <span class="item-name"><%= item["name"] %></span>
    <span class="item-score" style="color: <%= color_for_score(item["score"]) %>">
      <%= item["score"] %>/<%= item["max_score"] %>
    </span>
  </div>

  <!-- 피드백 -->
  <p class="item-feedback">
    <%= item["feedback"] %>
  </p>

  <!-- [적용] 버튼 -->
  <button class="btn btn-sm btn-secondary"
          data-action="click->seo-panel#optimizeItem"
          data-item-id="<%= item["id"] %>"
          id="btn-<%= item["id"] %>">
    [적용]
  </button>
</div>
```

---

## 4. 반응형 레이아웃

### 4.1 데스크톱 (1200px 이상)

```css
.blog-post-content-wrapper {
  display: grid;
  grid-template-columns: 1fr 350px;
  gap: 24px;
}

.seo-panel {
  position: sticky;
  top: 100px; /* 헤더 높이 */
  height: fit-content;
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 16px;
  background: white;
}
```

### 4.2 태블릿 (768px ~ 1199px)

```css
.blog-post-content-wrapper {
  display: block;
}

.seo-panel {
  margin-top: 32px;
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 16px;
  background: #f9f9f9;
}
```

### 4.3 모바일 (< 768px)

```css
.seo-panel {
  display: none; /* 숨김 */
}

.seo-fab {
  position: fixed;
  bottom: 20px;
  right: 20px;
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background: #007bff;
  color: white;
  font-size: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  z-index: 100;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
}

.seo-fab:active {
  /* 모달 전체 화면으로 표시 */
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  width: 100%;
  height: 100%;
  border-radius: 0;
}
```

---

## 5. Stimulus Controller 목록

| Controller | 역할 | 메서드 |
|-----------|------|--------|
| seo-panel | SEO 패널 관리 | `connect()`, `analyzeSeo()`, `optimizeItem()`, `optimizeAll()` |
| seo-comparison | 비교 모달 표시 | `show()`, `apply()`, `close()` |
| seo-progress | 진행률 모달 | `show()`, `cancel()`, `updateProgress()` |
| seo-error | 오류 모달 | `show()`, `close()`, `retry()` |

---

## 6. 상태 관리

### 6.1 SEO 패널 상태

```javascript
// Stimulus Controller 내부
export default class extends Controller {
  states = {
    idle: 'idle',              // 초기 상태
    analyzing: 'analyzing',    // 분석 중
    analyzed: 'analyzed',      // 분석 완료
    optimizing: 'optimizing',  // 최적화 중
    error: 'error'             // 오류 발생
  }

  currentState = this.states.idle
}
```

### 6.2 로딩 상태 표시

```
idle        → [분석하기] 버튼 활성화
  ↓
analyzing   → [분석 중...] 버튼 비활성화 + 스피너
  ↓
analyzed    → 점수 + 항목 목록 표시
  ↓
optimizing  → [적용] 버튼 비활성화 + 로딩
  ↓
error       → 오류 메시지 + [다시 시도] 버튼
```

---

## 7. 색상 및 스타일 가이드

### 7.1 점수별 색상

```css
.score-success { color: #28a745; }    /* 70~100: 초록색 */
.score-warning { color: #ffc107; }    /* 40~69: 노란색 */
.score-error   { color: #dc3545; }    /* 0~39: 빨간색 */
```

### 7.2 상태 아이콘

- ✓ 성공 (success)
- ⚠️ 경고 (warning)
- ✗ 오류 (error)
- ◐ 부분 (partial)

### 7.3 버튼 스타일

- 주 버튼 (Primary): 파란색 배경, 흰색 텍스트
- 보조 버튼 (Secondary): 회색 배경, 검은색 텍스트
- 위험 버튼 (Danger): 빨간색 배경, 흰색 텍스트 (선택사항)

---

## 8. 애니메이션 & 전환

### 8.1 항목 확장/축소

```css
.category-items {
  max-height: 500px;
  overflow: hidden;
  transition: max-height 0.3s ease-in-out;
}

.category-items.collapsed {
  max-height: 0;
}
```

### 8.2 점수 게이지 애니메이션

```css
.gauge-circle {
  stroke-dashoffset: 282.7;
  transition: stroke-dashoffset 0.5s ease-in-out;
}
```

### 8.3 모달 fade-in

```css
.modal-overlay {
  opacity: 0;
  transition: opacity 0.2s ease-in-out;
}

.modal-overlay.visible {
  opacity: 1;
}
```

---

## 9. 접근성 (a11y)

### 9.1 ARIA 속성

```html
<!-- SEO 패널 -->
<aside role="region" aria-label="SEO 점수 패널">
  <!-- 점수 -->
  <div role="progressbar"
       aria-valuenow="65"
       aria-valuemin="0"
       aria-valuemax="100"
       aria-label="SEO 점수: 65점">
    ...
  </div>

  <!-- 카테고리 -->
  <div role="region" aria-label="키워드 최적화 세부사항">
    ...
  </div>
</aside>
```

### 9.2 키보드 네비게이션

- Tab: 다음 버튼 이동
- Shift+Tab: 이전 버튼 이동
- Enter/Space: 버튼 활성화
- Esc: 모달 닫기

### 9.3 스크린 리더 호환성

- 모든 버튼에 aria-label 추가
- 아이콘에는 aria-hidden="true" 또는 aria-label 추가
- 점수 변화 시 aria-live="polite" 영역에 알림

---

## 10. 에러 상태 디자인

### 10.1 분석 실패

```
┌─────────────────────────────┐
│ ⚠️ SEO 분석 실패             │
├─────────────────────────────┤
│ 분석 중 일시적 오류가 발생   │
│ 잠시 후 다시 시도해주세요.  │
│                             │
│ [다시 시도] [닫기]          │
└─────────────────────────────┘
```

### 10.2 네트워크 오류

```
SEO 점수: 로딩 불가 (오프라인)
[분석 다시 시도]
```

### 10.3 타임아웃

```
⏳ 분석 중... (약 3초)
시간이 오래 걸리고 있습니다.
[계속 기다리기] [취소]
```

---

## 11. 테스트 시나리오별 화면 흐름

### 테스트 케이스 1: 신규 글 분석

```
show 페이지 로드
  ↓
SEO 패널 자동 로드 (분석 중...)
  ↓
분석 완료 (점수 표시)
  ↓
사용자가 항목 [적용] 버튼 클릭
  ↓
비교 모달 표시
  ↓
[확인] 클릭 → 본문 + 패널 업데이트
```

### 테스트 케이스 2: 전체 최적화

```
[모든 항목 최적화] 클릭
  ↓
확인 모달
  ↓
진행률 모달 (1/8)
  ↓
각 항목 순차 처리
  ↓
완료 모달 (85/100)
```

---

**작성자**: UI/UX Designer
**검토자**: Product Manager, Frontend Lead
**마지막 업데이트**: 2026-04-06
