# frozen_string_literal: true

require "roo"

class CardParserService
  CARD_PROCESSORS = {
    "비씨카드" => CardParsers::BcParser,
    "국민카드" => CardParsers::KbParser,
    "현대카드" => CardParsers::HdParser,
    "신한카드" => CardParsers::ShinhanParser,
    "하나카드" => CardParsers::HanaParser,
    "삼성카드" => CardParsers::SamsungParser
  }.freeze

  Result = Data.define(:transactions, :card_summary, :total_count, :errors)

  # 파일명에서 카드사를 감지하기 위한 패턴
  FILENAME_PATTERNS = {
    /비씨|bc/i => "비씨카드",
    /국민|kb|kookmin/i => "국민카드",
    /현대|hd|hyundai/i => "현대카드",
    /신한|shinhan/i => "신한카드",
    /하나|hana/i => "하나카드",
    /삼성|samsung/i => "삼성카드",
    /하이패스|hipass/i => "하이패스"
  }.freeze

  def initialize(file_path, original_filename: nil)
    @file_path = file_path
    @original_filename = original_filename
  end

  def parse
    ext = File.extname(@file_path).delete(".")
    xlsx = open_spreadsheet(@file_path, ext)

    # HTML 형식 파일인 경우 (한국 카드사가 .xls로 저장한 HTML)
    return parse_as_html if xlsx.nil?

    all_transactions = []
    card_summary = {}
    errors = []
    matched_sheets = []

    # 1단계: 시트 이름으로 카드사 매칭 (기존 로직)
    CARD_PROCESSORS.each do |sheet_name, parser_class|
      next unless xlsx.sheets.include?(sheet_name)
      matched_sheets << sheet_name

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

    # 2단계: 시트 매칭이 없으면 파일명에서 카드사 감지 → 적절한 시트로 파싱
    if matched_sheets.empty? && @original_filename.present?
      detected_card = detect_card_from_filename(@original_filename)
      parser_class = CARD_PROCESSORS[detected_card] if detected_card

      if parser_class
        begin
          # 삼성카드는 데이터가 "■ 국내이용내역" 시트에 있음
          target_sheet = if detected_card == "삼성카드" && xlsx.sheets.any? { |s| s.include?("국내이용내역") }
            xlsx.sheets.find { |s| s.include?("국내이용내역") }
          else
            xlsx.sheets.first
          end
          sheet = xlsx.sheet(target_sheet)
          parser = parser_class.new(sheet, detected_card)
          transactions = parser.parse
          all_transactions.concat(transactions)
          card_summary[detected_card] = transactions.size
          Rails.logger.info("[CardParserService] 파일명 기반 파싱: #{@original_filename} → #{detected_card} (#{transactions.size}건)")
        rescue => e
          errors << "#{detected_card}(파일명 감지): #{e.message}"
          Rails.logger.error("[CardParserService] 파일명 기반 파싱 실패: #{e.message}")
        end
      else
        Rails.logger.warn("[CardParserService] 카드사 감지 실패: #{@original_filename}, sheets=#{xlsx.sheets}")
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

  private

  # .xls 파일이 OLE2(바이너리)가 아닌 HTML/XML 형식일 때 폴백
  # 두 시도가 모두 실패하면 nil을 반환 → HTML 파싱으로 위임
  def open_spreadsheet(file_path, ext)
    Roo::Spreadsheet.open(file_path, extension: ext.presence || "xlsx")
  rescue Ole::Storage::FormatError
    Rails.logger.info("[CardParserService] OLE2 실패, XML 형식으로 재시도: #{@original_filename}")
    begin
      Roo::Spreadsheet.open(file_path, extension: "xlsx")
    rescue => e
      Rails.logger.info("[CardParserService] XML도 실패, HTML 시도 예정: #{@original_filename} (#{e.message})")
      nil
    end
  end

  def parse_as_html
    detected_card = detect_card_from_filename(@original_filename) if @original_filename.present?
    card_name = detected_card || "현대카드"

    parser = CardParsers::HyundaiHtmlParser.new(@file_path, card_name)
    transactions = parser.parse

    card_summary = {}
    card_summary[card_name] = transactions.size if transactions.any?

    Rails.logger.info("[CardParserService] HTML 파싱: #{@original_filename} → #{card_name} (#{transactions.size}건)")

    Result.new(
      transactions: transactions,
      card_summary: card_summary,
      total_count: transactions.size,
      errors: []
    )
  end

  def detect_card_from_filename(filename)
    name = File.basename(filename, File.extname(filename))
    # macOS NFD 유니코드 정규화 (자모 분리 → 완성형)
    name = name.unicode_normalize(:nfc) if name.respond_to?(:unicode_normalize)
    FILENAME_PATTERNS.each do |pattern, card_name|
      return card_name if name.match?(pattern)
    end
    nil
  end
end
