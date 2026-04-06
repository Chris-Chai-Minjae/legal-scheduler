# frozen_string_literal: true

module CardParsers
  class SamsungParser < BaseParser
    START_ROW = 2  # Roo 1-based; row 1 is the header, data starts at row 2

    def parse
      transactions = []

      (START_ROW..@sheet.last_row).each do |row_num|
        row = row_values(row_num)
        next if row.nil? || row[2].nil?

        cancel_status = row[9].to_s.strip if row.length > 9
        next if cancel_status == "취소"

        date     = parse_date(row[2])
        merchant = row[4].to_s.strip if row[4]
        amount   = parse_amount(row[5])

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
