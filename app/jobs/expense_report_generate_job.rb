class ExpenseReportGenerateJob < ApplicationJob
  queue_as :default

  def perform(expense_report_id)
    report = ExpenseReport.find(expense_report_id)
    report.update!(status: :generating)

    expenses = report.expenses.order("expense_report_items.position")

    generator = HwpxGeneratorService.new(expenses)
    result = generator.generate

    if result.success
      report.output_file.attach(
        io: File.open(result.output_path, "rb"),
        filename: "#{report.title.parameterize(separator: '_')}.hwpx",
        content_type: "application/hwp+zip"
      )
      report.recalculate!
      report.update!(status: :completed)

      # Cleanup temp file
      FileUtils.rm_f(result.output_path)
    else
      report.update!(status: :failed, error_message: result.error)
    end
  rescue => e
    report&.update(status: :failed, error_message: e.message)
    Rails.logger.error("[ExpenseReportGenerateJob] 실패: #{e.message}")
    raise
  end
end
