#!/usr/bin/env rails runner
# DB 복구: SEO 최적화 적용 시 LLM이 반환한 전체 본문이 title에 저장된 레코드 복구
#
# 대상:
#   1. title이 200자 초과 (비정상)
#   2. title이 "AI가 콘텐츠를 생성하는 중입니다..." (placeholder)
#   3. title이 "생성 중..." 이면서 status != generating (정체된 상태)
#
# 복구 전략:
#   - content가 정상적인 글이면 content 첫 줄을 title로 사용
#   - content가 비어있거나 placeholder면 "생성 중..." 설정
#   - status가 generating인 채 오래된 것은 draft로 변경
#
# Usage: rails runner scripts/fix_corrupted_titles.rb

class TitleFixer
  MAX_TITLE_LENGTH = 200

  def self.run(dry_run: true)
    fixer = new
    fixer.find_corrupted
    fixer.report

    unless dry_run
      puts "\n=== 실제 복구 시작 ==="
      fixer.fix_all
    else
      puts "\n=== DRY RUN (실제 수정 안 함) ==="
      puts "실제 복구하려면: rails runner scripts/fix_corrupted_titles.rb apply"
    end
  end

  def initialize
    @corrupted = []
  end

  def find_corrupted
    # 1. title이 200자 초과 (LLM이 전체 본문을 title에 저장)
    BlogPost.where("LENGTH(title) > ?", MAX_TITLE_LENGTH).find_each do |post|
      @corrupted << {
        id: post.id,
        type: :oversized_title,
        title_length: post.title.length,
        title_preview: post.title[0, 80],
        status: post.status,
        content_length: post.content.to_s.length,
        action: derive_action(post)
      }
    end

    # 2. title이 placeholder인데 status가 generating이 아닌 것 (정체)
    BlogPost.where(title: ["생성 중...", "AI가 콘텐츠를 생성하는 중입니다..."])
              .where.not(status: :generating)
              .find_each do |post|
      @corrupted << {
        id: post.id,
        type: :stale_placeholder,
        title_length: post.title.length,
        title_preview: post.title,
        status: post.status,
        content_length: post.content.to_s.length,
        action: derive_action(post)
      }
    end

    # 3. status가 generating인 채 1시간 이상 경과 (정체된 생성)
    stale_threshold = 1.hour.ago
    BlogPost.where(status: :generating).where("updated_at < ?", stale_threshold).find_each do |post|
      @corrupted << {
        id: post.id,
        type: :stale_generating,
        title_length: post.title.length,
        title_preview: post.title[0, 80],
        status: post.status,
        content_length: post.content.to_s.length,
        action: :set_draft
      }
    end
  end

  def derive_action(post)
    content = post.content.to_s
    real_content = content.present? &&
                   !content.start_with?("AI가 콘텐츠를 생성하는 중입니다")

    if real_content
      # content의 첫 줄을 title로 사용 (최대 100자)
      first_line = content.lines.first.to_s.strip
      first_line = first_line.gsub(/\A\[.*?\]\s*/, "").strip # [사건] 같은 접두어 제거
      first_line = first_line[0, 100]
      if first_line.length >= 3
        :restore_from_content
      else
        :set_placeholder
      end
    else
      :set_placeholder
    end
  end

  def report
    puts "발견된 손상 레코드: #{@corrupted.length}건\n\n"

    @corrupted.each do |r|
      puts "## Post ##{r[:id]} [#{r[:type]}]"
      puts "   status: #{r[:status]}"
      puts "   title: #{r[:title_length]}자 - #{r[:title_preview]}#{'...' if r[:title_preview].length >= 80}"
      puts "   content: #{r[:content_length]}자"
      puts "   action: #{r[:action]}"
      puts
    end
  end

  def fix_all
    @corrupted.each do |r|
      post = BlogPost.find(r[:id])
      old_title = post.title

      case r[:action]
      when :restore_from_content
        content = post.content.to_s
        first_line = content.lines.first.to_s.strip
        first_line = first_line.gsub(/\A\[.*?\]\s*/, "").strip[0, 100]
        post.update_columns(title: first_line) if first_line.length >= 3
        puts "Post ##{r[:id]}: title 복원 (#{first_line[0, 40]}...)"

      when :set_placeholder
        post.update_columns(title: "생성 중...")
        puts "Post ##{r[:id]}: title → '생성 중...'"

      when :set_draft
        post.update_columns(status: :draft)
        post.update_columns(title: "생성 중...") if post.title.length > MAX_TITLE_LENGTH || post.title.start_with?("AI가")
        puts "Post ##{r[:id]}: status generating → draft"
      end
    end

    puts "\n복구 완료: #{@corrupted.length}건 처리됨"
  end
end

apply_mode = ARGV.include?("apply")
TitleFixer.run(dry_run: !apply_mode)
