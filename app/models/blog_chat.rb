class BlogChat < ApplicationRecord
  belongs_to :blog_post, optional: true
  belongs_to :user

  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true

  scope :chronological, -> { order(created_at: :asc) }
end
