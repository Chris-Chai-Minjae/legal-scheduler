# frozen_string_literal: true

module CardParsers
  class ShinhanParser < BaseParser
    # 신한카드: 행2+, 가맹점 col4, 금액 col6
    START_ROW = 2

    def parse
      transactions = []

      (START_ROW..@sheet.last_row).each do |row_num|
        row = row_values(row_num)
        next if row.nil? || row[0].nil?

        cancel_status = row[10] if row.length > 10
        next unless cancel_status.nil? || cancel_status.to_s.strip.empty? || cancel_status == 0

        date = parse_date(row[0])
        merchant = row[3].to_s.strip if row[3]
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
