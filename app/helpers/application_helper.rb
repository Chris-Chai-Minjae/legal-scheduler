module ApplicationHelper
  # 블로그 본문 렌더링 헬퍼 — 간단한 마크다운 → HTML 치환 + simple_format
  #
  # 지원 패턴:
  #   **bold** / __bold__  → <strong>bold</strong>
  #   *italic* / _italic_  → <em>italic</em>
  #   `code`               → <code>code</code>
  #   # 헤더 / ## 헤더     → <h3>헤더</h3>
  #   - 리스트             → <ul><li>리스트</li></ul>
  #   1. 리스트            → <ol><li>리스트</li></ol>
  #
  # 나머지 줄바꿈/단락은 simple_format 이 처리.
  def render_blog_content(text)
    return "" if text.blank?

    raw = text.to_s.dup

    # 1) 코드블록 ``` 제거 (법률 블로그에선 불필요)
    raw.gsub!(/```[a-zA-Z0-9_-]*\n(.*?)```/m, '\1')

    # 2) 헤더: ### / ## / # (줄 시작)
    raw.gsub!(/^\s*\#{1,3}\s+(.+?)\s*$/) { "<h3>#{h(Regexp.last_match(1))}</h3>" }

    # 3) 볼드: **text** / __text__
    raw.gsub!(/\*\*(.+?)\*\*/m) { "<strong>#{h(Regexp.last_match(1))}</strong>" }
    raw.gsub!(/__(.+?)__/m) { "<strong>#{h(Regexp.last_match(1))}</strong>" }

    # 4) 이탤릭: *text* (볼드 뒤 처리, 연속 * 및 단어경계 방어)
    raw.gsub!(/(?<![\*\w])\*([^\*\n]+?)\*(?![\*\w])/) { "<em>#{h(Regexp.last_match(1))}</em>" }

    # 5) 인라인 코드: `text`
    raw.gsub!(/`([^`\n]+?)`/) { "<code>#{h(Regexp.last_match(1))}</code>" }

    # 6) 리스트 그룹화
    raw = group_markdown_lists(raw)

    # 7) 남은 텍스트는 simple_format (줄바꿈 → <br>, 빈 줄 → </p><p>)
    simple_format(raw.html_safe, {}, sanitize: false)
  end

  private

  # 연속된 '- item' 또는 '1. item' 줄을 <ul>/<ol> 로 그룹화
  def group_markdown_lists(text)
    lines = text.split("\n")
    output = []
    buffer = []
    buffer_type = nil # :ul | :ol | nil

    flush = lambda do
      return if buffer.empty?
      tag = buffer_type == :ol ? "ol" : "ul"
      items = buffer.map { |item| "<li>#{h(item)}</li>" }.join
      output << "<#{tag}>#{items}</#{tag}>"
      buffer.clear
      buffer_type = nil
    end

    lines.each do |line|
      if (m = line.match(/\A\s*[-•]\s+(.+)\z/))
        flush.call if buffer_type == :ol
        buffer_type = :ul
        buffer << m[1]
      elsif (m = line.match(/\A\s*\d+\.\s+(.+)\z/))
        flush.call if buffer_type == :ul
        buffer_type = :ol
        buffer << m[1]
      else
        flush.call
        output << line
      end
    end
    flush.call

    output.join("\n")
  end
end
