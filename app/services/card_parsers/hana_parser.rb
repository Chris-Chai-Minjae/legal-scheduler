# frozen_string_literal: true

module CardParsers
  class HanaParser < BaseParser
    # 하나카드: 행4+, 복합 상태 체크
    START_ROW = 4
    CANCEL_STATUSES = %w[취소 부분취소 매출취소].freeze
    INVALID_PURCHASE = %w[미매입 매입취소].freeze

    def parse
      transactions = []

      (START_ROW..@sheet.last_row).each do |row_num|
        row = row_values(row_num)
        next if row.nil? || row[0].nil?

        cancel_status = row[13].to_s.strip if row.length > 13
        purchase_status = row[9].to_s.strip if row.length > 9

        next if CANCEL_STATUSES.include?(cancel_status)
        next if INVALID_PURCHASE.include?(purchase_status)

        date = parse_date(row[0])
        merchant = row[4].to_s.strip.delete_suffix("\\") if row[4]
        amount = parse_amount(row[5])

        next if date.nil? || amount.nil?

        transactions << {
          transaction_date: date,
          merchant: merchant,
          amount: amount,
          currency: "KRW",
          card_name: @card_name,
          cancelled: false
        }
      end

      transactions
    end
  end
end
