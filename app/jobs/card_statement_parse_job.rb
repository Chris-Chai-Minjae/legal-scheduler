class CardStatementParseJob < ApplicationJob
  queue_as :default

  def perform(card_statement_id)
    statement = CardStatement.find(card_statement_id)
    statement.update!(status: :parsing)

    # Download attached file to temp location
    temp_file = Tempfile.new(["card_statement", ".xlsx"])
    temp_file.binmode
    temp_file.write(statement.file.download)
    temp_file.rewind

    # Parse Excel
    result = CardParserService.new(temp_file.path).parse

    # Bulk insert expenses
    if result.transactions.any?
      expense_records = result.transactions.map do |t|
        {
          card_statement_id: statement.id,
          user_id: statement.user_id,
          transaction_date: t[:transaction_date],
          merchant: t[:merchant],
          amount: t[:amount],
          currency: t[:currency],
          card_name: t[:card_name],
          cancelled: t[:cancelled] || false,
          classification_status: 0,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      Expense.insert_all(expense_records)
    end

    statement.update!(
      total_transactions: result.total_count,
      card_summary: result.card_summary
    )

    # Trigger classification job
    ExpenseClassifyJob.perform_later(statement.id)
  rescue => e
    statement&.update(status: :failed, error_message: e.message)
    Rails.logger.error("[CardStatementParseJob] 실패: #{e.message}")
    raise
  ensure
    temp_file&.close
    temp_file&.unlink
  end
end
