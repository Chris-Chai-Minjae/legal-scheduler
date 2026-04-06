# frozen_string_literal: true

module CardParsers
  class HanaParser < BaseParser
    CANCEL_STATUSES = %w[취소 부분취소 매출취소].freeze
    INVALID_PURCHASE = %w[미매입 매입취소].freeze

    def parse
      # 헤더 자동 감지로 형식 판별
      header = row_values(1)&.map { |v| v.to_s.strip } || []

      if header.any? { |h| h.include?("접수일자") || h.include?("원화사용금액") }
        parse_corporate_format(header)
      else
        parse_legacy_format
      end
    end

    private

    # 기업카드 매출전표 형식 (xlsx)
    # 헤더: 접수일자, 매출일자, 승인번호, 매출거래구분, 가맹점번호, 가맹점명, ..., 원화사용금액, 취소일자, ...
    def parse_corporate_format(header)
      date_col = header.index { |h| h.include?("매출일자") } || header.index { |h| h.include?("접수일자") } || 0
      merchant_col = header.index { |h| h.include?("가맹점명") } || 5
      amount_col = header.index { |h| h.include?("원화사용금액") } || 10
      cancel_col = header.index { |h| h.include?("취소일자") } || 11
      vat_col = header.index { |h| h.include?("부가세") }

      transactions = []

      (2..@sheet.last_row).each do |row_num|
        row = row_values(row_num)
        next if row.nil? || row[0].nil?

        # 취소 건 스킵 (취소일자가 있으면 취소)
        cancel_val = row[cancel_col].to_s.strip if row.length > cancel_col
        next if cancel_val.present? && cancel_val != " " && cancel_val.match?(/\d{4}/)

        date = parse_date(row[date_col])
        merchant = row[merchant_col].to_s.strip if row.length > merchant_col && row[merchant_col]
        amount = parse_comma_amount(row[amount_col])

        next if date.nil? || amount.nil? || amount <= 0

        vat = parse_comma_amount(row[vat_col]) if vat_col && row.length > vat_col

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

    # 기존 형식 (xls)
    # 행4+, 날짜 col0, 가맹점 col4, 금액 col5, 취소 col13
    def parse_legacy_format
      transactions = []

      (4..@sheet.last_row).each do |row_num|
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

    # 쉼표 포함 문자열 금액 파싱 ("19,800" → 19800)
    def parse_comma_amount(value)
      return nil if value.nil?
      str = value.to_s.strip.delete(",")
      return nil if str.empty?
      str.to_i
    end
  end
end
