# frozen_string_literal: true

module CardParsers
  class BcParser < BaseParser
    # 비씨카드: 행2+, 날짜 col1, 가맹점 col5, 금액 col6, 취소 col10
    START_ROW = 2

    def parse
      transactions = []

      (START_ROW..@sheet.last_row).each do |row_num|
        row = row_values(row_num)
        next if row.nil? || row.compact.empty?

        date_val = row[0]
        merchant = row[4].to_s.strip if row[4]
        amount = parse_amount(row[5])
        cancel_status = row[9]

        next if cancel_status.present? && cancel_status.to_s.strip != "-"
        date = parse_date(date_val)
        next if date.nil? || amount.nil?

        transactions << build_transaction(date, merchant, amount)
      end

      transactions
    end

    private

    def build_transaction(date, merchant, amount)
      {
        transaction_date: date,
        merchant: merchant,
        amount: amount,
        currency: "KRW",
        card_name: @card_name,
        cancelled: false
      }
    end
  end
end
