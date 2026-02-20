class BlogPost < ApplicationRecord
  belongs_to :user
  has_many :blog_chats, dependent: :destroy

  enum :status, { draft: 0, generating: 1, completed: 2, published: 3 }
  enum :tone, { professional: 0, easy: 1, storytelling: 2 }
  enum :length_setting, { short: 0, medium: 1, long: 2 }

  validates :title, presence: true
  validates :prompt, presence: true

  scope :recent, -> { order(created_at: :desc) }

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
end
