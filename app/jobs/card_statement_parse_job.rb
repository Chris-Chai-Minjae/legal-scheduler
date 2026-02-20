class CardStatementParseJob < ApplicationJob
  queue_as :default

  def perform(card_statement_id)
    statement = CardStatement.find(card_statement_id)

    # Guard: 이미 처리중이거나 완료된 statement는 재실행 방지 (idempotency)
    return if statement.parsing? || statement.completed?

    statement.update!(status: :parsing)

    # Guard: 파일 첨부 여부 확인
    unless statement.file.attached?
      statement.update!(status: :failed, error_message: "첨부된 파일이 없습니다")
      return
    end

    # Download attached file to temp location
    temp_file = Tempfile.new(["card_statement", ".xlsx"])
    temp_file.binmode
    temp_file.write(statement.file.download)
    temp_file.rewind

    # Parse Excel
    result = CardParserService.new(temp_file.path).parse

    # Build and validate expense records before insert
    if result.transactions.any?
      expense_records = result.transactions.filter_map do |t|
        next if t[:amount].blank? || t[:transaction_date].blank? || t[:card_name].blank?

        {
          card_statement_id: statement.id,
          user_id: statement.user_id,
          transaction_date: t[:transaction_date],
          merchant: t[:merchant],
          amount: t[:amount],
          currency: t[:currency] || "KRW",
          card_name: t[:card_name],
          cancelled: t[:cancelled] || false,
          classification_status: 0,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      Expense.insert_all(expense_records) if expense_records.any?
    end

    statement.update!(
      total_transactions: result.total_count,
      card_summary: result.card_summary
    )

    # Trigger classification job
    ExpenseClassifyJob.perform_later(statement.id)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[CardStatementParseJob] Statement #{card_statement_id} not found: #{e.message}")
  rescue => e
    statement&.update(status: :failed, error_message: e.message&.truncate(500))
    Rails.logger.error("[CardStatementParseJob] 실패: #{e.message}")
    raise
  ensure
    temp_file&.close
    temp_file&.unlink
  end
end
