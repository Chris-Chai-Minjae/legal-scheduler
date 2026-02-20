class ExpenseReportGenerateJob < ApplicationJob
  queue_as :default

  def perform(expense_report_id)
    report = ExpenseReport.find(expense_report_id)

    # Guard: 이미 생성중이거나 완료된 보고서 재실행 방지 (idempotency)
    return if report.generating? || report.completed?

    report.update!(status: :generating)

    expenses = report.expenses.order("expense_report_items.position")

    generator = HwpxGeneratorService.new(expenses)
    result = generator.generate

    if result.success
      # File.open 블록 형태로 사용하여 파일 핸들 자동 해제
      File.open(result.output_path, "rb") do |file|
        report.output_file.attach(
          io: file,
          filename: "#{report.title.parameterize(separator: '_')}.hwpx",
          content_type: "application/hwp+zip"
        )
      end

      report.recalculate!
      report.update!(status: :completed)
    else
      report.update!(status: :failed, error_message: result.error&.truncate(500))
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[ExpenseReportGenerateJob] Report #{expense_report_id} not found: #{e.message}")
  rescue => e
    report&.update(status: :failed, error_message: e.message&.truncate(500))
    Rails.logger.error("[ExpenseReportGenerateJob] 실패: #{e.message}")
    raise
  ensure
    # Cleanup temp file (result가 존재하고 output_path가 있을 때)
    if defined?(result) && result&.respond_to?(:output_path) && result&.output_path
      FileUtils.rm_f(result.output_path)
    end
  end
end
