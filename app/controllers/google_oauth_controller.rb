# Google OAuth2 Controller for Calendar API access
# Handles both authentication (login/signup) and calendar authorization
# Rails 8 style - no external gems required

class GoogleOauthController < ApplicationController
  # No authentication required - this IS the authentication!
  allow_unauthenticated_access only: [:new, :callback]

  GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
  GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
  GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo"

  # Request email, profile AND calendar access in one go
  SCOPES = [
    "openid",
    "email",
    "profile",
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/calendar.events"
  ].join(" ")

  # GET /auth/google - Redirect to Google OAuth
  def new
    redirect_to google_auth_url, allow_other_host: true
  end

  # GET /auth/google/callback - Handle OAuth callback (login + signup + calendar auth)
  def callback
    if params[:error]
      redirect_to root_path, alert: "Google 연결이 취소되었습니다."
      return
    end

    token_response = exchange_code_for_token(params[:code])

    if token_response[:error]
      redirect_to root_path, alert: "Google 인증에 실패했습니다: #{token_response[:error_description]}"
      return
    end

    # Get user info from Google
    user_info = fetch_user_info(token_response[:access_token])

    if user_info[:error]
      redirect_to root_path, alert: "사용자 정보를 가져올 수 없습니다."
      return
    end

    # Find or create user
    user = User.find_or_initialize_by(email_address: user_info[:email])

    if user.new_record?
      # New user - create account
      user.name = user_info[:name]
      user.password = SecureRandom.hex(16) # Random password (won't be used)
      user.save!
    end

    # Update OAuth tokens
    user.update!(
      google_access_token: token_response[:access_token],
      google_refresh_token: token_response[:refresh_token] || user.google_refresh_token,
      google_token_expires_at: Time.current + token_response[:expires_in].to_i.seconds
    )

    # Create session (log in)
    start_new_session_for(user)

    # Redirect based on onboarding status
    if user.onboarding_complete?
      redirect_to dashboard_path, notice: "로그인되었습니다!"
    else
      redirect_to onboarding_path(step: 3), notice: "Google 계정으로 연결되었습니다! 캘린더를 선택해주세요."
    end
  end

  private

  def google_auth_url
    params = {
      client_id: google_client_id,
      redirect_uri: callback_url,
      response_type: "code",
      scope: SCOPES,
      access_type: "offline",
      prompt: "consent"
    }

    "#{GOOGLE_AUTH_URL}?#{params.to_query}"
  end

  def fetch_user_info(access_token)
    uri = URI(GOOGLE_USERINFO_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"

    response = http.request(request)
    JSON.parse(response.body, symbolize_names: true)
  end

  def exchange_code_for_token(code)
    response = Net::HTTP.post_form(
      URI(GOOGLE_TOKEN_URL),
      {
        code: code,
        client_id: google_client_id,
        client_secret: google_client_secret,
        redirect_uri: callback_url,
        grant_type: "authorization_code"
      }
    )

    JSON.parse(response.body, symbolize_names: true)
  end

  def callback_url
    auth_google_callback_url
  end

  def google_client_id
    ENV.fetch("GOOGLE_CLIENT_ID")
  end

  def google_client_secret
    ENV.fetch("GOOGLE_CLIENT_SECRET")
  end
end
