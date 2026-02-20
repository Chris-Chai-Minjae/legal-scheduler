# frozen_string_literal: true

module CardParsers
  class KbParser < BaseParser
    # 국민카드: 행8+, 이중 통화 처리
    START_ROW = 8

    def parse
      transactions = []

      (START_ROW..@sheet.last_row).each do |row_num|
        row = row_values(row_num)
        next if row.nil? || row[0].nil?

        cancel_status = row[11] if row.length > 11
        next if cancelled?(cancel_status)

        date = parse_date(row[0])
        merchant = row[4].to_s.strip if row[4]
        amt_krw = parse_amount(row[5]) if row.length > 5
        amt_fx = parse_amount(row[6]) if row.length > 6

        if amt_krw.present? && amt_krw != 0
          amount = amt_krw
          currency = "KRW"
        else
          amount = amt_fx
          currency = "USD"
        end

        next if date.nil? || amount.nil?

        transactions << {
          transaction_date: date,
          merchant: merchant,
          amount: amount,
          currency: currency,
          card_name: @card_name,
          cancelled: false
        }
      end

      transactions
    end
  end
end
