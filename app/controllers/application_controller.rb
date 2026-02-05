class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # 이미 로그인된 사용자는 대시보드로 리다이렉트
  def redirect_if_authenticated
    redirect_to dashboard_path if authenticated?
  end
end
