# 04-data-model.md — 데이터 모델 및 스키마 설계

## 메타 정보
- **프로젝트**: Legal Scheduler AI - SEO 평가 시스템
- **버전**: 1.0
- **작성일**: 2026-04-06
- **담당**: Database Engineer

---

## 1. 개요

SEO 평가 시스템은 기존 BlogPost 모델을 확장하여 2개의 신규 컬럼을 추가합니다. 분석 결과는 JSONB 형식으로 저장하여 유연성과 쿼리 성능을 동시에 확보합니다.

---

## 2. 엔티티 관계도 (ERD)

```
┌────────────────────────────────────────┐
│            blog_posts                  │
├────────────────────────────────────────┤
│ PK  id                  INTEGER        │
│     user_id            INTEGER (FK)    │
│     title              VARCHAR(255)    │
│     content            TEXT            │
│     description        VARCHAR(160)    │ ← NEW (메타 디스크립션)
│     slug               VARCHAR(255)    │
│ NEW seo_score          INTEGER         │
│ NEW seo_details        JSONB           │
│ NEW seo_analyzed_at    TIMESTAMP       │
│     published_at       TIMESTAMP       │
│     created_at         TIMESTAMP       │
│     updated_at         TIMESTAMP       │
│                                        │
│ Indexes:                               │
│ - idx_user_id                         │
│ - idx_slug                            │
│ - idx_seo_score (NEW)                 │
│ - idx_seo_analyzed_at (NEW)           │
└────────────────────────────────────────┘
         │
         │ FK
         ▼
┌────────────────────────────────────────┐
│              users                     │
├────────────────────────────────────────┤
│ PK  id                  INTEGER        │
│     email              VARCHAR(255)    │
│     name               VARCHAR(100)    │
│     ...                                │
└────────────────────────────────────────┘
```

---

## 3. BlogPost 테이블 설계

### 3.1 기존 컬럼

| 컬럼명 | 데이터 타입 | Null | 기본값 | 설명 |
|--------|-----------|------|--------|------|
| id | BIGINT | NO | (PK) | 글 ID |
| user_id | BIGINT | NO | | 작성자 ID |
| title | VARCHAR(255) | NO | | 글 제목 |
| content | TEXT | NO | | 글 본문 (마크다운) |
| slug | VARCHAR(255) | NO | | URL 슬러그 |
| published_at | TIMESTAMP | YES | NULL | 발행 시간 |
| created_at | TIMESTAMP | NO | CURRENT_TIMESTAMP | 생성 시간 |
| updated_at | TIMESTAMP | NO | CURRENT_TIMESTAMP | 수정 시간 |

### 3.2 신규 컬럼

#### seo_score (INTEGER)

**목적**: SEO 평가 총점 저장

**데이터 타입**: INTEGER

**범위**: 0 ~ 100

**Null 정책**: NULL 가능 (아직 분석되지 않음)

**기본값**: NULL

**인덱스**: YES (쿼리 성능)

**예시**:
```sql
seo_score = 65  -- 65/100점
seo_score = NULL -- 아직 분석 안 됨
```

#### seo_details (JSONB)

**목적**: SEO 분석 세부 결과 저장

**데이터 타입**: JSONB (PostgreSQL)

**구조**:
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
    ...
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

**Null 정책**: NULL 가능 (아직 분석되지 않음)

**기본값**: NULL

**인덱스**: GIN 인덱스 (JSONB 필드 검색 최적화)

#### seo_analyzed_at (TIMESTAMP)

**목적**: 마지막 SEO 분석 시간 기록

**데이터 타입**: TIMESTAMP WITH TIME ZONE

**Null 정책**: NULL 가능

**기본값**: NULL

**인덱스**: YES (최근 분석된 글 쿼리 최적화)

**용도**:
- 분석 캐시 만료 판단
- "최근 분석됨" 배지 표시
- 분석 이력 관리

---

## 4. 마이그레이션 스크립트

### 4.1 Rails Migration

```ruby
# db/migrate/[timestamp]_add_seo_fields_to_blog_posts.rb
class AddSeoFieldsToBlogPosts < ActiveRecord::Migration[8.0]
  def change
    # 1. seo_score 컬럼 추가
    add_column :blog_posts, :seo_score, :integer, default: nil, comment: "SEO 평가 총점 (0~100)"

    # 2. seo_details 컬럼 추가 (JSONB)
    add_column :blog_posts, :seo_details, :jsonb, default: nil, comment: "SEO 분석 세부 결과"

    # 3. seo_analyzed_at 컬럼 추가
    add_column :blog_posts, :seo_analyzed_at, :datetime, default: nil, comment: "마지막 SEO 분석 시간"

    # 4. 인덱스 추가
    add_index :blog_posts, :seo_score, name: 'idx_blog_posts_seo_score'
    add_index :blog_posts, :seo_analyzed_at, name: 'idx_blog_posts_seo_analyzed_at'

    # 5. JSONB GIN 인덱스 (고급 쿼리용)
    add_index :blog_posts, :seo_details, using: :gin, name: 'idx_blog_posts_seo_details_gin'
  end
end
```

