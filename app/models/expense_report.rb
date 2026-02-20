class ExpenseReport < ApplicationRecord
  belongs_to :user
  belongs_to :card_statement, optional: true
  has_many :expense_report_items, -> { order(:position) }, dependent: :destroy
  has_many :expenses, through: :expense_report_items
  has_one_attached :template_file
  has_one_attached :output_file

  enum :status, { pending: 0, generating: 1, completed: 2, failed: 3 }

  validates :title, presence: true
  validates :status, presence: true

  STATUS_LABELS = {
    "pending" => "대기중",
    "generating" => "생성중",
    "completed" => "완료",
    "failed" => "실패"
  }.freeze

  def status_i18n
    STATUS_LABELS[status] || status
  end

  def recalculate!
    update!(
      expense_count: expense_report_items.count,
      total_amount: expenses.sum(:amount)
    )
  end
end
