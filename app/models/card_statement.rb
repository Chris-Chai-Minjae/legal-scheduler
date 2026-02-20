class CardStatement < ApplicationRecord
  belongs_to :user
  has_many :expenses, dependent: :destroy
  has_many :expense_reports
  has_one_attached :file

  enum :status, { pending: 0, parsing: 1, classifying: 2, completed: 3, failed: 4 }

  validates :filename, presence: true

  STATUS_LABELS = {
    "pending" => "대기중",
    "parsing" => "파싱중",
    "classifying" => "분류중",
    "completed" => "완료",
    "failed" => "실패"
  }.freeze

  def status_i18n
    STATUS_LABELS[status] || status
  end

  def progress_percentage
    return 0 if total_transactions.zero?
    (classified_transactions.to_f / total_transactions * 100).round
  end
end
