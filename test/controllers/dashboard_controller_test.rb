# @TASK T4.1 - Dashboard controller tests
# @SPEC .sdd/specs/dashboard/spec.md#REQ-DASH-01

require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @session = sessions(:one)
    cookies.signed[:session_id] = @session.id

    # Create calendars
    @calendar = calendars(:one)

    # Create pending schedules
    @pending_schedule_1 = Schedule.create!(
      calendar: @calendar,
      title: "서면작성 1",
      original_date: 2.weeks.from_now,
      scheduled_date: 1.week.from_now,
      status: :pending
    )
    @pending_schedule_2 = Schedule.create!(
      calendar: @calendar,
      title: "서면작성 2",
      original_date: 3.weeks.from_now,
      scheduled_date: 2.weeks.from_now,
      status: :pending
    )

    # Create approved schedule
    @approved_schedule = Schedule.create!(
      calendar: @calendar,
      title: "서면작성 (승인됨)",
      original_date: 1.week.from_now,
      scheduled_date: Date.today,
      status: :approved
    )
  end

  test "should get index" do
    get dashboard_url
    assert_response :success
  end

  test "should show pending count" do
    get dashboard_url
    assert_select ".stat-card.pending .stat-value", text: "2"
  end

  test "should show pending schedules list" do
    get dashboard_url
    assert_select ".schedule-card", count: 2
  end

  test "should show empty state when no pending schedules" do
    @pending_schedule_1.update!(status: :approved)
    @pending_schedule_2.update!(status: :approved)

    get dashboard_url
    assert_select ".empty-state"
  end

  test "should require authentication" do
    cookies.delete(:session_id)
    get dashboard_url
    assert_redirected_to new_session_path
  end
end
