class ExpenseReportGenerateJob < ApplicationJob
  queue_as :default

  def perform(expense_report_id)
    report = ExpenseReport.find(expense_report_id)

    return if report.generating? || report.completed?

    report.update!(status: :generating)

    expenses = report.expenses.order("expense_report_items.position")

    result = HwpxGeneratorService.new(expenses).generate

    if result.success
      begin
        File.open(result.output_path, "rb") do |file|
          report.output_file.attach(
            io: file,
            filename: "#{report.title.parameterize(separator: '_')}.hwpx",
            content_type: "application/hwp+zip"
          )
        end
        report.recalculate!
        report.update!(status: :completed)
      ensure
        FileUtils.rm_f(result.output_path) if result.output_path
      end
    else
      report.update!(status: :failed, error_message: result.error&.truncate(500))
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[ExpenseReportGenerateJob] Report #{expense_report_id} not found: #{e.message}")
  rescue => e
    report&.update(status: :failed, error_message: e.message&.truncate(500))
    Rails.logger.error("[ExpenseReportGenerateJob] 실패: #{e.message}")
    raise
  end
end