### 4.2 실행 방법

```bash
# Rails 마이그레이션 실행
rails db:migrate

# 롤백 (필요시)
rails db:rollback STEP=1
```

---

## 5. SQL 쿼리 예시

### 5.1 SEO 점수가 높은 글 조회

```sql
SELECT
  id,
  title,
  seo_score,
  seo_analyzed_at,
  ROUND((seo_score::float / 100) * 100, 1) AS score_percentage
FROM blog_posts
WHERE seo_score IS NOT NULL
  AND seo_score >= 70
ORDER BY seo_score DESC
LIMIT 10;
```

**결과**:
```
 id |      title      | seo_score | seo_analyzed_at | score_percentage
----+-----------------+-----------+-----------------+------------------
  5 | 기업 소송 관리법 |        85 | 2026-04-06 14:30| 85.0
  8 | 변론일 준비법   |        78 | 2026-04-06 13:45| 78.0
```

### 5.2 카테고리별 평균 점수

```sql
SELECT
  (seo_details -> 'summary' -> 'keyword_optimization' -> 'score')::int AS keyword_score,
  (seo_details -> 'summary' -> 'technical_seo' -> 'score')::int AS technical_score,
  (seo_details -> 'summary' -> 'bonus' -> 'score')::int AS bonus_score,
  COUNT(*) AS count,
  ROUND(AVG((seo_details -> 'score')::int), 1) AS avg_total_score
FROM blog_posts
WHERE seo_details IS NOT NULL
GROUP BY
  (seo_details -> 'summary' -> 'keyword_optimization' -> 'score'),
  (seo_details -> 'summary' -> 'technical_seo' -> 'score'),
  (seo_details -> 'summary' -> 'bonus' -> 'score');
```

### 5.3 특정 항목에서 낮은 점수 받은 글

```sql
SELECT
  id,
  title,
  seo_score,
  jsonb_array_elements(seo_details -> 'items') ->> 'name' AS item_name,
  (jsonb_array_elements(seo_details -> 'items') ->> 'score')::int AS item_score
FROM blog_posts
WHERE seo_details IS NOT NULL
  AND (jsonb_array_elements(seo_details -> 'items') ->> 'id') = 'meta_description'
  AND (jsonb_array_elements(seo_details -> 'items') ->> 'score')::int < 5
ORDER BY item_score ASC;
```

**결과**:
```
 id |      title      | seo_score |     item_name      | item_score
----+-----------------+-----------+--------------------+------------
  3 | 변론일 가이드   |        60 | 메타 디스크립션   |          0
  7 | 소송 절차       |        55 | 메타 디스크립션   |          3
```

### 5.4 최근 분석된 글

```sql
SELECT
  id,
  title,
  seo_score,
  seo_analyzed_at,
  AGE(NOW(), seo_analyzed_at) AS time_since_analysis
FROM blog_posts
WHERE seo_analyzed_at IS NOT NULL
ORDER BY seo_analyzed_at DESC
LIMIT 5;
```

---

## 6. Ruby on Rails 모델 정의

### 6.1 BlogPost 모델

```ruby
# app/models/blog_post.rb
class BlogPost < ApplicationRecord
  belongs_to :user

  # SEO 관련 속성
  attribute :seo_score, :integer
  attribute :seo_details, :jsonb
  attribute :seo_analyzed_at, :datetime

  # 유효성 검사
  validates :seo_score, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100,
    allow_nil: true
  }

  # 스코프: SEO 점수가 높은 순서
  scope :by_seo_score, -> { order(seo_score: :desc) }
  scope :with_seo_analysis, -> { where('seo_details IS NOT NULL') }
  scope :without_seo_analysis, -> { where(seo_details: nil) }
  scope :low_seo_score, -> (threshold = 50) {
    where('seo_score IS NOT NULL AND seo_score < ?', threshold)
  }

  # 메서드: SEO 점수 등급
  def seo_grade
    return nil if seo_score.nil?
    case seo_score
    when 0..40
      'D'
    when 41..60
      'C'
    when 61..80
      'B'
    when 81..100
      'A'
    end
  end

  # 메서드: SEO 분석 여부
  def seo_analyzed?
    seo_details.present? && seo_analyzed_at.present?
  end

  # 메서드: 분석 캐시 만료 여부 (24시간)
  def seo_cache_expired?
    return true if seo_analyzed_at.nil?
    seo_analyzed_at < 24.hours.ago
  end

  # 메서드: 특정 항목의 점수 조회
  def seo_item_score(item_id)
    return nil if seo_details.nil?
    items = seo_details['items'] || []
    item = items.find { |i| i['id'] == item_id }
    item&.dig('score')
  end

  # 메서드: 카테고리별 점수
  def seo_summary
    return nil if seo_details.nil?
    seo_details['summary']
  end
end
```

### 6.2 모델 사용 예시

