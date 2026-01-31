# Database Schema Documentation

## Overview

This document describes the database schema for Legal Scheduler AI, based on SDD specifications (REQ-AUTH-01 through REQ-SET-06).

## Migrations Summary

All migrations are located in `db/migrate/` and follow Rails 8.1 conventions.

### Migration Timeline

| Timestamp | Migration | Description |
|-----------|-----------|-------------|
| 20260131072955 | CreateUsers | Rails authentication (email, password) |
| 20260131072956 | CreateSessions | Rails session management |
| 20260131073001 | AddGoogleAndTelegramToUsers | OAuth and Telegram integration |
| 20260131073002 | CreateCalendars | Google Calendar management |
| 20260131073003 | CreateSchedules | Writing deadline scheduling |
| 20260131073004 | CreateKeywords | Calendar event filtering |
| 20260131073005 | CreateSettings | User preferences |

## Database Tables

### 1. users (Rails Authentication)

**Path:** `db/migrate/20260131072955_create_users.rb`

Base authentication table with OAuth and Telegram extensions.

**Columns:**
- `id` (bigint, PK)
- `email_address` (string, unique, required) - User's email
- `password_digest` (string, required) - bcrypt hash
- `google_access_token` (text, encrypted) - Google OAuth access token (REQ-AUTH-03)
- `google_refresh_token` (text, encrypted) - Google OAuth refresh token (REQ-AUTH-03)
- `google_token_expires_at` (datetime) - Token expiration time
- `telegram_chat_id` (string, unique nullable) - Telegram user ID (REQ-AUTH-04)
- `telegram_bot_token` (string, encrypted) - Telegram bot API token (REQ-AUTH-04)
- `created_at` (datetime)
- `updated_at` (datetime)

**Indexes:**
- `users_email_address_unique` - Unique email constraint
- `users_telegram_chat_id_unique` - Unique Telegram chat ID (nullable)

**Associations:**
- `has_many :sessions` (Rails built-in)
- `has_many :calendars`
- `has_many :schedules` (through: calendars)
- `has_many :keywords`
- `has_one :settings`

**Model File:** `app/models/user.rb`

**Encryption:**
- Uses Rails 8.1 built-in encryption: `encrypts :google_access_token`
- Sensitive fields: google_access_token, google_refresh_token, telegram_bot_token

---

### 2. calendars

**Path:** `db/migrate/20260131073002_create_calendars.rb`

Google Calendar integration (REQ-CAL-01, REQ-CAL-02)

**Columns:**
- `id` (bigint, PK)
- `user_id` (bigint, FK) - Reference to users
- `google_id` (string, required) - Google Calendar ID
- `calendar_type` (integer) - Enum: 0=lbox, 1=work, 2=personal
- `name` (string) - Calendar display name
- `color` (string) - Calendar color code
- `created_at` (datetime)
- `updated_at` (datetime)

**Indexes:**
- `calendars_user_id_google_id_unique` - Unique per user
- `calendars_calendar_type` - For filtering by type

**Associations:**
- `belongs_to :user`
- `has_many :schedules`

**Model File:** `app/models/calendar.rb`

**Enums:**
```ruby
enum :calendar_type, { lbox: 0, work: 1, personal: 2 }
```

---

### 3. schedules

**Path:** `db/migrate/20260131073003_create_schedules.rb`

Writing deadline management (REQ-SCHED-01 through REQ-SCHED-06)

**Columns:**
- `id` (bigint, PK)
- `calendar_id` (bigint, FK) - Reference to calendars
- `title` (string, required) - Format: `[업무] {case_number} {case_name} 서면작성`
- `case_number` (string) - Case number from original event
- `case_name` (string) - Case name from original event
- `original_date` (date, required) - Court date (변론일)
- `scheduled_date` (date, required) - Writing deadline (서면작성일)
- `status` (integer) - Enum: 0=pending, 1=approved, 2=rejected (REQ-SCHED-05)
- `original_event_id` (string, unique nullable) - Google Calendar event ID of court date (REQ-SCHED-06)
- `created_event_id` (string, unique nullable) - Google Calendar event ID of writing deadline
- `created_at` (datetime)
- `updated_at` (datetime)

**Indexes:**
- `schedules_calendar_id_original_date` - Calendar + date lookup
- `schedules_original_event_id_unique` - Prevent duplicate scheduling (REQ-SCHED-06)
- `schedules_created_event_id_unique` - Track created events
- `schedules_status` - Filter by status
- `schedules_scheduled_date` - Upcoming deadline queries

**Associations:**
- `belongs_to :calendar`
- `has_one :user` (through: calendar)

**Model File:** `app/models/schedule.rb`

**Enums:**
```ruby
enum :status, { pending: 0, approved: 1, rejected: 2 }
```

