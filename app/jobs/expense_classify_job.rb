class ExpenseClassifyJob < ApplicationJob
  queue_as :default

  def perform(card_statement_id)
    statement = CardStatement.find(card_statement_id)
    statement.update!(status: :classifying)

    expenses = statement.expenses.pending
    classified_count = statement.classified_transactions

    expenses.find_each do |expense|
      begin
        result = ExpenseClassifierService.classify(
          merchant: expense.merchant,
          amount: expense.amount,
          card_name: expense.card_name
        )

        description = ExpenseClassifierService.format_description(
          result[:memo],
          expense.merchant,
          expense.card_name
        )

        expense.update!(
          category: result[:category],
          memo: result[:memo],
          description: description,
          classification_status: :classified
        )

        classified_count += 1
        statement.update_column(:classified_transactions, classified_count)
      rescue => e
        expense.update(classification_status: :failed)
        Rails.logger.error("[ExpenseClassifyJob] 경비 #{expense.id} 분류 실패: #{e.message}")
      end

      # Rate limit: brief pause between API calls
      sleep(0.1)
    end

    statement.update!(status: :completed)
  rescue => e
    statement&.update(status: :failed, error_message: e.message)
    Rails.logger.error("[ExpenseClassifyJob] 실패: #{e.message}")
    raise
  end
end