```ruby
# 특정 글의 SEO 점수 조회
post = BlogPost.find(1)
post.seo_score                    # => 65
post.seo_grade                    # => 'B'
post.seo_analyzed?                # => true
post.seo_item_score('title_keyword') # => 8

# SEO 점수 기준 조회
BlogPost.by_seo_score.limit(10)
BlogPost.low_seo_score(70)
BlogPost.with_seo_analysis.limit(20)

# 분석 결과 저장
post.update(
  seo_score: 75,
  seo_details: { score: 75, items: [...] },
  seo_analyzed_at: Time.current
)
```

---

## 7. 데이터 완전성 및 정합성

### 7.1 제약 조건

```sql
-- seo_score와 seo_details의 일관성 보장
-- (둘 다 NULL이거나 둘 다 NOT NULL)
ALTER TABLE blog_posts
ADD CONSTRAINT check_seo_data_consistency
CHECK (
  (seo_score IS NULL AND seo_details IS NULL) OR
  (seo_score IS NOT NULL AND seo_details IS NOT NULL)
);
```

### 7.2 트리거 (선택사항)

```sql
-- seo_analyzed_at 자동 업데이트
CREATE OR REPLACE FUNCTION update_seo_analyzed_at()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.seo_details IS NOT NULL AND OLD.seo_details IS DISTINCT FROM NEW.seo_details THEN
    NEW.seo_analyzed_at = CURRENT_TIMESTAMP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER blog_posts_seo_analyzed_at_trigger
BEFORE UPDATE ON blog_posts
FOR EACH ROW
EXECUTE FUNCTION update_seo_analyzed_at();
```

---

## 8. 데이터 백업 및 복구

### 8.1 SEO 데이터 백업

```bash
# seo_details JSONB 데이터만 백업
pg_dump -t blog_posts \
  -a \
  -F plain \
  legal_scheduler_ai_production > seo_backup_$(date +%Y%m%d).sql
```

### 8.2 복구

```bash
# 데이터 복구
psql legal_scheduler_ai_production < seo_backup_20260406.sql
```

---

## 9. 성능 최적화

### 9.1 인덱스 전략

```sql
-- 기본 인덱스 (이미 마이그레이션에 포함)
CREATE INDEX idx_blog_posts_seo_score ON blog_posts(seo_score DESC);
CREATE INDEX idx_blog_posts_seo_analyzed_at ON blog_posts(seo_analyzed_at DESC);

-- GIN 인덱스 (JSONB 검색)
CREATE INDEX idx_blog_posts_seo_details_gin ON blog_posts USING GIN (seo_details);

-- 복합 인덱스 (사용자별 SEO 점수 조회)
CREATE INDEX idx_blog_posts_user_seo ON blog_posts(user_id, seo_score DESC);
```

### 9.2 쿼리 최적화

```ruby
# N+1 문제 방지
posts = BlogPost
  .select(:id, :title, :seo_score, :seo_analyzed_at)
  .where('seo_score > ?', 70)
  .limit(100)

# JSONB 필드 선택적 로드 (필요한 경우만)
posts = BlogPost.select(
  'id, title, seo_score, seo_analyzed_at, seo_details'
).by_seo_score.limit(10)
```

---

## 10. 버전 관리 (선택사항)

만약 SEO 분석 결과의 이력을 추적해야 한다면:

```sql
-- 별도 이력 테이블
CREATE TABLE blog_post_seo_histories (
  id BIGSERIAL PRIMARY KEY,
  blog_post_id BIGINT NOT NULL REFERENCES blog_posts(id),
  seo_score INTEGER NOT NULL,
  seo_details JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (blog_post_id) REFERENCES blog_posts(id) ON DELETE CASCADE
);

-- 인덱스
CREATE INDEX idx_seo_histories_blog_post ON blog_post_seo_histories(blog_post_id);
CREATE INDEX idx_seo_histories_created_at ON blog_post_seo_histories(created_at DESC);
```

---

## 11. 모니터링 및 유지보수

### 11.1 테이블 통계

```sql
-- 테이블 크기 확인
SELECT
  pg_size_pretty(pg_total_relation_size('blog_posts')) AS total_size,
  pg_size_pretty(pg_relation_size('blog_posts')) AS table_size,
  pg_size_pretty(pg_indexes_size('blog_posts')) AS indexes_size;
```

### 11.2 JSONB 데이터 검증

```ruby
# Rails 콘솔에서 검증
BlogPost.where.not(seo_details: nil).find_each do |post|
  # seo_details 구조 검증
  unless post.seo_details.is_a?(Hash) && post.seo_details['score'].is_a?(Integer)
    Rails.logger.error("Invalid seo_details for post #{post.id}")
  end
end
```

---

## 12. 마이그레이션 체크리스트

- [ ] 마이그레이션 파일 작성
- [ ] 로컬 환경에서 테스트
- [ ] 프로덕션 백업 수행
- [ ] 마이그레이션 실행
- [ ] 데이터 검증 (NULL 체크, 타입 체크)
- [ ] 인덱스 성능 검증
- [ ] 롤백 테스트

---

**작성자**: Database Engineer
**검토자**: Senior Backend Engineer, DevOps
**마지막 업데이트**: 2026-04-06
