# Blog AI UI Controllers

> Phase 2, 태스크 P2-S0-T1에서 생성된 Stimulus 컨트롤러들

## 📦 컨트롤러 목록

### 1. ai_chat_controller.js
AI 채팅 패널 - SSE 스트리밍 지원

**데이터 속성:**
- `data-controller="ai-chat"`
- `data-ai-chat-url-value="<%= blog_post_chats_path(@post) %>"`

**타겟:**
- `messages` - 채팅 메시지 영역
- `input` - 입력 필드
- `form` - 폼 요소
- `status` - 상태 표시

**액션:**
- `toggle()` - 패널 열기/닫기
- `send(event)` - 메시지 전송

**사용 예시:**
```erb
<%= render "blog/posts/ai_chat", post: @post %>

<button data-action="click->ai-chat#toggle">
  💬 AI와 대화
</button>
```

---

### 2. streaming_controller.js
실시간 텍스트 스트리밍 - 글 생성 시

**데이터 속성:**
- `data-controller="streaming"`
- `data-streaming-url-value="<%= generate_blog_post_path %>"`

**타겟:**
- `output` - 텍스트 출력 영역
- `cursor` - 커서 요소
- `status` - 상태 메시지

**액션:**
- `start(event)` - 스트리밍 시작

**사용 예시:**
```erb
<div data-controller="streaming"
     data-streaming-url-value="<%= generate_blog_post_path %>">

  <div data-streaming-target="output"></div>
  <span data-streaming-target="cursor" class="streaming-cursor"></span>

  <%= form_with url: generate_blog_post_path do |f| %>
    <%= f.text_area :prompt %>
    <button data-action="click->streaming#start">
      ✨ 글 생성
    </button>
  <% end %>
</div>
```

---

### 3. file_upload_controller.js
드래그앤드롭 파일 업로드 (PDF/DOCX/HWP)

**데이터 속성:**
- `data-controller="file-upload"`
- `data-file-upload-max-size-value="52428800"` (50MB, 옵션)
- `data-file-upload-allowed-types-value='["application/pdf", ...]'` (옵션)

**타겟:**
- `dropzone` - 드롭 영역
- `input` - 파일 input
- `preview` - 미리보기 영역
- `progress` - 진행 표시

**액션:**
- `dragover(event)` - 드래그 중
- `dragleave(event)` - 드래그 벗어남
- `drop(event)` - 드롭
- `select(event)` - 파일 선택
- `remove(event)` - 파일 제거

**사용 예시:**
```erb
<%= form_with model: @blog_document,
              data: { controller: "file-upload" } do |f| %>

  <div data-file-upload-target="dropzone"
       data-action="dragover->file-upload#dragover
                    dragleave->file-upload#dragleave
                    drop->file-upload#drop"
       class="file-dropzone">
    <div class="file-dropzone-icon">📁</div>
    <p>파일을 드래그하거나 클릭하세요</p>
  </div>

  <%= f.file_field :file,
                   data: {
                     file_upload_target: "input",
                     action: "change->file-upload#select"
                   },
                   style: "display: none;" %>

  <div data-file-upload-target="preview"></div>
<% end %>
```

**허용 파일:**
- PDF (application/pdf)
- DOCX (application/vnd.openxmlformats-officedocument.wordprocessingml.document)
- HWP (application/x-hwp, application/haansofthwp)

**최대 크기:** 50MB

---

### 4. blog_editor_controller.js
인라인 에디터 - contenteditable + 자동저장

**데이터 속성:**
- `data-controller="blog-editor"`
- `data-blog-editor-post-id-value="<%= @post.id %>"`
- `data-blog-editor-save-url-value="<%= blog_post_path(@post) %>"`
- `data-blog-editor-debounce-value="2000"` (옵션, 기본 2초)

**타겟:**
- `title` - 제목 요소
- `content` - 내용 요소
- `status` - 저장 상태 표시

**액션:**
- `contentChanged()` - 내용 변경 감지
- `save()` - 수동 저장
- `copy()` - 클립보드 복사
- `preventLineBreak(event)` - 제목에서 Enter 방지

**사용 예시:**
```erb
<div data-controller="blog-editor"
     data-blog-editor-post-id-value="<%= @post.id %>"
     data-blog-editor-save-url-value="<%= blog_post_path(@post) %>">

  <h1 contenteditable="true"
      data-blog-editor-target="title"
      data-action="input->blog-editor#contentChanged
                   keydown->blog-editor#preventLineBreak">
    <%= @post.title %>
  </h1>

  <div contenteditable="true"
       data-blog-editor-target="content"
       data-action="input->blog-editor#contentChanged"
       class="blog-editor-content">
    <%= @post.content %>
  </div>

  <button data-action="click->blog-editor#copy">
    📋 복사
  </button>

  <div data-blog-editor-target="status" class="blog-editor-status"></div>
</div>
```

**자동저장 동작:**
1. 사용자가 타이핑 → `contentChanged()` 호출
2. 2초 디바운스 타이머 시작
3. 타이머 완료 → PATCH 요청 → 상태 표시

---

## 🎨 CSS 클래스

`blog.css`에서 사용 가능한 주요 클래스:

### 컨테이너
- `.blog-header` - 페이지 헤더
- `.blog-cards` - 카드 그리드
- `.blog-card` - 개별 카드

### 에디터
- `.blog-editor` - 편집기 컨테이너
- `.blog-editor-title` - 제목 (contenteditable)
- `.blog-editor-content` - 내용 (contenteditable)
- `.blog-editor-status` - 상태 표시

### AI 채팅
- `.ai-chat-panel` - 채팅 패널 (우측 슬라이딩)
- `.ai-chat-panel.open` - 열린 상태
- `.ai-chat-messages` - 메시지 영역
- `.ai-chat-message` - 개별 메시지
- `.ai-chat-input` - 입력 필드

### 파일 업로드
- `.file-dropzone` - 드롭 영역
- `.file-dropzone.dragover` - 드래그 중
- `.file-preview` - 미리보기 영역
- `.file-preview-item` - 개별 파일

### 상태 뱃지
- `.blog-status-badge.draft` - 임시저장
- `.blog-status-badge.generating` - 생성 중 (펄스 애니메이션)
- `.blog-status-badge.completed` - 완료
- `.blog-status-badge.published` - 발행됨

### 스트리밍
- `.streaming-cursor` - 깜빡이는 커서
- `.streaming-text` - 스트리밍 텍스트 영역

---

## 🔧 기술 스택

- **Rails 8** + **Hotwire** (Turbo 8 + Stimulus)
- **Propshaft** (Asset Pipeline)
- **SSE** (Server-Sent Events)
- **contenteditable** (인라인 편집)
- **Fetch API** + **ReadableStream** (SSE 스트리밍)

---

## 📱 반응형

모든 컴포넌트는 `@media (max-width: 768px)`에서 모바일 최적화됨:

- AI 채팅 패널: 전체 너비 (400px → 100%)
- 블로그 카드: 1열 그리드
- 톤/길이 선택: 세로 배치

---

## 🚀 다음 단계

### 백엔드 연동 (P2-S0-T2)
- `Blog::ChatsController#create` - SSE 응답
- `Blog::PostsController#generate` - 스트리밍 생성
- `Blog::DocumentsController#create` - 파일 처리

### FastAPI 프록시 (P2-S0-T3)
- ActionController::Live로 SSE 프록시
- `/blog/chat` → FastAPI
- `/blog/generate` → FastAPI

---

**생성일:** 2026-02-07
**태스크:** P2-S0-T1
**담당:** frontend-specialist
