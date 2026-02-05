# frozen_string_literal: true

# 워터마크 추가 서비스
# 이미지와 PDF 파일에 워터마크를 추가
class WatermarkService
  WATERMARK_IMAGE = Rails.root.join("app", "assets", "images", "watermark.png")
  SUPPORTED_IMAGES = %w[.jpg .jpeg .png .bmp .webp].freeze
  SUPPORTED_DOCS = %w[.pdf].freeze

  attr_reader :file, :opacity, :scale, :position

  def initialize(file:, opacity: 0.3, scale: 1.0, position: "center")
    @file = file
    @opacity = opacity
    @scale = scale
    @position = position
  end

  def process
    ext = File.extname(file.original_filename).downcase

    if SUPPORTED_IMAGES.include?(ext)
      process_image
    elsif SUPPORTED_DOCS.include?(ext)
      process_pdf
    else
      { success: false, error: "지원하지 않는 파일 형식입니다." }
    end
  rescue StandardError => e
    Rails.logger.error("[WatermarkService] Error: #{e.message}")
    { success: false, error: e.message }
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
  rescue LoadError
    # combine_pdf가 없으면 Python 스크립트 사용
    process_pdf_with_python
  end

  def process_pdf_with_python
    input_path = save_temp_file(file)
    output_path = temp_output_path(".pdf")

    script = <<~PYTHON
      import pymupdf
      from PIL import Image
      import io

      doc = pymupdf.open("#{input_path}")
      wm_img = Image.open("#{WATERMARK_IMAGE}").convert('RGBA')

      # 투명도 조절
      alpha = wm_img.split()[3]
      alpha = alpha.point(lambda p: int(p * #{opacity}))
      wm_img.putalpha(alpha)

      img_bytes = io.BytesIO()
      wm_img.save(img_bytes, format='PNG')
      img_bytes.seek(0)

      for page in doc:
          page_rect = page.rect
          wm_width = int(page_rect.width * #{scale})
          wm_height = int(wm_img.height * wm_width / wm_img.width)

          x = (page_rect.width - wm_width) / 2
          y = (page_rect.height - wm_height) / 2

          wm_rect = pymupdf.Rect(x, y, x + wm_width, y + wm_height)
          page.insert_image(wm_rect, stream=img_bytes.getvalue())

      doc.save("#{output_path}")
      doc.close()
    PYTHON

    system("python3", "-c", script)

    if File.exist?(output_path)
      {
        success: true,
        output_path: output_path,
        filename: watermarked_filename(file.original_filename, ".pdf"),
        content_type: "application/pdf"
      }
    else
      { success: false, error: "PDF 처리 실패" }
    end
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
    temp.write(uploaded_file.read)
    temp.close
    temp.path
  end

  def temp_output_path(ext)
    File.join(Dir.tmpdir, "watermark_output_#{SecureRandom.hex(8)}#{ext}")
  end

  def watermarked_filename(original, ext)
    name = File.basename(original, ".*")
    "#{name}_watermarked#{ext}"
  end
end
