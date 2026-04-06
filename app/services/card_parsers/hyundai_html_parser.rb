# frozen_string_literal: true

require "nokogiri"

module CardParsers
  class HyundaiHtmlParser
    def initialize(file_path, card_name)
      @file_path = file_path
      @card_name = card_name
    end

    def parse
      doc = Nokogiri::HTML(File.read(@file_path, encoding: "UTF-8"))
      transactions = []

      # Find the data table — must contain both 가맹점 and 승인금액 headers
      tables = doc.css("table")
      data_table = tables.find { |t| t.text.include?("가맹점") && t.text.include?("승인금액") }
      return transactions unless data_table

      rows = data_table.css("tr")
      return transactions if rows.empty?

      # Locate the header row by content
      header_row = rows.find { |r| r.text.include?("가맹점") }
      return transactions unless header_row

      headers = header_row.css("td, th").map { |td| td.text.strip }
      date_col     = headers.index { |h| h.include?("승인일") }      || 0
      merchant_col = headers.index { |h| h.include?("가맹점") }      || 4
      amount_col   = headers.index { |h| h.include?("승인금액") || h.include?("금액") } || 5
      cancel_col   = headers.index { |h| h.include?("취소") }

      header_index = rows.index(header_row)
      data_rows = rows[(header_index + 1)..]

      data_rows.each do |row|
        cells = row.css("td").map { |td| td.text.strip }
        next if cells.empty? || cells.length <= amount_col

        # Skip cancelled rows
        if cancel_col && cells[cancel_col].present? &&
           cells[cancel_col] != "-" && cells[cancel_col] != ""
          next
        end

        date     = parse_date_string(cells[date_col])
        merchant = cells[merchant_col]
        amount   = parse_amount_string(cells[amount_col])

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

    private

    def parse_date_string(str)
      return nil if str.nil? || str.strip.empty?

      cleaned = str.strip.gsub(/\s+/, " ")

      if (match = cleaned.match(/(\d{4})년\s*(\d{1,2})월\s*(\d{1,2})일/))
        Date.new(match[1].to_i, match[2].to_i, match[3].to_i)
      elsif (match = cleaned.match(/(\d{4})[.\-\/](\d{1,2})[.\-\/](\d{1,2})/))
        Date.new(match[1].to_i, match[2].to_i, match[3].to_i)
      elsif (match = cleaned.match(/(\d{2})[.\-\/](\d{1,2})[.\-\/](\d{1,2})/))
        year = match[1].to_i + 2000
        Date.new(year, match[2].to_i, match[3].to_i)
      end
    rescue ArgumentError
      nil
    end

    def parse_amount_string(str)
      return nil if str.nil? || str.strip.empty?

      cleaned = str.strip.delete(",").delete("원").delete(" ")
      return nil if cleaned.empty?

      cleaned.to_i
    rescue StandardError
      nil
    end
  end
end
