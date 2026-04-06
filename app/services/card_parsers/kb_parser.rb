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

        foreign_amount = nil
        foreign_currency = nil

        if amt_krw.present? && amt_krw != 0
          amount = amt_krw
          # 해외결제인 경우 외화 금액도 기록
          if amt_fx.present? && amt_fx != 0
            foreign_amount = amt_fx
            currency_col = row[8].to_s.strip if row.length > 8
            foreign_currency = currency_col.present? && currency_col.match?(/\A[A-Z]{3}\z/) ? currency_col : "USD"
          end
        else
          # 원화 금액이 없으면 외화 금액을 amount에 넣고 표시
          amount = amt_fx
          foreign_amount = amt_fx
          currency_col = row[8].to_s.strip if row.length > 8
          foreign_currency = currency_col.present? && currency_col.match?(/\A[A-Z]{3}\z/) ? currency_col : "USD"
        end

        next if date.nil? || amount.nil?

        transactions << {
          transaction_date: date,
          merchant: merchant,
          amount: amount,
          currency: "KRW",
          card_name: @card_name,
          cancelled: false,
          foreign_amount: foreign_amount,
          foreign_currency: foreign_currency
        }
      end

      transactions
    end
  end
end
