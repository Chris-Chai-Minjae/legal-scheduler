# frozen_string_literal: true

require "roo"

class CardParserService
  CARD_PROCESSORS = {
    "비씨카드" => CardParsers::BcParser,
    "국민카드" => CardParsers::KbParser,
    "현대카드" => CardParsers::HdParser,
    "신한카드" => CardParsers::ShinhanParser,
    "하나카드" => CardParsers::HanaParser
  }.freeze

  Result = Data.define(:transactions, :card_summary, :total_count, :errors)

  def initialize(file_path)
    @file_path = file_path
  end

  def parse
    xlsx = Roo::Excelx.new(@file_path)
    all_transactions = []
    card_summary = {}
    errors = []

    CARD_PROCESSORS.each do |sheet_name, parser_class|
      next unless xlsx.sheets.include?(sheet_name)

      begin
        sheet = xlsx.sheet(sheet_name)
        parser = parser_class.new(sheet, sheet_name)
        transactions = parser.parse
        all_transactions.concat(transactions)
        card_summary[sheet_name] = transactions.size
      rescue => e
        errors << "#{sheet_name}: #{e.message}"
        Rails.logger.error("[CardParserService] #{sheet_name} 파싱 실패: #{e.message}")
      end
    end

    all_transactions.sort_by! { |t| t[:transaction_date] || Date.new(1970, 1, 1) }

    Result.new(
      transactions: all_transactions,
      card_summary: card_summary,
      total_count: all_transactions.size,
      errors: errors
    )
  end
end
