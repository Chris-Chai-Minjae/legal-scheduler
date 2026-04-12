class BlogPost < ApplicationRecord
  belongs_to :user
  has_many :blog_chats, dependent: :destroy

  enum :status, { draft: 0, generating: 1, completed: 2, published: 3 }
  enum :tone, { professional: 0, easy: 1, storytelling: 2 }
  enum :length_setting, { short: 0, medium: 1, long: 2 }

  validates :title, presence: true
  validates :prompt, presence: true
  validates :seo_score, numericality: { in: 0..100 }, allow_nil: true

  before_validation :generate_slug, if: -> { slug.blank? && title.present? }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_seo_score, -> { where.not(seo_score: nil).order(seo_score: :desc) }

  def tone_name
    case tone
    when "professional" then "전문적"
    when "easy" then "쉬운"
    when "storytelling" then "스토리텔링"
    else tone
    end
  end

  def status_name
    case status
    when "draft" then "초안"
    when "generating" then "생성 중"
    when "completed" then "완료"
    when "published" then "발행"
    else status
    end
  end

  def status_emoji
    case status
    when "draft" then "📝"
    when "generating" then "⚙️"
    when "completed" then "✅"
    when "published" then "🌐"
    else "📄"
    end
  end

  # SEO

  def seo_grade
    return nil if seo_score.nil?
    case seo_score
    when 80..100 then "A"
    when 60..79  then "B"
    when 40..59  then "C"
    else              "D"
    end
  end

  def seo_analyzed?
    seo_details.present?
  end

  def seo_items
    return [] unless seo_details
    seo_details["items"] || []
  end

  # Images

  def add_image(url:, alt: nil)
    self.images = (images || []) + [{ "url" => url, "alt" => alt, "created_at" => Time.current.iso8601 }]
    save!
  end

  def image_list
    images || []
  end

  def has_images?
    images.present? && images.any?
  end

  private

  def generate_slug
    # 한글 제목은 parameterize 시 거의 비어버리므로 random suffix 로 uniqueness 보장
    base = title.to_s.parameterize.presence || "post"
    base = base[0, 40] # 너무 긴 slug 방지
    self.slug = "#{base}-#{SecureRandom.hex(4)}"
  end
end
