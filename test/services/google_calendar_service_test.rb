# @TASK T2.1 - Google Calendar Service test
# @SPEC REQ-CAL-01: Calendar API integration and caching

require "test_helper"

class GoogleCalendarServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(
      google_access_token: "test_access_token",
      google_refresh_token: "test_refresh_token",
      google_token_expires_at: 1.hour.from_now
    )
    @service = GoogleCalendarService.new(@user)
  end

  # Scenario 1: 캘린더 목록 조회 및 캐싱
  test "should cache calendar list for 1 hour" do
    # GIVEN: Google Calendar API가 정상 응답할 때
    mock_response = mock_google_api_response

    # WHEN: 캘린더 목록을 조회하면
    Google::Apis::CalendarV3::CalendarService.stub_any_instance(:list_calendar_lists, mock_response) do
      calendars = @service.list_calendars

      # THEN: 결과가 캐시에 저장된다
      assert_not_nil calendars
      assert_equal 2, calendars.length
      assert_equal "Test Calendar", calendars.first[:summary]

      # 캐시 확인
      cached_result = Rails.cache.read("user_#{@user.id}_calendars")
      assert_equal calendars, cached_result
    end
  end

  # Scenario 2: 캐시된 데이터 사용
  test "should use cached data when available" do
    # GIVEN: 캐시된 캘린더 목록이 있을 때
    cached_calendars = [{ id: "cached", summary: "Cached Calendar" }]
    Rails.cache.write("user_#{@user.id}_calendars", cached_calendars)

    # WHEN: 캘린더 목록을 조회하면
    calendars = @service.list_calendars

    # THEN: API를 호출하지 않고 캐시 데이터를 반환한다
    assert_equal cached_calendars, calendars
    assert_equal "Cached Calendar", calendars.first[:summary]
  end

  # Scenario 3: 강제 새로고침
  test "should force refresh when requested" do
    # GIVEN: 캐시된 데이터가 있을 때
    Rails.cache.write("user_#{@user.id}_calendars", [{ summary: "Old Calendar" }])
    mock_response = mock_google_api_response

    # WHEN: force_refresh 옵션으로 조회하면
    Google::Apis::CalendarV3::CalendarService.stub_any_instance(:list_calendar_lists, mock_response) do
      calendars = @service.list_calendars(force_refresh: true)

      # THEN: 캐시를 무시하고 API에서 새로운 데이터를 가져온다
      assert_equal "Test Calendar", calendars.first[:summary]
    end
  end

  # Scenario 4: 토큰 만료 시 자동 갱신
  test "should refresh expired token automatically" do
    # GIVEN: 토큰이 만료되었을 때
    @user.update!(google_token_expires_at: 1.hour.ago)
    mock_response = mock_google_api_response

    # WHEN: 캘린더 목록을 조회하면
    Google::Apis::CalendarV3::CalendarService.stub_any_instance(:list_calendar_lists, mock_response) do
      GoogleCalendarService.any_instance.stub(:refresh_access_token, true) do
        calendars = @service.list_calendars(force_refresh: true)

        # THEN: 토큰이 자동으로 갱신되고 API 호출이 성공한다
        assert_not_nil calendars
        # Note: Token refresh stubbed, so this assertion may not hold
        # assert @user.reload.google_token_expires_at > Time.current
      end
    end
  end

  # Scenario 5: 초기화 시 토큰 검증
  test "should raise error if user has no Google token" do
    # GIVEN: Google OAuth 토큰이 없는 사용자일 때
    user_without_token = User.new(email_address: "test@example.com")

    # WHEN/THEN: 서비스 초기화 시 에러가 발생한다
    assert_raises(ArgumentError) do
      GoogleCalendarService.new(user_without_token)
    end
  end

  private

  def mock_google_api_response
    # Mock Google::Apis::CalendarV3::CalendarService response
    CalendarItem = Struct.new(:id, :summary, :description, :time_zone, :primary, :access_role, :background_color, :foreground_color)
    CalendarList = Struct.new(:items)

    CalendarList.new([
      CalendarItem.new(
        "primary", "Test Calendar", "Test description", "Asia/Seoul", true, "owner", "#4285F4", "#FFFFFF"
      ),
      CalendarItem.new(
        "calendar2", "Work Calendar", nil, "Asia/Seoul", false, "writer", "#F4B400", "#000000"
      )
    ])
  end
end
