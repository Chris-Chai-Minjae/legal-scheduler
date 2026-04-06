# frozen_string_literal: true

require "zip"
require "nokogiri"
require "fileutils"

class HwpxGeneratorService
  TEMPLATE_PATH = Rails.root.join("app", "assets", "templates", "cost.hwpx")

  Result = Data.define(:success, :output_path, :error)

  def initialize(expenses)
    @expenses = expenses
  end

  def generate
    return Result.new(success: false, output_path: nil, error: "경비 데이터가 없습니다") if @expenses.empty?

    temp_dir = Dir.mktmpdir("hwpx_work")
    output_path = File.join(Dir.tmpdir, "expense_report_#{SecureRandom.hex(8)}.hwpx")

    extract_template(temp_dir)

    xml_path = File.join(temp_dir, "Contents", "section0.xml")
    generate_pages(xml_path)

    repackage(temp_dir, output_path)

    Result.new(success: true, output_path: output_path, error: nil)
  rescue => e
    Rails.logger.error("[HwpxGeneratorService] 생성 실패: #{e.class}: #{e.message}")
    Result.new(success: false, output_path: nil, error: e.message)
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
  end

  private

  def extract_template(temp_dir)
    Zip::File.open(TEMPLATE_PATH.to_s) do |zip|
      zip.each do |entry|
        dest = File.join(temp_dir, entry.name)
        dest_real = File.expand_path(dest)
        unless dest_real.start_with?(File.expand_path(temp_dir))
          raise SecurityError, "Zip path traversal detected: #{entry.name}"
        end
        FileUtils.mkdir_p(File.dirname(dest))
        entry.extract(dest)
      end
    end
  end

  def generate_pages(xml_path)
    xml_content = File.read(xml_path)

    # XML을 파싱해서 body 내 자식 노드들의 XML 문자열을 추출 (= 1페이지 템플릿)
    doc = Nokogiri::XML(xml_content)
    body = doc.root

    # secPr (섹션 속성)은 마지막에 한 번만 있어야 함 — 분리
    sec_pr = body.at_xpath("hp:secPr", "hp" => body.namespace&.href || body.namespaces.values.first)
    sec_pr_xml = sec_pr&.to_xml || ""
    sec_pr&.remove

    # 나머지 = 페이지 템플릿
    template_xml = body.children.to_xml

    # body를 비우고 경비별 페이지 생성
    body.children.each(&:remove)

    @expenses.each_with_index do |expense, idx|
      page_xml = fill_template(template_xml, expense)

      # 2번째 페이지부터 pageBreak 추가
      if idx > 0
        page_xml = page_xml.sub(/<hp:p /, '<hp:p pageBreak="1" ')
      end

      # body에 추가 (XML 프래그먼트로 파싱)
      fragment = Nokogiri::XML.fragment(page_xml)
      fragment.children.each { |child| body.add_child(child) }
    end

    # secPr 복원 (마지막에)
    if sec_pr_xml.present?
      body.add_child(Nokogiri::XML.fragment(sec_pr_xml))
    end

    File.write(xml_path, doc.to_xml)
  end

  def fill_template(template_xml, expense)
    values = build_field_values(expense)
    result = template_xml.dup

    # 각 필드의 누름틀 값을 치환
    # 패턴: <hp:fieldBegin ... name="date" ... type="CLICK_HERE" ...> 다음의 <hp:t>값</hp:t>
    values.each do |field_name, value|
      escaped_value = escape_xml(value)
      pattern = /(name="#{Regexp.escape(field_name)}"[^>]*type="CLICK_HERE"|type="CLICK_HERE"[^>]*name="#{Regexp.escape(field_name)}")(.*?<hp:t>)(.*?)(<\/hp:t>)/m
      result = result.gsub(pattern) do
        "#{$1}#{$2}#{escaped_value}#{$4}"
      end
    end

    result
  end

  def build_field_values(expense)
    date = expense.transaction_date
    date_str = date ? "#{date.year}. #{date.month}. #{date.day}." : ""

    memo_desc = if expense.description.present?
      match = expense.description.match(/^(.*?)\(/)
      match ? match[1].strip : (expense.memo || "기타지출")
    else
      expense.memo || "기타지출"
    end

    {
      "date" => date_str,
      "date2" => date_str,
      "amount" => expense.formatted_amount,
      "merchant" => expense.merchant || "(미상)",
      "category" => expense.category || "잡비",
      "memo" => memo_desc
    }
  end

  def escape_xml(text)
    text.to_s.encode(xml: :text)
  end

  def repackage(temp_dir, output_path)
    Zip::OutputStream.open(output_path) do |zos|
      mimetype_path = File.join(temp_dir, "mimetype")
      if File.exist?(mimetype_path)
        zos.put_next_entry("mimetype", nil, nil, Zip::Entry::STORED)
        zos.write(File.read(mimetype_path))
      end

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
