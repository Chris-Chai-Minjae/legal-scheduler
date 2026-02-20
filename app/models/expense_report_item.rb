class ExpenseReportItem < ApplicationRecord
  belongs_to :expense_report
  belongs_to :expense

  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :expense_report_id,
                                     message: "은(는) 보고서 내에서 중복될 수 없습니다" }
end
