class ExpenseClassifyJob < ApplicationJob
  queue_as :default

  def perform(card_statement_id)
    statement = CardStatement.find(card_statement_id)

    # Guard: 완료된 statement만 재실행 방지 (classifying 상태에서 실패 후 재시도 허용)
    return if statement.completed?

    statement.update!(status: :classifying)

    expenses = statement.expenses.pending
    initial_count = expenses.count
    failure_count = 0

    expenses.find_each do |expense|
      begin
        # 규칙 기반 사전 분류 시도 — 매칭되면 AI 호출 스킵
        rule_result = ExpenseClassifierService.rule_based_classify(merchant: expense.merchant)

        if rule_result
          result = rule_result
          description = ExpenseClassifierService.format_description(
            result[:memo],
            expense.merchant,
            expense.card_name
          )

          expense.update!(
            category: result[:category],
            memo: result[:remarks] || result[:memo],
            description: description,
            classification_status: :classified
          )
        else
          # AI 분류 (DeepSeek)
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

          # Rate limit: AI 호출 시에만 대기
          sleep(0.1)
        end

        # Atomic increment로 race condition 방지
        CardStatement.where(id: statement.id).update_all(
          ["classified_transactions = classified_transactions + 1, updated_at = ?", Time.current]
        )
      rescue => e
        expense.update(classification_status: :failed)
        failure_count += 1
        Rails.logger.error("[ExpenseClassifyJob] 경비 #{expense.id} 분류 실패: #{e.message}")
      end
    end

    # 전체 실패 시 failed, 부분 실패 시 completed (로그에 실패 건수 기록)
    if failure_count == initial_count && initial_count > 0
      statement.reload
      statement.update!(status: :failed, error_message: "전체 #{initial_count}건 분류 실패")
    else
      statement.reload
      if failure_count > 0
        Rails.logger.warn("[ExpenseClassifyJob] Statement #{statement.id}: #{failure_count}/#{initial_count}건 분류 실패")
      end
      statement.update!(status: :completed)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[ExpenseClassifyJob] Statement #{card_statement_id} not found: #{e.message}")
  rescue => e
    statement&.update(status: :failed, error_message: e.message&.truncate(500))
    Rails.logger.error("[ExpenseClassifyJob] 실패: #{e.message}")
    raise
  end
end
