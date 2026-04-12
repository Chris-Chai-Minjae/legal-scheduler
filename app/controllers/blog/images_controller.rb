require "net/http"

# Blog::ImagesController
#
# blog-ai FastAPI 컨테이너(:8001)가 서빙하는 생성 이미지를
# Rails 도메인(/blog/images/...)으로 리버스 프록시한다.
#
# 이유: 브라우저는 Rails 포트(3080)로만 접근 가능하고,
#       blog-ai 컨테이너의 8001 포트는 외부 노출되어 있지 않다.
class Blog::ImagesController < ApplicationController
  # 이미지 <img src="..."> 요청은 브라우저의 세션 쿠키로 오지만,
  # Rails 8 authentication generator 의 글로벌 before_action 때문에
  # 로그인 확인 실패 시 302 redirect → 이미지 깨짐.
  # 이미지 URL 은 post_id + 파일명(랜덤 hex) 조합으로 추측 불가하므로
  # 인증 체크를 건너뛰고 blog-ai 로 프록시한다.
  allow_unauthenticated_access only: [:show]

  BLOG_AI_URL = ENV["BLOG_AI_API_URL"] || ENV["BLOG_AI_URL"] || "http://blog-ai:8001"
  ALLOWED_EXT = %w[.png .jpg .jpeg .webp].freeze

  def show
    post_id  = params[:post_id].to_s
    filename = params[:filename].to_s

    # 보안: path traversal / 잘못된 문자 차단
    return head(:bad_request) unless post_id.match?(/\A\d+\z/)
    return head(:bad_request) if filename.include?("..") || filename.start_with?(".")
    return head(:bad_request) unless filename.match?(/\A[A-Za-z0-9._\-]+\z/)
    return head(:bad_request) unless ALLOWED_EXT.include?(File.extname(filename).downcase)

    uri = URI.join(BLOG_AI_URL, "/static/blog_images/#{post_id}/#{filename}")

    upstream = Net::HTTP.start(uri.host, uri.port,
                               use_ssl: uri.scheme == "https",
                               open_timeout: 5,
                               read_timeout: 30) do |http|
      http.get(uri.request_uri)
    end

    unless upstream.is_a?(Net::HTTPSuccess)
      return head(:not_found)
    end

    # 1일 캐시 + 인라인 표시
    response.headers["Cache-Control"] = "public, max-age=86400"
    send_data upstream.body,
              type:        upstream["Content-Type"] || "image/png",
              disposition: "inline",
              filename:    filename
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("Blog::ImagesController upstream error: #{e.message}")
    head :bad_gateway
  end
end
