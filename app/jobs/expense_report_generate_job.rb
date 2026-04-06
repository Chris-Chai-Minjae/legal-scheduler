class ExpenseReportGenerateJob < ApplicationJob
  queue_as :default

  def perform(expense_report_id)
    report = ExpenseReport.find(expense_report_id)

    return if report.generating? || report.completed?

    report.update!(status: :generating)

    expenses = report.expenses.order("expense_report_items.position")
    batch_size = 50

    if expenses.size <= batch_size
      generate_single(report, expenses)
    else
      generate_batched(report, expenses, batch_size)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[ExpenseReportGenerateJob] Report #{expense_report_id} not found: #{e.message}")
  rescue => e
    report&.update(status: :failed, error_message: e.message&.truncate(500))
    Rails.logger.error("[ExpenseReportGenerateJob] 실패: #{e.message}")
    raise
  end

  private

  def generate_single(report, expenses)
    result = HwpxGeneratorService.new(expenses).generate

    if result.success
      File.open(result.output_path, "rb") do |file|
        report.output_file.attach(
          io: file,
          filename: "#{report.title.parameterize(separator: '_')}.hwpx",
          content_type: "application/hwp+zip"
        )
      end
      FileUtils.rm_f(result.output_path)
      report.recalculate!
      report.update!(status: :completed)
    else
      report.update!(status: :failed, error_message: result.error&.truncate(500))
    end
  end

  def generate_batched(report, expenses, batch_size)
    temp_files = []
    batches = expenses.each_slice(batch_size).to_a

    batches.each_with_index do |batch, idx|
      result = HwpxGeneratorService.new(batch).generate
      unless result.success
        temp_files.each { |f| FileUtils.rm_f(f) }
        report.update!(status: :failed, error_message: "배치 #{idx + 1} 생성 실패: #{result.error}")
        return
      end
      temp_files << result.output_path
    end

    # ZIP으로 묶기
    zip_file = Tempfile.new(["expense_report_bundle", ".zip"])
    zip_path = zip_file.path
    zip_file.close

    Zip::OutputStream.open(zip_path) do |zos|
      temp_files.each_with_index do |path, idx|
        zos.put_next_entry("지출결의서_#{idx + 1}.hwpx")
        zos.write(File.binread(path))
      end
    end

    File.open(zip_path, "rb") do |file|
      report.output_file.attach(
        io: file,
        filename: "#{report.title.parameterize(separator: '_')}.zip",
        content_type: "application/zip"
      )
    end

    report.recalculate!
    report.update!(status: :completed)
  ensure
    temp_files&.each { |f| FileUtils.rm_f(f) }
    FileUtils.rm_f(zip_path) if zip_path
  end
end
