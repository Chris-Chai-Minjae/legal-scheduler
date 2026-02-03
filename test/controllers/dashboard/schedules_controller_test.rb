# @TASK T4.1 - Dashboard schedules controller tests
# @SPEC .sdd/specs/dashboard/spec.md#REQ-DASH-01

require "test_helper"

class Dashboard::SchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @session = sessions(:one)
    cookies.signed[:session_id] = @session.id

    @calendar = calendars(:one)
    @schedule = Schedule.create!(
      calendar: @calendar,
      title: "서면작성 테스트",
      original_date: 2.weeks.from_now,
      scheduled_date: 1.week.from_now,
      status: :pending
    )
  end

  test "should approve schedule" do
    post approve_dashboard_schedule_url(@schedule)
    assert_redirected_to dashboard_path

    @schedule.reload
    assert_equal "approved", @schedule.status
  end

  test "should reject schedule" do
    post reject_dashboard_schedule_url(@schedule)
    assert_redirected_to dashboard_path

    @schedule.reload
    assert_equal "rejected", @schedule.status
  end

  test "should respond with turbo stream on approve" do
    post approve_dashboard_schedule_url(@schedule), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
  end

  test "should respond with turbo stream on reject" do
    post reject_dashboard_schedule_url(@schedule), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
  end

  test "should require authentication for approve" do
    cookies.delete(:session_id)
    post approve_dashboard_schedule_url(@schedule)
    assert_redirected_to new_session_path
  end

  test "should require authentication for reject" do
    cookies.delete(:session_id)
    post reject_dashboard_schedule_url(@schedule)
    assert_redirected_to new_session_path
  end
end
