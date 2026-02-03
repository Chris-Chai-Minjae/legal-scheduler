# @TASK T2.2 - Calendar model test
# @SPEC REQ-CAL-02: Calendar type validation

require "test_helper"

class CalendarTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  # Scenario 1: 기본 캘린더 생성
  test "should create calendar with valid attributes" do
    calendar = @user.calendars.build(
      google_id: "test@example.com",
      name: "Test Calendar",
      calendar_type: :lbox,
      color: "#4285F4"
    )

    assert calendar.valid?
    assert calendar.save
  end

  # Scenario 2: 필수 필드 검증
  test "should not save calendar without required fields" do
    calendar = Calendar.new

    assert_not calendar.valid?
    assert_includes calendar.errors[:user_id], "can't be blank"
    assert_includes calendar.errors[:google_id], "can't be blank"
    assert_includes calendar.errors[:name], "can't be blank"
    assert_includes calendar.errors[:calendar_type], "can't be blank"
  end

  # Scenario 3: google_id 유니크 제약 (user별)
  test "should not allow duplicate google_id for same user" do
    @user.calendars.create!(
      google_id: "duplicate@example.com",
      name: "First Calendar",
      calendar_type: :lbox
    )

    duplicate = @user.calendars.build(
      google_id: "duplicate@example.com",
      name: "Second Calendar",
      calendar_type: :work
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:google_id], "has already been taken"
  end

  # Scenario 4: 다른 사용자는 같은 google_id 사용 가능
  test "should allow same google_id for different users" do
    user2 = User.create!(
      email_address: "user2@example.com",
      password: "Password123"
    )

    @user.calendars.create!(
      google_id: "shared@example.com",
      name: "User1 Calendar",
      calendar_type: :lbox
    )

    calendar2 = user2.calendars.build(
      google_id: "shared@example.com",
      name: "User2 Calendar",
      calendar_type: :lbox
    )

    assert calendar2.valid?
    assert calendar2.save
  end

  # @TASK T2.2 - Calendar type validation
  # Scenario 5: 각 타입당 1개씩만 할당 가능
  test "should not allow multiple calendars of same type per user" do
    # 첫 번째 LBOX 캘린더 생성
    @user.calendars.create!(
      google_id: "lbox1@example.com",
      name: "First LBOX",
      calendar_type: :lbox
    )

    # 두 번째 LBOX 캘린더 생성 시도
    second_lbox = @user.calendars.build(
      google_id: "lbox2@example.com",
      name: "Second LBOX",
      calendar_type: :lbox
    )

    assert_not second_lbox.valid?
    assert_includes second_lbox.errors[:calendar_type], "already assigned to another calendar"
  end

  # Scenario 6: 타입 변경 시 검증
  test "should validate uniqueness when changing calendar type" do
    # LBOX 캘린더 생성
    lbox_calendar = @user.calendars.create!(
      google_id: "lbox@example.com",
      name: "LBOX Calendar",
      calendar_type: :lbox
    )

    # Work 캘린더 생성
    work_calendar = @user.calendars.create!(
      google_id: "work@example.com",
      name: "Work Calendar",
      calendar_type: :work
    )

    # Work 캘린더를 LBOX로 변경 시도 (이미 LBOX가 있음)
    work_calendar.calendar_type = :lbox

    assert_not work_calendar.valid?
    assert_includes work_calendar.errors[:calendar_type], "already assigned to another calendar"
  end

  # Scenario 7: 서로 다른 타입은 동시에 할당 가능
  test "should allow one calendar per each type" do
    lbox = @user.calendars.create!(
      google_id: "lbox@example.com",
      name: "LBOX Calendar",
      calendar_type: :lbox
    )

    work = @user.calendars.create!(
      google_id: "work@example.com",
      name: "Work Calendar",
      calendar_type: :work
    )

    personal = @user.calendars.create!(
      google_id: "personal@example.com",
      name: "Personal Calendar",
      calendar_type: :personal
    )

    assert lbox.persisted?
    assert work.persisted?
    assert personal.persisted?
    assert_equal 3, @user.calendars.count
  end

  # Scenario 8: calendar_type enum 값 검증
  test "should have valid calendar_type enum values" do
    calendar = @user.calendars.build(
      google_id: "test@example.com",
      name: "Test Calendar"
    )

    # lbox (0)
    calendar.calendar_type = :lbox
    assert_equal 0, calendar.calendar_type_before_type_cast
    assert calendar.lbox?

    # work (1)
    calendar.calendar_type = :work
    assert_equal 1, calendar.calendar_type_before_type_cast
    assert calendar.work?

    # personal (2)
    calendar.calendar_type = :personal
    assert_equal 2, calendar.calendar_type_before_type_cast
    assert calendar.personal?
  end

  # Scenario 9: 타입 해제 가능 (nil)
  test "should allow unsetting calendar_type" do
    calendar = @user.calendars.create!(
      google_id: "test@example.com",
      name: "Test Calendar",
      calendar_type: :lbox
    )

    # 타입 해제
    calendar.update(calendar_type: nil)
    calendar.reload

    assert_nil calendar.calendar_type
  end
end
