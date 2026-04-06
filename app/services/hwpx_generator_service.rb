# frozen_string_literal: true

require "zip"
require "nokogiri"
require "fileutils"

class HwpxGeneratorService
  TEMPLATE_PATH = Rails.root.join("app", "assets", "templates", "cost.hwpx")

  # 누름틀(CLICK_HERE) 필드 이름
  FIELD_NAMES = %w[date date2 amount merchant category memo].freeze

  Result = Data.define(:success, :output_path, :error)

  def initialize(expenses)
    @expenses = expenses
  end

  # NOTE: 호출자(caller)는 사용 완료 후 output_path 파일을 반드시 삭제해야 합니다.
  def generate
    temp_dir = Dir.mktmpdir("hwpx_work")
    output_path = File.join(Dir.tmpdir, "expense_report_#{SecureRandom.hex(8)}.hwpx")

    extract_template(temp_dir)

    xml_path = File.join(temp_dir, "Contents", "section0.xml")
    modify_xml_with_fields(xml_path)

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

  def modify_xml_with_fields(xml_path)
    xml_content = File.read(xml_path)
    doc = Nokogiri::XML(xml_content)

    # 템플릿의 body(root) 내 모든 자식 노드 = 1페이지 분량
    body = doc.root
    template_children = body.children.to_a.dup

    # 첫 번째 경비: 템플릿 자체의 누름틀 값 교체
    if @expenses.any?
      fill_fields(doc, build_field_values(@expenses.first))
    end

    # 2번째 경비부터: 템플릿 페이지를 복제하고 필드 값 교체
    @expenses.drop(1).each do |expense|
      values = build_field_values(expense)

      # 페이지 구분을 위해 첫 번째 paragraph에 pageBreak 설정
      page_nodes = template_children.map(&:dup)

      first_para = page_nodes.find { |n| n.name == "p" }
      first_para["pageBreak"] = "1" if first_para

      # 누름틀 값 교체
      page_nodes.each do |node|
        fill_fields_in_node(node, values)
      end

      # body에 추가
      page_nodes.each { |node| body.add_child(node) }
    end

    File.write(xml_path, doc.to_xml)
  end

  def build_field_values(expense)
    date = expense.transaction_date
    date_str = "#{date.year}. #{date.month}. #{date.day}."

    # 비고(description)에서 적요 추출: "직원 식대(빅빅버거,비씨카드)" → "직원 식대"
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

  # XML 전체에서 누름틀 필드 값 교체
  def fill_fields(doc, values)
    fill_fields_in_node(doc.root, values)
  end

  # 특정 노드 내에서 누름틀 필드 값 교체
  def fill_fields_in_node(node, values)
    # hp:fieldBegin ... </hp:fieldBegin> [텍스트] <hp:fieldEnd/> 패턴
    node.xpath(".//hp:fieldBegin[@type='CLICK_HERE']", "hp" => detect_namespace(node)).each do |field_begin|
      field_name = field_begin["name"]
      next unless values.key?(field_name)

      # fieldBegin 다음 형제 노드들을 순회하며 hp:t 텍스트를 찾아 교체
      sibling = field_begin.next_sibling
      while sibling
        if sibling.name == "fieldEnd"
          break
        elsif sibling.name == "t"
          sibling.content = values[field_name]
          break
        else
          # 중첩된 노드 내부의 hp:t 검색
          t_elem = sibling.at_xpath(".//hp:t", "hp" => detect_namespace(node))
          if t_elem
            t_elem.content = values[field_name]
            break
          end
        end
        sibling = sibling.next_sibling
      end
    end

    # 부모 p 노드의 직접 자식으로 있는 경우도 처리
    node.xpath(".//hp:p", "hp" => detect_namespace(node)).each do |para|
      para.children.each do |child|
        next unless child.element? && child.name == "fieldBegin" && child["type"] == "CLICK_HERE"

        field_name = child["name"]
        next unless values.key?(field_name)

        # 같은 부모(run) 내의 다음 t 요소를 찾아 교체
        current = child
        while (current = current.next_sibling)
          break if current.name == "fieldEnd"

          t_nodes = if current.name == "t"
            [current]
          else
            current.xpath(".//hp:t", "hp" => detect_namespace(node)).to_a
          end

          if t_nodes.any?
            t_nodes.first.content = values[field_name]
            break
          end
        end
      end
    end
  end

  def detect_namespace(node)
    doc = node.is_a?(Nokogiri::XML::Document) ? node : node.document
    ns = doc.root.namespaces
    # hp 네임스페이스 찾기
    ns.each do |prefix, uri|
      return uri if prefix == "xmlns:hp" || uri.include?("hancom")
    end
    # 기본 네임스페이스
    ns["xmlns"] || "http://www.hancom.co.kr/hwpml/2011/paragraph"
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