**Scopes:**
- `.pending_approval` - Pending approval (status: pending)
- `.approved` - Approved schedules
- `.rejected` - Rejected schedules
- `.upcoming` - Future schedules
- `.by_calendar(id)` - Filter by calendar

---

### 4. keywords

**Path:** `db/migrate/20260131073004_create_keywords.rb`

Calendar event filtering keywords (REQ-SET-01)

**Columns:**
- `id` (bigint, PK)
- `user_id` (bigint, FK) - Reference to users
- `keyword` (string, required) - Filter keyword
- `is_active` (boolean, default: true) - Active status
- `created_at` (datetime)
- `updated_at` (datetime)

**Indexes:**
- `keywords_user_id_keyword_unique` - Unique per user
- `keywords_is_active` - Filter active keywords

**Associations:**
- `belongs_to :user`

**Model File:** `app/models/keyword.rb`

**Scopes:**
- `.active` - Active keywords only
- `.inactive` - Inactive keywords only

---

### 5. settings

**Path:** `db/migrate/20260131073005_create_settings.rb`

User preferences and scheduling rules (REQ-SET-02 through REQ-SET-06)

**Columns:**
- `id` (bigint, PK)
- `user_id` (bigint, FK, unique) - Reference to users
- `alert_time` (time, default: "08:00") - Daily notification time (REQ-SET-02)
- `max_per_week` (integer, default: 3) - Max schedules per week (REQ-SET-03)
- `lead_days` (integer, default: 14) - Days before court date to schedule (REQ-SET-04)
- `exclude_weekends` (boolean, default: true) - Skip weekend scheduling (REQ-SET-05)
- `created_at` (datetime)
- `updated_at` (datetime)

**Indexes:**
- `settings_user_id_unique` - One settings per user

**Associations:**
- `belongs_to :user`

**Model File:** `app/models/settings.rb`

**Auto-Creation:**
- Settings are automatically created when a user is created (via `after_create` callback)

---

## Data Model Relationships

```
User (1)
  ├── has_many Sessions
  ├── has_many Calendars
  │   └── has_many Schedules
  ├── has_many Schedules (through Calendars)
  ├── has_many Keywords
  └── has_one Settings
```

## REQ Mapping

| Requirement | Table | Column(s) | Status |
|-------------|-------|-----------|--------|
| REQ-AUTH-01 | users | email_address | ✅ |
| REQ-AUTH-02 | users | password_digest | ✅ |
| REQ-AUTH-03 | users | google_{access,refresh}_token | ✅ |
| REQ-AUTH-04 | users | telegram_chat_id, telegram_bot_token | ✅ |
| REQ-CAL-01 | calendars | google_id, user_id | ✅ |
| REQ-CAL-02 | calendars | calendar_type (enum) | ✅ |
| REQ-SCHED-01 | schedules | title | ✅ |
| REQ-SCHED-02 | schedules | case_number, case_name | ✅ |
| REQ-SCHED-03 | schedules | original_date, scheduled_date | ✅ |
| REQ-SCHED-04 | schedules | calendar_id | ✅ |
| REQ-SCHED-05 | schedules | status (enum) | ✅ |
| REQ-SCHED-06 | schedules | original_event_id (unique) | ✅ |
| REQ-SET-01 | keywords | keyword, is_active | ✅ |
| REQ-SET-02 | settings | alert_time | ✅ |
| REQ-SET-03 | settings | max_per_week | ✅ |
| REQ-SET-04 | settings | lead_days | ✅ |
| REQ-SET-05 | settings | exclude_weekends | ✅ |
| REQ-SET-06 | settings | lead_days (default: 14) | ✅ |

## Security Features

1. **Encryption (Rails 8.1)**
   - `google_access_token` - Encrypted at rest
   - `google_refresh_token` - Encrypted at rest
   - `telegram_bot_token` - Encrypted at rest

2. **Data Integrity**
   - Foreign key constraints on all references
   - Unique indexes on sensitive lookups
   - NOT NULL constraints where required

3. **Uniqueness Constraints**
   - Email addresses (users)
   - Telegram chat IDs (nullable, unique)
   - Google Calendar IDs per user
   - Keywords per user
   - Settings per user
   - Original event IDs (prevent duplicate scheduling)

## Performance Considerations

1. **Indexes**
   - Composite indexes for common queries (user_id + google_id)
   - Partial indexes for nullable fields
   - Date indexes for schedule filtering

2. **Scalability**
   - Proper foreign key relationships
   - No N+1 query problems with eager loading support
   - Timestamps for audit trails

## Migration Execution

To apply all migrations:

```bash
bin/rails db:migrate
```

To roll back specific migration:

```bash
bin/rails db:migrate:down VERSION=20260131073005
```

To check migration status:

```bash
bin/rails db:migrate:status
```

## Testing

All models include validations and scopes to support:
- Unit tests (model validation)
- Integration tests (associations)
- Controller tests (CRUD operations)

See `test/models/` for comprehensive test coverage.
