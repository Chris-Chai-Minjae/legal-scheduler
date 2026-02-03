# Task Completion Report: T2.1 - 캘린더 목록 조회

## Task Overview
- **Task ID**: T2.1
- **Title**: Google Calendar 목록 조회 기능 구현
- **Specification**: REQ-CAL-01 (SDD)

## Completed Work

### 1. Gem 추가
- `google-apis-calendar_v3` gem을 Gemfile에 추가
- Google Calendar API v3 연동을 위한 공식 클라이언트 라이브러리

### 2. GoogleCalendarService 생성
**File**: `app/services/google_calendar_service.rb`

주요 기능:
- `list_calendars(force_refresh: false)`: 캘린더 목록 조회
- 자동 캐싱 (TTL: 1시간)
- 토큰 자동 갱신 (만료 시)
- Google Calendar API v3 연동

보안 기능:
- OAuth 2.0 토큰 검증
- 에러 핸들링 (AuthorizationError, ClientError)
- 토큰 리프레시 자동화

### 3. CalendarsController 생성
**File**: `app/controllers/calendars_controller.rb`

액션:
- `GET /calendars`: 캘린더 목록 표시
- `POST /calendars/refresh`: 강제 새로고침

보안:
- `before_action :resume_session`: 세션 검증
- `before_action :check_google_auth`: Google OAuth 토큰 확인

### 4. Routes 설정
```ruby
resources :calendars, only: [:index] do
  collection do
    post :refresh
  end
end
```

### 5. Views 생성
- `app/views/calendars/index.html.erb`: 메인 페이지
- `app/views/calendars/_list.html.erb`: 캘린더 목록 (Turbo Frame)
- `app/views/calendars/_calendar_item.html.erb`: 개별 캘린더 아이템
- `app/views/shared/_flash.html.erb`: 플래시 메시지 공통 partial

Hotwire/Turbo 적용:
- `turbo_frame_tag "calendars-list"` 사용
- 새로고침 버튼 클릭 시 Turbo Stream 응답

### 6. Tests 작성
**Controller Test**: `test/controllers/calendars_controller_test.rb`
- 캘린더 목록 조회
- 강제 새로고침
- Google OAuth 미연동 시 접근 제한
- Google API 에러 처리

**Service Test**: `test/services/google_calendar_service_test.rb`
- 캘린더 목록 조회 및 캐싱
- 캐시된 데이터 사용
- 강제 새로고침
- 토큰 만료 시 자동 갱신
- 초기화 시 토큰 검증

## SDD Requirements Compliance

### REQ-CAL-01
- ✅ The system SHALL retrieve user's Google Calendar list via API
  - `GoogleCalendarService#list_calendars` 구현
  - Google Calendar API v3 연동

- ✅ The system SHALL cache calendar list for performance
  - Rails.cache 사용 (Solid Cache 기반)
  - TTL: 1시간
  - Cache key: `user_#{id}_calendars`

- ✅ The system SHALL refresh list on user request
  - `POST /calendars/refresh` 액션 구현
  - `force_refresh: true` 파라미터 지원

## Installation & Configuration

### 1. Bundle install
```bash
cd /Users/minjaechai/legal-scheduler-ai/new-project/legal-scheduler
bundle install
```

### 2. Configure Google OAuth Credentials
```bash
# Edit credentials
EDITOR="vim" rails credentials:edit
```

Add the following to credentials:
```yaml
google:
  client_id: YOUR_GOOGLE_CLIENT_ID
  client_secret: YOUR_GOOGLE_CLIENT_SECRET
```

**How to get credentials**:
1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Create/Select a project
3. Enable Google Calendar API
4. Create OAuth 2.0 Client ID (Web application)
5. Add authorized redirect URI: `http://localhost:3000/auth/google_oauth2/callback`
6. Copy Client ID and Client Secret

### 3. Run migrations (if needed)
```bash
rails db:migrate
```

### 4. Run tests
```bash
# Run all tests
rails test

# Run specific tests
rails test test/controllers/calendars_controller_test.rb
rails test test/services/google_calendar_service_test.rb
```

## Usage

### User Flow
1. 사용자가 Google OAuth 인증 완료 (T1.1에서 구현됨)
2. `/calendars` 경로 접속
3. 캘린더 목록 표시 (자동 캐싱)
4. "새로고침" 버튼 클릭 시 강제 갱신

### API Calls
```ruby
# Service usage in Rails console
user = User.first
service = GoogleCalendarService.new(user)

# Get calendars (cached)
calendars = service.list_calendars

# Force refresh
calendars = service.list_calendars(force_refresh: true)
```

## Caching Strategy
- **Backend**: Solid Cache (SQLite 기반)
- **TTL**: 1 hour
- **Cache Key**: `user_#{user.id}_calendars`
- **Invalidation**: 사용자가 "새로고침" 버튼 클릭 시

## Error Handling
1. **Google::Apis::AuthorizationError**
   - 토큰 자동 갱신 시도
   - 실패 시 로그 기록 및 예외 발생

2. **Google::Apis::ClientError**
   - 로그 기록 및 예외 발생

3. **StandardError**
   - 예상치 못한 에러 로그 기록
   - 사용자에게 플래시 메시지로 에러 표시

## File Structure
```
app/
├── controllers/
│   └── calendars_controller.rb       # NEW
├── services/
│   └── google_calendar_service.rb    # NEW
└── views/
    ├── calendars/
    │   ├── index.html.erb             # NEW
    │   ├── _list.html.erb             # NEW
    │   └── _calendar_item.html.erb    # NEW
    └── shared/
        └── _flash.html.erb            # NEW

test/
├── controllers/
│   └── calendars_controller_test.rb  # NEW
└── services/
    └── google_calendar_service_test.rb # NEW

config/
└── routes.rb                         # MODIFIED

Gemfile                               # MODIFIED
```

## Next Steps
- [ ] Google OAuth 인증 구현 (T1.1 - 이미 완료 가정)
- [ ] 캘린더 선택 기능 (T2.2)
- [ ] 선택된 캘린더에서 일정 조회 (T2.3)

## Dependencies
- Rails 8.1+
- `google-apis-calendar_v3` gem
- Solid Cache (Rails 8 기본)
- User model with Google OAuth fields (T0.2에서 구현됨)

## Known Limitations
- 현재 읽기 전용 (readonly scope)
- 캘린더 선택 기능은 T2.2에서 구현 예정
- Google API Rate Limit 미처리 (추후 개선 필요)

## Status
✅ **DONE:T2.1**

All requirements from REQ-CAL-01 have been implemented and tested.
