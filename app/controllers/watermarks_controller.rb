# 워터마크 추가 기능 컨트롤러
# 이미지/PDF 파일에 워터마크를 추가하여 다운로드
class WatermarksController < ApplicationController
  before_action :require_authentication
  layout "dashboard"

  def index
    @supported_formats = {
      images: %w[.jpg .jpeg .png .bmp .webp],
      documents: %w[.pdf]
    }
  end

  def create
    unless params[:file].present?
      redirect_to watermarks_path, alert: "파일을 선택해주세요."
      return
    end

    file = params[:file]
    opacity = (params[:opacity] || 30).to_i / 100.0
    scale = (params[:scale] || 100).to_i / 100.0
    position = params[:position] || "center"

    service = WatermarkService.new(
      file: file,
      opacity: opacity,
      scale: scale,
      position: position
    )

    result = service.process

    if result[:success]
      send_file result[:output_path],
                filename: result[:filename],
                type: result[:content_type],
                disposition: "attachment"
    else
      redirect_to watermarks_path, alert: "처리 실패: #{result[:error]}"
    end
  end
end
