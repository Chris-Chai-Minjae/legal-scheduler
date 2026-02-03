# @TASK T5.2 - Schedule Model Tests
# @SPEC .sdd/specs/schedule/spec.md#REQ-SCHED-02, REQ-SCHED-04, REQ-SCHED-05

require "test_helper"

class ScheduleTest < ActiveSupport::TestCase
  setup do
    @schedule = schedules(:one)
    @calendar = calendars(:one)
  end

  # Validation tests
  test "requires calendar_id" do
    schedule = Schedule.new(title: "Test", original_date: Date.today + 14, scheduled_date: Date.today)
    assert_not schedule.valid?
    assert_includes schedule.errors[:calendar_id], "can't be blank"
  end

  test "requires title" do
    schedule = Schedule.new(calendar: @calendar, original_date: Date.today + 14, scheduled_date: Date.today)
    assert_not schedule.valid?
    assert_includes schedule.errors[:title], "can't be blank"
  end

  test "requires original_date" do
    schedule = Schedule.new(calendar: @calendar, title: "Test", scheduled_date: Date.today)
    assert_not schedule.valid?
    assert_includes schedule.errors[:original_date], "can't be blank"
  end

  test "requires scheduled_date" do
    schedule = Schedule.new(calendar: @calendar, title: "Test", original_date: Date.today + 14)
    assert_not schedule.valid?
    assert_includes schedule.errors[:scheduled_date], "can't be blank"
  end

  test "scheduled_date must be before original_date" do
    schedule = Schedule.new(
      calendar: @calendar,
      title: "Test",
      original_date: Date.today,
      scheduled_date: Date.today + 1
    )
    assert_not schedule.valid?
    assert_includes schedule.errors[:scheduled_date], "must be before the original court date (변론일)"
  end

  test "original_event_id must be unique" do
    duplicate = Schedule.new(
      calendar: @calendar,
      title: "Duplicate Test",
      original_date: Date.today + 30,
      scheduled_date: Date.today + 16,
      original_event_id: @schedule.original_event_id
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:original_event_id], "has already been taken"
  end

  # Status enum tests
  test "default status is pending" do
    schedule = Schedule.new(
      calendar: @calendar,
      title: "New Schedule",
      original_date: Date.today + 21,
      scheduled_date: Date.today + 7
    )
    schedule.save!
    assert schedule.pending?
  end

  test "can transition to approved" do
    schedule = schedules(:one)
    schedule.approve!
    assert schedule.approved?
  end

  test "can transition to rejected" do
    schedule = schedules(:one)
    schedule.reject!
    assert schedule.rejected?
  end

  # REQ-SCHED-04: Approve with created_event_id
  test "approve! sets created_event_id" do
    schedule = schedules(:one)
    schedule.approve!(created_event_id: "gcal_created_123")

    assert schedule.approved?
    assert_equal "gcal_created_123", schedule.created_event_id
  end

  # Scope tests
  test "pending_approval scope" do
    pending = Schedule.pending_approval
    assert pending.all?(&:pending?)
  end

  test "approved scope" do
    approved = Schedule.approved
    assert approved.all?(&:approved?)
  end

  test "rejected scope" do
    rejected = Schedule.rejected
    assert rejected.all?(&:rejected?)
  end

  test "upcoming scope" do
    upcoming = Schedule.upcoming
    assert upcoming.all? { |s| s.scheduled_date >= Date.today }
  end

  test "for_week scope" do
    # Create schedules for a specific week
    target_date = Date.new(2026, 6, 10)  # Wednesday
    week_schedule = Schedule.create!(
      calendar: @calendar,
      title: "Week Test",
      original_date: target_date + 14,
      scheduled_date: target_date
    )

    schedules_in_week = Schedule.for_week(target_date)
    assert_includes schedules_in_week, week_schedule
  end

  test "active scope includes pending and approved" do
    active = Schedule.active
    active.each do |s|
      assert s.pending? || s.approved?
    end
  end

  test "by_original_event scope" do
    event_id = @schedule.original_event_id
    schedules = Schedule.by_original_event(event_id)
    assert schedules.all? { |s| s.original_event_id == event_id }
  end

  # Instance method tests
  test "on_weekend? returns true for Saturday" do
    schedule = Schedule.new(
      calendar: @calendar,
      title: "Saturday",
      original_date: Date.new(2026, 3, 28),  # Saturday + 14 = April 11
      scheduled_date: Date.new(2026, 3, 14)  # Saturday
    )
    assert schedule.on_weekend?
  end

  test "on_weekend? returns true for Sunday" do
    schedule = Schedule.new(
      calendar: @calendar,
      title: "Sunday",
      original_date: Date.new(2026, 3, 29),  # Sunday + 14 = April 12
      scheduled_date: Date.new(2026, 3, 15)  # Sunday
    )
    assert schedule.on_weekend?
  end

  test "on_weekend? returns false for weekday" do
    schedule = Schedule.new(
      calendar: @calendar,
      title: "Weekday",
      original_date: Date.new(2026, 3, 30),
      scheduled_date: Date.new(2026, 3, 16)  # Monday
    )
    assert_not schedule.on_weekend?
  end

  test "status_text returns Korean text" do
    assert_equal "대기중", Schedule.new(status: :pending).status_text
    assert_equal "승인됨", Schedule.new(status: :approved).status_text
    assert_equal "거부됨", Schedule.new(status: :rejected).status_text
  end

  test "days_until calculates correctly" do
    schedule = Schedule.new(scheduled_date: Date.today + 5)
    assert_equal 5, schedule.days_until
  end

  test "days_until_court calculates correctly" do
    schedule = Schedule.new(original_date: Date.today + 14)
    assert_equal 14, schedule.days_until_court
  end

  # Class method tests
  test "format_title with all parts" do
    title = Schedule.format_title(case_number: "2025나12345", case_name: "손해배상")
    assert_equal "[업무] 2025나12345 손해배상 서면작성", title
  end

  test "format_title without case_number" do
    title = Schedule.format_title(case_name: "손해배상")
    assert_equal "[업무] 손해배상 서면작성", title
  end

  test "format_title without case_name" do
    title = Schedule.format_title(case_number: "2025나12345")
    assert_equal "[업무] 2025나12345 서면작성", title
  end

  test "format_title with no parts" do
    title = Schedule.format_title
    assert_equal "[업무] 서면작성", title
  end
end
