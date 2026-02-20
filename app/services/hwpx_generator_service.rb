# frozen_string_literal: true

require "zip"
require "nokogiri"
require "tempfile"
require "fileutils"

class HwpxGeneratorService
  TEMPLATE_PATH = Rails.root.join("app", "assets", "templates", "cost.hwpx")
  NS_PARA = "http://www.hancom.co.kr/hwpml/2011/paragraph"
  TEMPLATE_PARA_RANGE = (2..31) # 30 template paragraphs

  Result = Data.define(:success, :output_path, :error)

  def initialize(expenses)
    @expenses = expenses
  end

  # NOTE: 호출자(caller)는 사용 완료 후 output_path 파일을 반드시 삭제해야 합니다.
  # 예: FileUtils.rm_f(result.output_path) if result.success
  def generate
    temp_dir = Dir.mktmpdir("hwpx_work")
    output_file = Tempfile.new(["expense_report", ".hwpx"])
    output_path = output_file.path
    output_file.close

    # 1. Extract HWPX template
    extract_template(temp_dir)

    # 2. Parse and modify XML
    xml_path = File.join(temp_dir, "Contents", "section0.xml")
    modify_xml(xml_path)

    # 3. Repackage as HWPX
    repackage(temp_dir, output_path)

    Result.new(success: true, output_path: output_path, error: nil)
  rescue => e
    Rails.logger.error("[HwpxGeneratorService] 생성 실패: #{e.message}")
    Result.new(success: false, output_path: nil, error: e.message)
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
  end

  private

  def extract_template(temp_dir)
    Zip::File.open(TEMPLATE_PATH.to_s) do |zip|
      zip.each do |entry|
        dest = File.join(temp_dir, entry.name)
        # Zip path traversal 방어: 추출 경로가 temp_dir 내부인지 검증
        dest_real = File.expand_path(dest)
        unless dest_real.start_with?(File.expand_path(temp_dir))
          raise SecurityError, "Zip path traversal detected: #{entry.name}"
        end
        FileUtils.mkdir_p(File.dirname(dest))
        entry.extract(dest)
      end
    end
  end

  def modify_xml(xml_path)
    doc = Nokogiri::XML(File.read(xml_path))

    all_paras = doc.xpath("//para:p", "para" => NS_PARA)
    template_paras = all_paras[TEMPLATE_PARA_RANGE]

    return if template_paras.nil? || template_paras.empty?

    # Remove only template paragraphs (preserve header paras before TEMPLATE_PARA_RANGE)
    template_paras.each(&:remove)

    # Generate one page per expense
    @expenses.each_with_index do |expense, idx|
      replacements = build_replacements(expense)

      template_paras.each_with_index do |para, para_idx|
        new_para = para.dup

        # Page break for 2nd+ documents
        if idx > 0 && para_idx == 0
          new_para["pageBreak"] = "1"
        end

        replace_in_paragraph(new_para, replacements)
        doc.root.add_child(new_para)
      end
    end

    File.write(xml_path, doc.to_xml)
  end

  def build_replacements(expense)
    date = expense.transaction_date
    memo = expense.memo || "기타지출"
    merchant = expense.merchant || "(미상)"

    # Parse description field for memo_desc
    memo_desc = if expense.description.present?
      match = expense.description.match(/^(.*?)\(/)
      match ? match[1].strip : memo
    else
      memo
    end

    {
      date: "#{date.year}. #{date.month}. #{date.day}.",
      amount: expense.formatted_amount,
      merchant: merchant,
      category: expense.category || "잡비",
      memo_desc: memo_desc
    }
  end

  def replace_in_paragraph(para, replacements)
    para.xpath(".//para:t", "para" => NS_PARA).each do |t_elem|
      text = t_elem.text
      next if text.blank?

      if text.include?("지출일자") && text.include?(":")
        t_elem.content = "지출일자 :  #{replacements[:date]}"
      elsif text.strip.start_with?("금")
        parts = text.split(":", 2)
        if parts.length == 2
          new_suffix = parts[1].gsub(/\d{1,3}(?:,\d{3})*원/, replacements[:amount])
          t_elem.content = "#{parts[0]}:#{new_suffix}"
        else
          t_elem.content = "금   액  : #{replacements[:amount]}"
        end
      elsif text.strip.start_with?("지출처")
        t_elem.content = "지출처 : #{replacements[:merchant]}"
      elsif text.strip.start_with?("계정과목")
        t_elem.content = "계정과목 :  #{replacements[:category]}"
      elsif text.include?(":") && text.include?("적") && text.include?("요")
        t_elem.content = "적   요  :  #{replacements[:memo_desc]}"
      elsif text.match?(/^\s*\d{4}\.\s*\d{1,2}\.\s*\d{1,2}\.\s*$/)
        t_elem.content = replacements[:date]
      end
    end
  end

  def repackage(temp_dir, output_path)
    Zip::OutputStream.open(output_path) do |zos|
      # mimetype must be first and STORED (not compressed)
      mimetype_path = File.join(temp_dir, "mimetype")
      if File.exist?(mimetype_path)
        zos.put_next_entry("mimetype", nil, nil, Zip::Entry::STORED)
        zos.write(File.read(mimetype_path))
      end

      # All other files - DEFLATED
      Dir.glob(File.join(temp_dir, "**", "*")).each do |file_path|
        next if File.directory?(file_path)
        next if File.basename(file_path) == "mimetype"

        relative_path = file_path.sub("#{temp_dir}/", "")
        zos.put_next_entry(relative_path, nil, nil, Zip::Entry::DEFLATED)
        zos.write(File.binread(file_path))
      end
    end
  end
end
