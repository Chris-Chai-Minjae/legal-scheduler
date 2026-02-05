# 워터마크 추가 기능 컨트롤러
# 이미지/PDF 파일에 워터마크를 추가하여 다운로드
class WatermarksController < ApplicationController
  include ActionController::Live

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

    # 파일 크기 검증 - 서비스 상수 참조 (중복 제거)
    if file.size > WatermarkService::MAX_FILE_SIZE
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
      stream_and_cleanup(result)
    else
      redirect_to watermarks_path, alert: "처리 실패: #{result[:error]}"
    end
  end

  private

  # 스트리밍 방식으로 파일 전송 (메모리 효율적)
  # 전송 완료 후 안전하게 파일 삭제
  def stream_and_cleanup(result)
    output_path = result[:output_path]

    response.headers["Content-Type"] = result[:content_type]
    # RFC 5987/6266 표준에 따라 파일명 안전하게 인코딩 (헤더 인젝션 방지)
    response.headers["Content-Disposition"] = content_disposition(result[:filename])

    # 청크 단위로 스트리밍 (메모리 스파이크 방지)
    File.open(output_path, "rb") do |file|
      while (chunk = file.read(16.kilobytes))
        response.stream.write(chunk)
      end
    end
  rescue IOError, Errno::EPIPE, Errno::ECONNRESET => e
    # 클라이언트 연결 끊김 등 스트리밍 에러 처리
    Rails.logger.warn("[WatermarksController] Stream interrupted: #{e.class} - #{e.message}")
  ensure
    response.stream.close rescue nil  # 이미 닫힌 경우 무시
    FileUtils.rm_f(output_path) if output_path
    Rails.logger.debug("[WatermarksController] Cleaned up: #{output_path}")
  end

  # 파일명을 안전하게 Content-Disposition 헤더로 변환
  def content_disposition(filename)
    # 위험한 문자 제거 (CRLF, 따옴표 등)
    safe_filename = filename.to_s.gsub(/[\r\n"\\]/, "_").strip
    safe_filename = "download" if safe_filename.empty?

    # RFC 6266 형식: ASCII + UTF-8 fallback
    ActionDispatch::Http::ContentDisposition.format(
      disposition: "attachment",
      filename: safe_filename
    )
  end
end
