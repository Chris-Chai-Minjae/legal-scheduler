class ExpenseExcelImportService
  COLUMN_MAP = {
    "거래일" => :transaction_date,
    "가맹점" => :merchant,
    "금액" => :amount,
    "카드사" => :card_name,
    "카테고리" => :category,
    "메모" => :memo,
    "적요" => :description
  }.freeze

  REQUIRED_FIELDS = %i[transaction_date amount].freeze

  Result = Struct.new(:expenses, :errors, keyword_init: true)

  def initialize(file, user:)
    @file = file
    @user = user
  end

  def call
    rows = parse_file
    build_expenses(rows)
  rescue CSV::MalformedCSVError => e
    Result.new(expenses: [], errors: ["CSV 파싱 오류: #{e.message}"])
  rescue StandardError => e
    Rails.logger.error("[ExpenseExcelImportService] #{e.class}: #{e.message}")
    Result.new(expenses: [], errors: ["파일 처리 오류: #{e.message}"])
  end

  private

  def parse_file
    ext = File.extname(@file.original_filename).downcase

    case ext
    when ".csv"
      parse_csv
    when ".xlsx", ".xls"
      parse_excel
    else
      raise "지원하지 않는 파일 형식입니다: #{ext}"
    end
  end

  def parse_csv
    content = @file.read.force_encoding("UTF-8")
    # BOM 제거
    content = content.sub("\xEF\xBB\xBF".force_encoding("UTF-8"), "")

    rows = []
    CSV.parse(content, headers: true) do |row|
      rows << row.to_h
    end
    rows
  end

  def parse_excel
    spreadsheet = Roo::Spreadsheet.open(@file.tempfile, extension: File.extname(@file.original_filename).delete(".").to_sym)
    sheet = spreadsheet.sheet(0)

    headers = sheet.row(1).map(&:to_s).map(&:strip)
    rows = []

    (2..sheet.last_row).each do |i|
      row_data = {}
      sheet.row(i).each_with_index do |cell, col_idx|
        row_data[headers[col_idx]] = cell.to_s.strip if headers[col_idx]
      end
      rows << row_data
    end
    rows
  end

  def build_expenses(rows)
    expenses = []
    errors = []

    rows.each_with_index do |row, idx|
      line_num = idx + 2 # 헤더가 1행이므로 데이터는 2행부터

      attrs = map_columns(row)
      row_errors = validate_row(attrs, line_num)

      if row_errors.any?
        errors.concat(row_errors)
        next
      end

      expense = @user.expenses.build(
        transaction_date: parse_date(attrs[:transaction_date]),
        merchant: attrs[:merchant],
        amount: parse_amount(attrs[:amount]),
        card_name: attrs[:card_name] || "미지정",
        category: normalize_category(attrs[:category]),
        memo: attrs[:memo],
        description: attrs[:description],
        classification_status: :manual
      )

      expenses << expense
    end

    Result.new(expenses: expenses, errors: errors)
  end

  def map_columns(row)
    mapped = {}
    row.each do |header, value|
      key = COLUMN_MAP[header.to_s.strip]
      mapped[key] = value.to_s.strip if key
    end
    mapped
  end

  def validate_row(attrs, line_num)
    errors = []

    if attrs[:transaction_date].blank?
      errors << "#{line_num}행: 거래일이 비어있습니다."
    elsif parse_date(attrs[:transaction_date]).nil?
      errors << "#{line_num}행: 거래일 형식이 올바르지 않습니다 (#{attrs[:transaction_date]})."
    end

    if attrs[:amount].blank?
      errors << "#{line_num}행: 금액이 비어있습니다."
    elsif parse_amount(attrs[:amount]).to_i == 0
      errors << "#{line_num}행: 금액은 0이 아니어야 합니다 (#{attrs[:amount]})."
    end

    errors
  end

  def parse_date(value)
    return nil if value.blank?

    # 다양한 날짜 형식 지원
    formats = ["%Y-%m-%d", "%Y/%m/%d", "%Y.%m.%d", "%m/%d/%Y", "%d-%m-%Y"]

    formats.each do |fmt|
      return Date.strptime(value.to_s.strip, fmt)
    rescue Date::Error
      next
    end

    # Date.parse 시도 (ISO 8601 등)
    Date.parse(value.to_s.strip)
  rescue Date::Error
    nil
  end

  def parse_amount(value)
    return 0 if value.blank?

    # 쉼표, 원, 공백, 통화기호 제거 (부호는 보존)
    cleaned = value.to_s.gsub(/[,\s원₩\\]/, "")
    cleaned.to_i
  end

  def normalize_category(value)
    return nil if value.blank?

    stripped = value.to_s.strip
    Expense::CATEGORIES.include?(stripped) ? stripped : nil
  end
end
