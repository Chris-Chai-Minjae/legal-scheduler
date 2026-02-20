# frozen_string_literal: true

module CardParsers
  class BaseParser
    EXCEL_EPOCH = Date.new(1899, 12, 30)

    DATE_FORMATS = [
      "%Y-%m-%d %H:%M",
      "%Y-%m-%d",
      "%Y.%m.%d %H:%M:%S",
      "%Y.%m.%d %H:%M",
      "%Y.%m.%d"
    ].freeze

    def initialize(sheet, card_name)
      @sheet = sheet
      @card_name = card_name
    end

    def parse
      raise NotImplementedError
    end

    private

    def parse_amount(value)
      return nil if value.nil?

      case value
      when Integer
        value
      when Float
        return nil if value.nan? || value.infinite?
        value.round
      when String
        cleaned = value.strip.delete(",")
        return nil if cleaned.empty?
        cleaned.to_f.round
      else
        nil
      end
    end

    def parse_date(value)
      return nil if value.nil? || (value.is_a?(String) && value.strip.empty?)

      case value
      when Date
        value
      when DateTime, Time
        value.to_date
      when Numeric
        (EXCEL_EPOCH + value.to_i).rescue_nil
      when String
        parse_date_string(value)
      else
        nil
      end
    rescue
      nil
    end

    def parse_date_string(str)
      cleaned = str.strip.gsub(/[\n\t]/, " ").gsub(/\s+/, " ")

      DATE_FORMATS.each do |fmt|
        return Date.strptime(cleaned, fmt)
      rescue Date::Error, ArgumentError
        next
      end

      # Fallback: extract YYYY-MM-DD or YYYY.MM.DD pattern
      if (match = cleaned.match(/^(\d{4})[.\-](\d{2})[.\-](\d{2})/))
        Date.new(match[1].to_i, match[2].to_i, match[3].to_i)
      end
    rescue
      nil
    end

    def cancelled?(status_value, cancel_keywords = ["취소"])
      return false if status_value.nil?
      str = status_value.to_s.strip
      return false if str.empty? || str == "-"
      cancel_keywords.any? { |kw| str.include?(kw) }
    end

    def row_values(row_number)
      @sheet.row(row_number)
    end
  end
end
