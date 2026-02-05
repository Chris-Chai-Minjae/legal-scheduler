# 워터마크 추가 기능 컨트롤러
# 이미지/PDF 파일에 워터마크를 추가하여 다운로드
class WatermarksController < ApplicationController
  before_action :require_authentication
  layout "dashboard"

  MAX_FILE_SIZE = 50.megabytes

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

    # 파일 크기 검증 (클라이언트 측 검증 우회 방지)
    if file.size > MAX_FILE_SIZE
      redirect_to watermarks_path, alert: "파일 크기가 50MB를 초과합니다."
      return
    end

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
      # send_data를 사용하여 파일 전송 후 즉시 삭제 가능하도록 함
      output_path = result[:output_path]
      begin
        send_data File.read(output_path),
                  filename: result[:filename],
                  type: result[:content_type],
                  disposition: "attachment"
      ensure
        File.delete(output_path) if output_path && File.exist?(output_path)
      end
    else
      redirect_to watermarks_path, alert: "처리 실패: #{result[:error]}"
    end
  end
end
