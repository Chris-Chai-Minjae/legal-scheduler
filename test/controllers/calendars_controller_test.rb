# @TASK T2.1 - Calendars controller test
# @SPEC REQ-CAL-01: Calendar list retrieval and refresh

require "test_helper"

class CalendarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    # Set up Google OAuth tokens
    @user.update!(
      google_access_token: "test_access_token",
      google_refresh_token: "test_refresh_token",
      google_token_expires_at: 1.hour.from_now
    )
    sign_in_as(@user)
  end

  # Scenario 1: 캘린더 목록 조회
  test "should get calendar list" do
    # GIVEN: Google Calendar API가 캘린더 목록을 반환할 때
    calendars = mock_calendar_list

    # WHEN: 캘린더 목록 페이지를 요청하면
    GoogleCalendarService.stub_any_instance(:list_calendars, calendars) do
      get calendars_path

      # THEN: 캘린더 목록이 표시된다
      assert_response :success
      assert_select "h1", text: /캘린더 목록/
    end
  end

  # Scenario 2: 캘린더 목록 강제 새로고침
  test "should refresh calendar list" do
    # GIVEN: 캐시된 캘린더 목록이 있을 때
    Rails.cache.write("user_#{@user.id}_calendars", [{ summary: "Old Calendar" }])
    calendars = mock_calendar_list

    # WHEN: 새로고침 버튼을 클릭하면
    GoogleCalendarService.stub_any_instance(:list_calendars, calendars) do
      post refresh_calendars_path

      # THEN: API에서 최신 데이터를 가져온다
      assert_redirected_to calendars_path
      follow_redirect!
      assert_response :success
    end
  end

  # Scenario 3: Google OAuth 미연동 시 접근 제한
  test "should redirect to onboarding if not authenticated with Google" do
    # GIVEN: Google OAuth 토큰이 없는 사용자일 때
    @user.update!(google_access_token: nil)

    # WHEN: 캘린더 목록 페이지를 요청하면
    get calendars_path

    # THEN: 온보딩 페이지로 리다이렉트된다
    assert_redirected_to onboarding_path
    follow_redirect!
    assert_match /Google Calendar.*연결/i, flash[:alert]
  end

  # Scenario 4: Google API 에러 처리
  test "should handle Google API errors gracefully" do
    # GIVEN: Google API가 에러를 반환할 때
    error_stub = -> (*) { raise StandardError.new("API Error") }

    # WHEN: 캘린더 목록 페이지를 요청하면
    GoogleCalendarService.stub_any_instance(:list_calendars, error_stub) do
      get calendars_path

      # THEN: 에러 메시지가 표시되고 빈 목록이 표시된다
      assert_response :success
      assert_match /Failed to fetch calendars/i, response.body
    end
  end

  # @TASK T2.2 - Calendar type assignment tests
  # @SPEC REQ-CAL-02: Designate lbox/work/personal calendars

  # Scenario 5: LBOX 캘린더 선택
  test "should assign lbox calendar type" do
    # GIVEN: 사용 가능한 캘린더 목록이 있을 때
    calendars = mock_calendar_list
    google_id = "primary"

    # WHEN: LBOX 캘린더를 선택하면
    GoogleCalendarService.stub_any_instance(:list_calendars, calendars) do
      patch calendar_path(google_id),
        params: { id: google_id, calendar_type: "lbox" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      # THEN: 캘린더가 lbox 타입으로 저장된다
      assert_response :success
      calendar = @user.calendars.find_by(google_id: google_id)
      assert_not_nil calendar
      assert_equal "lbox", calendar.calendar_type
      assert_equal "Test Calendar", calendar.name
    end
  end

  # Scenario 6: 업무 캘린더 선택
  test "should assign work calendar type" do
    # GIVEN: 사용 가능한 캘린더 목록이 있을 때
    calendars = mock_calendar_list
    google_id = "calendar2@example.com"

    # WHEN: 업무 캘린더를 선택하면
    GoogleCalendarService.stub_any_instance(:list_calendars, calendars) do
      patch calendar_path(google_id),
        params: { id: google_id, calendar_type: "work" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      # THEN: 캘린더가 work 타입으로 저장된다
      assert_response :success
      calendar = @user.calendars.find_by(google_id: google_id)
      assert_not_nil calendar
      assert_equal "work", calendar.calendar_type
      assert_equal "Work Calendar", calendar.name
    end
  end

  # Scenario 7: 개인 캘린더 선택 (선택사항)
  test "should assign personal calendar type" do
    # GIVEN: 사용 가능한 캘린더 목록이 있을 때
    calendars = mock_calendar_list
    google_id = "primary"

    # WHEN: 개인 캘린더를 선택하면
    GoogleCalendarService.stub_any_instance(:list_calendars, calendars) do
      patch calendar_path(google_id),
        params: { id: google_id, calendar_type: "personal" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      # THEN: 캘린더가 personal 타입으로 저장된다
      assert_response :success
      calendar = @user.calendars.find_by(google_id: google_id)
      assert_not_nil calendar
      assert_equal "personal", calendar.calendar_type
    end
  end

  # Scenario 8: 같은 타입의 캘린더 재선택 시 기존 할당 해제
  test "should unassign previous calendar when reassigning same type" do
    # GIVEN: LBOX 캘린더가 이미 할당되어 있을 때
    calendars = mock_calendar_list
    old_calendar = @user.calendars.create!(
      google_id: "old_calendar@example.com",
      name: "Old LBOX Calendar",
      calendar_type: :lbox
    )

    # WHEN: 다른 캘린더를 LBOX로 선택하면
    GoogleCalendarService.stub_any_instance(:list_calendars, calendars) do
      patch calendar_path("primary"),
        params: { id: "primary", calendar_type: "lbox" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      # THEN: 기존 캘린더의 타입이 해제되고 새 캘린더가 할당된다
      assert_response :success
      old_calendar.reload
      assert_nil old_calendar.calendar_type

      new_calendar = @user.calendars.find_by(google_id: "primary")
      assert_equal "lbox", new_calendar.calendar_type
    end
  end

  # Scenario 9: 캘린더 타입별 1개씩만 할당 가능
  test "should allow one calendar per type" do
    # GIVEN: LBOX, Work, Personal 캘린더가 각각 할당되어 있을 때
    calendars = mock_calendar_list

    GoogleCalendarService.stub_any_instance(:list_calendars, calendars) do
      # WHEN: 각 타입별로 캘린더를 할당하면
      patch calendar_path("primary"), params: { id: "primary", calendar_type: "lbox" }
      patch calendar_path("calendar2@example.com"), params: { id: "calendar2@example.com", calendar_type: "work" }
      patch calendar_path("primary"), params: { id: "primary", calendar_type: "personal" }

      # THEN: 각 타입별로 1개씩만 할당되어 있다
      assert_equal 1, @user.calendars.where(calendar_type: :lbox).count
      assert_equal 1, @user.calendars.where(calendar_type: :work).count
      assert_equal 1, @user.calendars.where(calendar_type: :personal).count
    end
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def mock_calendar_list
    [
      {
        id: "primary",
        summary: "Test Calendar",
        description: "Test calendar description",
        time_zone: "Asia/Seoul",
        primary: true,
        access_role: "owner",
        background_color: "#4285F4",
        foreground_color: "#FFFFFF"
      },
      {
        id: "calendar2@example.com",
        summary: "Work Calendar",
        description: nil,
        time_zone: "Asia/Seoul",
        primary: false,
        access_role: "writer",
        background_color: "#F4B400",
        foreground_color: "#000000"
      }
    ]
  end
end
