# frozen_string_literal: true

module CardParsers
  class ShinhanParser < BaseParser
    START_ROW = 2

    def parse
      # Detect column positions from header row (Roo row 1, 1-based)
      header = row_values(1).map { |v| v.to_s.strip }
      merchant_col = header.index { |h| h.include?("가맹점") } || 3
      amount_col   = header.index { |h| h.include?("금액") }   || 5
      cancel_col   = header.index { |h| h.include?("취소") }   || 10

      transactions = []

      (START_ROW..@sheet.last_row).each do |row_num|
        row = row_values(row_num)
        next if row.nil? || row[0].nil?

        cancel_status = row[cancel_col] if row.length > cancel_col
        next unless cancel_status.nil? || cancel_status.to_s.strip.empty? || cancel_status == 0

        date     = parse_date(row[0])
        merchant = row[merchant_col].to_s.strip if row.length > merchant_col && row[merchant_col]
        amount   = parse_amount(row[amount_col]) if row.length > amount_col

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
