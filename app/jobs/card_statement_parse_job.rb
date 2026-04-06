class CardStatementParseJob < ApplicationJob
  queue_as :default

  def perform(card_statement_id)
    statement = CardStatement.find(card_statement_id)

    # Guard: 완료된 statement만 재실행 방지 (parsing 상태에서 실패 후 재시도 허용)
    return if statement.completed?

    statement.update!(status: :parsing)

    # Guard: 파일 첨부 여부 확인
    attachments = statement.files.any? ? statement.files : (statement.file.attached? ? [statement.file] : [])
    if attachments.empty?
      statement.update!(status: :failed, error_message: "첨부된 파일이 없습니다")
      return
    end

    all_transactions = []
    combined_card_summary = {}

    # 모든 첨부 파일을 순회하며 파싱 후 통합 (개별 파일 실패 시 건너뜀)
    parse_errors = []
    attachments.each do |attachment|
      ext = File.extname(attachment.filename.to_s).downcase.presence || ".xlsx"
      temp_file = Tempfile.new(["card_statement", ext])
      begin
        temp_file.binmode
        temp_file.write(attachment.download)
        temp_file.rewind

        result = CardParserService.new(temp_file.path, original_filename: attachment.filename.to_s).parse
        all_transactions.concat(result.transactions)
        result.card_summary.each { |k, v| combined_card_summary[k] = (combined_card_summary[k] || 0) + v }
      rescue => e
        parse_errors << "#{attachment.filename}: #{e.message}"
        Rails.logger.warn("[CardStatementParseJob] 파일 파싱 스킵: #{attachment.filename} - #{e.message}")
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    # Build and validate expense records before insert
    expense_records = []
    if all_transactions.any?
      expense_records = all_transactions.filter_map do |t|
        next if t[:amount].blank? || t[:amount].to_i <= 0 || t[:transaction_date].blank? || t[:card_name].blank?
        next if ExpenseClassifierService.excluded?(t[:merchant])

        {
          card_statement_id: statement.id,
          user_id: statement.user_id,
          transaction_date: t[:transaction_date],
          merchant: t[:merchant],
          amount: t[:amount],
          currency: t[:currency] || "KRW",
          card_name: t[:card_name],
          cancelled: t[:cancelled] || false,
          foreign_amount: t[:foreign_amount],
          foreign_currency: t[:foreign_currency],
          classification_status: 0,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      Expense.insert_all(expense_records) if expense_records.any?
    end

    statement.update!(
      total_transactions: expense_records.size,
      card_summary: combined_card_summary
    )

    # Trigger classification job
    ExpenseClassifyJob.perform_later(statement.id)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[CardStatementParseJob] Statement #{card_statement_id} not found: #{e.message}")
  rescue => e
    statement&.update(status: :failed, error_message: e.message&.truncate(500))
    Rails.logger.error("[CardStatementParseJob] 실패: #{e.message}")
    raise
  end
end
