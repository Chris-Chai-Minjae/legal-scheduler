# frozen_string_literal: true

# 워터마크 추가 서비스
# 이미지와 PDF 파일에 워터마크를 추가
class WatermarkService
  WATERMARK_IMAGE = Rails.root.join("app", "assets", "images", "watermark.png")
  SUPPORTED_IMAGES = %w[.jpg .jpeg .png .bmp .webp].freeze
  SUPPORTED_DOCS = %w[.pdf].freeze

  # MIME Type 검증을 위한 매직 넘버
  MAGIC_NUMBERS = {
    "\xFF\xD8\xFF" => :jpeg,
    "\x89PNG\r\n\x1A\n" => :png,
    "BM" => :bmp,
    "RIFF" => :webp,
    "%PDF" => :pdf
  }.freeze

  MAX_FILE_SIZE = 50.megabytes

  attr_reader :file, :opacity, :scale, :position

  def initialize(file:, opacity: 0.3, scale: 1.0, position: "center")
    @file = file
    @opacity = opacity
    @scale = scale
    @position = position
    @temp_files = []      # 입력 임시 파일 (항상 정리)
    @output_path = nil    # 출력 파일 (실패 시에만 정리)
  end

  def process
    # 파일 크기 검증
    if file.size > MAX_FILE_SIZE
      return { success: false, error: "파일 크기가 50MB를 초과합니다." }
    end

    # MIME Type 검증
    unless valid_file_type?
      return { success: false, error: "지원하지 않는 파일 형식이거나 위조된 파일입니다." }
    end

    ext = File.extname(file.original_filename).downcase

    result = if SUPPORTED_IMAGES.include?(ext)
               process_image
             elsif SUPPORTED_DOCS.include?(ext)
               process_pdf
             else
               { success: false, error: "지원하지 않는 파일 형식입니다." }
             end

    # 실패 시 출력 파일도 정리
    cleanup_output_on_failure unless result[:success]

    result
  rescue StandardError => e
    Rails.logger.error("[WatermarkService] Error: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    cleanup_output_on_failure
    { success: false, error: "파일 처리 중 오류가 발생했습니다." }
  ensure
    cleanup_temp_files
  end

  private

  def process_image
    require "mini_magick"

    # 임시 파일 생성
    input_path = save_temp_file(file)
    output_path = temp_output_path(".jpg")

    # MiniMagick으로 워터마크 추가
    image = MiniMagick::Image.open(input_path)
    watermark = MiniMagick::Image.open(WATERMARK_IMAGE.to_s)

    # 워터마크 크기 조절
    wm_width = (image.width * scale).to_i
    wm_height = (watermark.height * wm_width / watermark.width).to_i
    watermark.resize "#{wm_width}x#{wm_height}"

    # 위치 계산
    x, y = calculate_position(image.width, image.height, wm_width, wm_height)

    # 합성
    result = image.composite(watermark) do |c|
      c.compose "Over"
      c.geometry "+#{x}+#{y}"
      c.dissolve "#{(opacity * 100).to_i}"
    end

    result.write(output_path)

    {
      success: true,
      output_path: output_path,
      filename: watermarked_filename(file.original_filename, ".jpg"),
      content_type: "image/jpeg"
    }
  end

  def process_pdf
    require "combine_pdf"
    require "prawn"

    input_path = save_temp_file(file)
    output_path = temp_output_path(".pdf")

    # PDF 로드
    pdf = CombinePDF.load(input_path)

    # 워터마크 PDF 생성
    watermark_pdf = create_watermark_pdf(pdf.pages.first)

    # 각 페이지에 워터마크 추가
    pdf.pages.each do |page|
      page << watermark_pdf.pages.first
    end

    pdf.save(output_path)

    {
      success: true,
      output_path: output_path,
      filename: watermarked_filename(file.original_filename, ".pdf"),
      content_type: "application/pdf"
    }
  end

  def create_watermark_pdf(sample_page)
    require "prawn"

    width = sample_page[:MediaBox][2]
    height = sample_page[:MediaBox][3]

    wm_width = width * scale
    x = (width - wm_width) / 2
    y = (height - wm_width * 0.5) / 2  # 대략적인 비율

    Prawn::Document.new(page_size: [width, height], margin: 0) do |pdf|
      pdf.transparent(opacity) do
        pdf.image WATERMARK_IMAGE.to_s, at: [x, y + wm_width * 0.3], width: wm_width
      end
    end

    CombinePDF.parse(pdf.render)
  end

  def calculate_position(img_width, img_height, wm_width, wm_height)
    margin = 20

    case position
    when "center"
      [(img_width - wm_width) / 2, (img_height - wm_height) / 2]
    when "bottom-right"
      [img_width - wm_width - margin, img_height - wm_height - margin]
    when "bottom-left"
      [margin, img_height - wm_height - margin]
    when "top-right"
      [img_width - wm_width - margin, margin]
    when "top-left"
      [margin, margin]
    else
      [(img_width - wm_width) / 2, (img_height - wm_height) / 2]
    end
  end

  def save_temp_file(uploaded_file)
    temp = Tempfile.new(["watermark_input", File.extname(uploaded_file.original_filename)])
    temp.binmode
    uploaded_file.rewind if uploaded_file.respond_to?(:rewind)
    temp.write(uploaded_file.read)
    temp.close
    @temp_files << temp.path
    temp.path
  end

  def temp_output_path(ext)
    # output_path 추적 (실패 시 정리용)
    @output_path = File.join(Dir.tmpdir, "watermark_output_#{SecureRandom.hex(8)}#{ext}")
  end

  def watermarked_filename(original, ext)
    name = File.basename(original, ".*")
    "#{name}_watermarked#{ext}"
  end

  def valid_file_type?
    file.rewind if file.respond_to?(:rewind)
    header = file.read(16)
    file.rewind if file.respond_to?(:rewind)

    return false if header.nil?

    ext = File.extname(file.original_filename).downcase

    # 매직 넘버와 확장자가 일치하는지 확인
    MAGIC_NUMBERS.any? do |magic, type|
      next unless header.start_with?(magic.b)

      case type
      when :jpeg then %w[.jpg .jpeg].include?(ext)
      when :png then ext == ".png"
      when :bmp then ext == ".bmp"
      when :webp then ext == ".webp" && header[8..11] == "WEBP"
      when :pdf then ext == ".pdf"
      else false
      end
    end
  end

  def cleanup_temp_files
    @temp_files.each do |path|
      next unless path

      # FileUtils.rm_f는 파일이 없어도 예외를 발생시키지 않음
      FileUtils.rm_f(path)
      Rails.logger.debug("[WatermarkService] Cleaned up input file: #{path}")
    end
  end

  def cleanup_output_on_failure
    return unless @output_path

    FileUtils.rm_f(@output_path)
    Rails.logger.debug("[WatermarkService] Cleaned up output file on failure: #{@output_path}")
  end
end
