# @TASK T4.2 - Schedules Controller Test
# @SPEC REQ-DASH-02: Status filtering, pagination, detail view

require "test_helper"

class SchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @calendar = calendars(:one)
    @schedule = schedules(:one)
    sign_in_as @user
  end

  test "should get index" do
    get schedules_url
    assert_response :success
    assert_select "h1", "일정 목록"
  end

  test "should filter schedules by status pending" do
    get schedules_url(status: :pending)
    assert_response :success
    assert_select "turbo-frame#schedules_list"
  end

  test "should filter schedules by status approved" do
    get schedules_url(status: :approved)
    assert_response :success
    assert_select "turbo-frame#schedules_list"
  end

  test "should filter schedules by status rejected" do
    get schedules_url(status: :rejected)
    assert_response :success
    assert_select "turbo-frame#schedules_list"
  end

  test "should search schedules by query" do
    get schedules_url(q: "서면작성")
    assert_response :success
  end

  test "should show schedule detail" do
    get schedule_url(@schedule)
    assert_response :success
    assert_select "h1", "일정 상세"
  end

  test "should not show schedule from other user" do
    other_user = users(:two)
    other_calendar = calendars(:two)
    other_schedule = schedules(:two)

    assert_raises(ActiveRecord::RecordNotFound) do
      get schedule_url(other_schedule)
    end
  end

  test "should display status counts in tabs" do
    get schedules_url
    assert_response :success
    assert_select ".tab-badge", minimum: 4 # all, pending, approved, rejected
  end

  test "should paginate schedules" do
    # Create more than 20 schedules
    25.times do |i|
      Schedule.create!(
        calendar: @calendar,
        title: "Test Schedule #{i}",
        original_date: Date.today + i.days,
        scheduled_date: Date.today + i.days - 2.weeks,
        status: :pending
      )
    end

    get schedules_url
    assert_response :success
    assert_select ".pagination"
  end
end
