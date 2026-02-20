# frozen_string_literal: true

module CardParsers
  class HdParser < BaseParser
    # 현대카드: 행4+, 취소 col11
    START_ROW = 4

    def parse
      transactions = []

      (START_ROW..@sheet.last_row).each do |row_num|
        row = row_values(row_num)
        next if row.nil? || row[0].nil?

        cancel_status = row[10] if row.length > 10
        next if cancelled?(cancel_status)

        date = parse_date(row[0])
        merchant = row[4].to_s.strip if row[4]
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
