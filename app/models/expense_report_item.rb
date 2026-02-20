class ExpenseReportItem < ApplicationRecord
  belongs_to :expense_report
  belongs_to :expense
end
