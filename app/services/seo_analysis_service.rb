class SeoAnalysisService
  # BlogAiService 와 동일한 env 우선순위 + 올바른 기본 포트(8001)
  BLOG_AI_URL = ENV["BLOG_AI_API_URL"] || ENV["BLOG_AI_URL"] || "http://blog-ai:8001"

  def self.analyze(post)
    new(post).analyze
  end

  def self.optimize(post, item_id)
    new(post).optimize(item_id)
  end

  def initialize(post)
    @post = post
  end

  def analyze
    response = request_analysis
    return nil unless response

    # SEO 재분석 시 추출한 키워드도 DB 에 저장 (다음 분석 재사용 + 프론트 표시)
    update_attrs = {
      seo_score: response["score"],
      seo_details: response,
      seo_analyzed_at: Time.current
    }
    keywords = extract_keywords
    update_attrs[:target_keywords] = keywords if keywords.present?
    @post.update(update_attrs)

    response
  end

  def optimize(item_id)
    uri = URI.join(BLOG_AI_URL, "/api/seo/optimize/#{item_id}")
    body = build_request_body.merge(item_type: item_id)

    response = Net::HTTP.post(uri, body.to_json, "Content-Type" => "application/json")

    if response.code == "200"
      JSON.parse(response.body)
    else
      Rails.logger.error("SEO optimize failed: #{response.code} #{response.body}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("SEO optimize error: #{e.message}")
    nil
  end

  private

  def request_analysis
    uri = URI.join(BLOG_AI_URL, "/api/seo/analyze")
    body = build_request_body

    response = Net::HTTP.post(uri, body.to_json, "Content-Type" => "application/json")

    if response.code == "200"
      JSON.parse(response.body)
    else
      Rails.logger.error("SEO analysis failed: #{response.code} #{response.body}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("SEO analysis error: #{e.message}")
    nil
  end

  def build_request_body
    {
      content: @post.content.to_s,
      title: @post.title.to_s,
      description: @post.description,
      slug: @post.slug,
      target_keywords: extract_keywords,
      images: @post.image_list
    }
  end

  # 키워드 후보에서 제외할 meta/일반 단어 (SEO 오판 방지)
  STOPWORDS = %w[
    AI 생성 제목 제목: 생성중 제목생성 post
    사건 결과 사례 성공 성공사례
    허유영 변호사 방법 내용
    이것 저것 그것 그리고 그러나 또는 또한
    의뢰인 원고 피고 관련 본문 부분 사실
  ].freeze

  def extract_keywords
    # 1순위: 사용자가 직접 지정한 target_keywords
    if @post.respond_to?(:target_keywords) && @post.target_keywords.present?
      return @post.target_keywords
    end

    # 2순위: 사용자 입력 prompt 에서 추출 (사용자가 블로그 주제로 직접 적은 단어들)
    #        prompt 는 AI 가 건드리지 않은 원본 주제라 가장 신뢰도가 높음
    prompt_keywords = tokenize(@post.prompt.to_s)
    return prompt_keywords.first(3) if prompt_keywords.any?

    # 3순위: title 에서 추출 (단, placeholder 제외)
    title = @post.title.to_s
    return [] if title.blank? || title == "생성 중..." || title.start_with?("AI 생성 제목")
    tokenize(title).first(3)
  end

  # 2자 이상 단어 + 불용어 제거 + 중복 제거 (순서 유지)
  def tokenize(text)
    text
      .to_s
      .gsub(/[「」『』（）\[\]{}【】,.、·•:;"""''!?*\-—]/, " ")
      .split(/\s+/)
      .map(&:strip)
      .reject(&:empty?)
      .select { |w| w.length >= 2 }
      .reject { |w| STOPWORDS.include?(w) }
      .reject { |w| w.match?(/\A\d+\z/) }
      .uniq
  end
end
