class CardStatement < ApplicationRecord
  belongs_to :user
  has_many :expenses, dependent: :destroy
  has_many :expense_reports, dependent: :nullify
  has_one_attached :file

  enum :status, { pending: 0, parsing: 1, classifying: 2, completed: 3, failed: 4 }

  validates :filename, presence: true
  validates :status, presence: true
  validate :file_content_type_valid, if: -> { file.attached? }

  STATUS_LABELS = {
    "pending" => "대기중",
    "parsing" => "파싱중",
    "classifying" => "분류중",
    "completed" => "완료",
    "failed" => "실패"
  }.freeze

  ALLOWED_CONTENT_TYPES = %w[
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-excel
    text/csv
  ].freeze

  def status_i18n
    STATUS_LABELS[status] || status
  end

  def progress_percentage
    total = total_transactions.to_i
    return 0 if total.zero?

    (classified_transactions.to_i.to_f / total * 100).round
  end

  private

  def file_content_type_valid
    return unless file.attached?
    unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
      errors.add(:file, "은(는) Excel 또는 CSV 파일만 허용됩니다")
    end
  end
end
