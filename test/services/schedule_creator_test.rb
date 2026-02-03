# @TASK T5.2 - Schedule Creator Service Tests
# @SPEC .sdd/specs/schedule/spec.md#REQ-SCHED-01, REQ-SCHED-02, REQ-SCHED-06

require "test_helper"

class ScheduleCreatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @settings = settings(:one)
    @work_calendar = calendars(:one)

    # Sample LBOX event data
    @lbox_event = {
      id: "lbox_event_123",
      summary: "2025나12345 손해배상청구 변론",
      description: "서울고등법원 제5민사부",
      start_date: Date.new(2026, 3, 15)  # Sunday
    }
  end

  # REQ-SCHED-01: Calculate scheduled_date as original_date - lead_days
  test "calculates scheduled_date correctly with lead_days" do
    result = ScheduleCreator.new(@user, @lbox_event).call

    assert result.success
    # 2026-03-15 - 14 days = 2026-03-01 (Sunday) -> adjusted to Friday 2026-02-27
    expected_date = Date.new(2026, 2, 27)  # Friday
    assert_equal expected_date, result.schedule.scheduled_date
  end

  # REQ-SCHED-01: Exclude weekends when setting is enabled
  test "adjusts Saturday to Friday when exclude_weekends is true" do
    # Event on a date where scheduled_date would fall on Saturday
    # 2026-03-14 (Saturday) - 14 days = 2026-02-28 (Saturday) -> Friday 2026-02-27
    event = @lbox_event.merge(start_date: Date.new(2026, 3, 14))

    result = ScheduleCreator.new(@user, event).call

    assert result.success
    # Should be Friday 2026-02-27
    assert_equal 5, result.schedule.scheduled_date.wday  # Friday = 5
  end

  test "adjusts Sunday to Friday when exclude_weekends is true" do
    # 2026-03-15 (Sunday) - 14 days = 2026-03-01 (Sunday) -> Friday 2026-02-27
    event = @lbox_event.merge(start_date: Date.new(2026, 3, 15))

    result = ScheduleCreator.new(@user, event).call

    assert result.success
    # Should be Friday
    assert_equal 5, result.schedule.scheduled_date.wday
  end

  test "does not adjust weekends when exclude_weekends is false" do
    user_two = users(:two)
    # Settings for user_two has exclude_weekends: false

    event = {
      id: "lbox_event_no_weekend_adjust",
      summary: "2025나99999 변론",
      start_date: Date.new(2026, 3, 14)  # Saturday - 7 days = Saturday 2026-03-07
    }

    result = ScheduleCreator.new(user_two, event).call

    assert result.success
    # Should remain on Saturday since exclude_weekends is false
    assert_equal 6, result.schedule.scheduled_date.wday  # Saturday = 6
  end

  # REQ-SCHED-02: Format title as "[업무] {case_number} {case_name} 서면작성"
  test "formats title correctly with case number and name" do
    result = ScheduleCreator.new(@user, @lbox_event).call

    assert result.success
    assert_includes result.schedule.title, "[업무]"
    assert_includes result.schedule.title, "2025나12345"
    assert_includes result.schedule.title, "손해배상청구"
    assert_includes result.schedule.title, "서면작성"
  end

  test "extracts case_number from event summary" do
    result = ScheduleCreator.new(@user, @lbox_event).call

    assert result.success
    assert_equal "2025나12345", result.schedule.case_number
  end

  test "extracts case_name from event summary" do
    result = ScheduleCreator.new(@user, @lbox_event).call

    assert result.success
    assert_includes result.schedule.case_name, "손해배상청구"
  end

  # REQ-SCHED-06: Check for duplicate schedules
  test "skips duplicate schedules with same original_event_id" do
    # Create initial schedule
    first_result = ScheduleCreator.new(@user, @lbox_event).call
    assert first_result.success

    # Try to create again with same event
    second_result = ScheduleCreator.new(@user, @lbox_event).call

    assert_not second_result.success
    assert_equal :duplicate, second_result.skipped_reason
  end

  test "allows schedules with different original_event_id" do
    # Create initial schedule
    first_result = ScheduleCreator.new(@user, @lbox_event).call
    assert first_result.success

    # Create another with different event ID
    different_event = @lbox_event.merge(id: "different_event_456")
    second_result = ScheduleCreator.new(@user, different_event).call

    assert second_result.success
    assert_not_equal first_result.schedule.id, second_result.schedule.id
  end

  # REQ-SCHED-01: Weekly limit check
  test "respects max_per_week limit" do
    # Create 3 schedules (max_per_week for user one)
    base_date = Date.new(2026, 4, 15)  # Wednesday

    3.times do |i|
      event = {
        id: "limit_event_#{i}",
        summary: "2025나#{10000 + i} 테스트사건 변론",
        start_date: base_date + i.days
      }
      result = ScheduleCreator.new(@user, event).call
      assert result.success, "Schedule #{i + 1} should succeed"
    end

    # 4th schedule should move to next week
    fourth_event = {
      id: "limit_event_4",
      summary: "2025나10004 테스트사건 변론",
      start_date: base_date + 3.days
    }
    result = ScheduleCreator.new(@user, fourth_event).call

    assert result.success
    # The scheduled_date should be in a different week
    first_week = (base_date - @settings.lead_days.days).beginning_of_week
    fourth_week = result.schedule.scheduled_date.beginning_of_week
    assert fourth_week > first_week, "4th schedule should be in a later week"
  end

  # Status and calendar tests
  test "creates schedule with pending status" do
    result = ScheduleCreator.new(@user, @lbox_event).call

    assert result.success
    assert_equal "pending", result.schedule.status
  end

  test "creates schedule in work calendar" do
    result = ScheduleCreator.new(@user, @lbox_event).call

    assert result.success
    assert_equal @work_calendar.id, result.schedule.calendar_id
    assert result.schedule.calendar.work?
  end

  test "stores original_date correctly" do
    result = ScheduleCreator.new(@user, @lbox_event).call

    assert result.success
    assert_equal Date.new(2026, 3, 15), result.schedule.original_date
  end

  test "stores original_event_id correctly" do
    result = ScheduleCreator.new(@user, @lbox_event).call

    assert result.success
    assert_equal "lbox_event_123", result.schedule.original_event_id
  end

  # Batch creation tests
  test "batch_create processes multiple events" do
    events = [
      { id: "batch_1", summary: "2025나11111 사건1 변론", start_date: Date.new(2026, 4, 1) },
      { id: "batch_2", summary: "2025나22222 사건2 변론", start_date: Date.new(2026, 4, 8) },
      { id: "batch_3", summary: "2025나33333 사건3 변론", start_date: Date.new(2026, 4, 15) }
    ]

    results = ScheduleCreator.batch_create(@user, events)

    assert_equal 3, results[:created].length
    assert_empty results[:skipped]
    assert_empty results[:failed]
  end

  test "batch_create handles duplicates correctly" do
    # Create first schedule
    ScheduleCreator.new(@user, @lbox_event).call

    # Batch with duplicate and new
    events = [
      @lbox_event,  # duplicate
      { id: "new_event", summary: "2025나55555 신규사건 변론", start_date: Date.new(2026, 5, 1) }
    ]

    results = ScheduleCreator.batch_create(@user, events)

    assert_equal 1, results[:created].length
    assert_equal 1, results[:skipped].length
    assert_equal :duplicate, results[:skipped].first[:reason]
  end

  # Edge cases
  test "handles event with string keys" do
    event = {
      "id" => "string_key_event",
      "summary" => "2025나77777 문자열키 변론",
      "start_date" => "2026-05-15"
    }

    result = ScheduleCreator.new(@user, event).call

    assert result.success
    assert_equal "string_key_event", result.schedule.original_event_id
  end

  test "handles Google Calendar API date format" do
    event = {
      id: "gcal_format_event",
      summary: "2025나88888 구글형식 변론",
      start: { "date" => "2026-06-01" }
    }

    result = ScheduleCreator.new(@user, event).call

    assert result.success
    assert_equal Date.new(2026, 6, 1), result.schedule.original_date
  end

  test "handles event without case number" do
    event = {
      id: "no_case_number_event",
      summary: "일반 변론 기일",
      start_date: Date.new(2026, 5, 20)
    }

    result = ScheduleCreator.new(@user, event).call

    assert result.success
    assert_nil result.schedule.case_number
    assert_includes result.schedule.title, "[업무]"
    assert_includes result.schedule.title, "서면작성"
  end

  test "raises error when user has no work calendar" do
    user_without_calendar = User.create!(
      email_address: "no_calendar@example.com",
      password: "password123"
    )

    assert_raises(ActiveRecord::RecordNotFound) do
      ScheduleCreator.new(user_without_calendar, @lbox_event).call
    end
  end
end
