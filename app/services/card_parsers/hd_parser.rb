# frozen_string_literal: true

module CardParsers
  class HdParser < BaseParser
    def parse
      # 헤더 자동 감지로 형식 판별
      header_row, header = detect_header
      if header && header.any? { |h| h.include?("이용일") && h.include?("가맹점명") }
        parse_xlsx_format(header_row, header)
      else
        parse_legacy_format
      end
    end

    private

    # 현대카드 xlsx 형식 (헤더가 9행 등에 위치)
    # 이용일, 카드번호, 가맹점명, 승인금액, 이용금액, 부가세, 관계, 할부, 상태, ...
    def parse_xlsx_format(header_row, header)
      date_col = header.index { |h| h.include?("이용일") } || 0
      merchant_col = header.index { |h| h.include?("가맹점명") } || 2
      amount_col = header.index { |h| h.include?("이용 금액") || h.include?("이용금액") } || header.index { |h| h.include?("승인 금액") || h.include?("승인금액") } || 3
      status_col = header.index { |h| h.include?("상태") }
      vat_col = header.index { |h| h.include?("부가세") }

      transactions = []

      ((header_row + 1)..@sheet.last_row).each do |row_num|
        row = row_values(row_num)
        next if row.nil? || row[date_col].nil?

        # 취소 건 스킵
        if status_col && row.length > status_col
          status = row[status_col].to_s.strip
          next if status.include?("취소")
        end

        date = parse_date(row[date_col])
        merchant = row[merchant_col].to_s.strip if row.length > merchant_col && row[merchant_col]
        amount = parse_comma_amount(row[amount_col])

        next if date.nil? || amount.nil? || amount <= 0

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

    # 기존 형식 (xls) — 행4+, 날짜 col0, 가맹점 col4, 금액 col5, 취소 col10
    def parse_legacy_format
      transactions = []

      (4..@sheet.last_row).each do |row_num|
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

    # 헤더 행 자동 감지 (1~15행 스캔)
    def detect_header
      (1..[15, @sheet.last_row].min).each do |row_num|
        row = row_values(row_num)&.map { |v| v.to_s.strip }
        next if row.nil?
        if row.any? { |h| h.include?("이용일") } && row.any? { |h| h.include?("가맹점") }
          return [row_num, row]
        end
      end
      [nil, nil]
    end

    def parse_comma_amount(value)
      return nil if value.nil?
      str = value.to_s.strip.delete(",")
      return nil if str.empty?
      str.to_i
    end
  end
end
