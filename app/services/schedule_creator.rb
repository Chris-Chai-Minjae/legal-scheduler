# @TASK T5.2 - Schedule creation service for n8n weekly-scan integration
# @SPEC .sdd/specs/schedule/spec.md#REQ-SCHED-01, REQ-SCHED-02, REQ-SCHED-06
#
# This service creates writing schedules (서면작성 일정) based on LBOX calendar events.
# Called by n8n workflow when it detects court dates (변론일) in the source calendar.

class ScheduleCreator
  # Result object for creation operations
  Result = Data.define(:success, :schedule, :error, :skipped_reason)

  # Initialize with user and LBOX event data
  #
  # @param user [User] The user for whom to create the schedule
  # @param lbox_event [Hash] Event data from LBOX calendar
  #   - :id [String] Google Calendar event ID
  #   - :summary [String] Event title
  #   - :description [String] Event description (optional)
  #   - :start_date [Date] Original court date (변론일)
  def initialize(user, lbox_event)
    @user = user
    @event = normalize_event(lbox_event)
    @settings = user.settings
  end

  # Create the schedule if validation passes
  #
  # @return [Result] Result object with success status and schedule/error
  def call
    # REQ-SCHED-06: Check for duplicate schedules
    if duplicate?
      return Result.new(
        success: false,
        schedule: nil,
        error: nil,
        skipped_reason: :duplicate
      )
    end

    # Calculate scheduled date with weekend adjustment
    target_date = calculate_scheduled_date

    # REQ-SCHED-01: Check weekly limit
    if weekly_limit_reached?(target_date)
      # Move to next available week
      target_date = find_next_available_date(target_date)
    end

    # Create the schedule
    schedule = Schedule.new(
      calendar: work_calendar,
      title: format_title,
      case_number: extract_case_number,
      case_name: extract_case_name,
      original_date: @event[:start_date],
      scheduled_date: target_date,
      original_event_id: @event[:id],
      status: :pending
    )

    if schedule.save
      Result.new(success: true, schedule: schedule, error: nil, skipped_reason: nil)
    else
      Result.new(success: false, schedule: nil, error: schedule.errors.full_messages.join(", "), skipped_reason: nil)
    end
  end

  # Batch create schedules from multiple events
  #
  # @param user [User] The user for whom to create schedules
  # @param events [Array<Hash>] Array of LBOX calendar events
  # @return [Hash] Summary of created, skipped, and failed schedules
  def self.batch_create(user, events)
    results = { created: [], skipped: [], failed: [] }

    events.each do |event|
      result = new(user, event).call

      case
      when result.success
        results[:created] << result.schedule
      when result.skipped_reason
        results[:skipped] << { event_id: event[:id], reason: result.skipped_reason }
      else
        results[:failed] << { event_id: event[:id], error: result.error }
      end
    end

    results
  end

  private

  # Normalize event data to symbols and proper types
  def normalize_event(event)
    {
      id: event[:id] || event["id"],
      summary: event[:summary] || event["summary"],
      description: event[:description] || event["description"],
      start_date: parse_date(event[:start_date] || event["start_date"] || event[:start] || event["start"])
    }
  end

  # Parse date from various formats
  def parse_date(date_value)
    case date_value
    when Date
      date_value
    when Time, DateTime
      date_value.to_date
    when String
      Date.parse(date_value)
    when Hash
      # Google Calendar API format: { "date" => "2026-02-15" }
      Date.parse(date_value["date"] || date_value[:date])
    else
      raise ArgumentError, "Cannot parse date from: #{date_value.inspect}"
    end
  end

  # REQ-SCHED-06: Check if schedule already exists for this event
  def duplicate?
    return false if @event[:id].blank?

    Schedule.exists?(original_event_id: @event[:id])
  end

  # Calculate scheduled_date based on lead_days and weekend exclusion
  #
  # REQ-SCHED-01: scheduled_date = original_date - lead_days
  # REQ-SCHED-01: Exclude weekends when setting is enabled
  def calculate_scheduled_date
    base_date = @event[:start_date] - @settings.lead_days.days

    if @settings.exclude_weekends
      adjust_for_weekend(base_date)
    else
      base_date
    end
  end

  # Adjust date to avoid weekends (move to Friday)
  #
  # Scenario 5 from spec:
  # - Saturday (wday=6) -> Friday (date - 1)
  # - Sunday (wday=0) -> Friday (date - 2)
  def adjust_for_weekend(date)
    case date.wday
    when 0 then date - 2.days  # Sunday -> Friday
    when 6 then date - 1.day   # Saturday -> Friday
    else date
    end
  end

  # REQ-SCHED-01: Check if weekly limit is reached for the target week
  def weekly_limit_reached?(date)
    week_start = date.beginning_of_week
    week_end = date.end_of_week

    existing_count = @user.schedules
      .where(status: [:pending, :approved])
      .where(scheduled_date: week_start..week_end)
      .count

    existing_count >= @settings.max_per_week
  end

  # Scenario 6: Find next available date when weekly limit is reached
  def find_next_available_date(start_date)
    candidate = start_date + 1.week
    # Move to the beginning of next week, adjust for weekends
    candidate = candidate.beginning_of_week

    if @settings.exclude_weekends
      candidate = adjust_for_weekend(candidate)
    end

    # Recursively check if next week is also full (max 4 iterations to prevent infinite loop)
    max_attempts = 4
    attempts = 0

    while weekly_limit_reached?(candidate) && attempts < max_attempts
      candidate += 1.week
      if @settings.exclude_weekends
        candidate = adjust_for_weekend(candidate)
      end
      attempts += 1
    end

    candidate
  end

  # Get user's work calendar for schedule creation
  def work_calendar
    @work_calendar ||= @user.calendars.work.first ||
      raise(ActiveRecord::RecordNotFound, "User has no work calendar configured")
  end

  # REQ-SCHED-02: Format title as "[업무] {case_number} {case_name} 서면작성"
  def format_title
    parts = ["[업무]"]
    parts << extract_case_number if extract_case_number.present?
    parts << extract_case_name if extract_case_name.present?
    parts << "서면작성"
    parts.join(" ")
  end

  # Extract case number from event summary or description
  # Common formats: 2025나12345, 2025고합123, etc.
  def extract_case_number
    @case_number ||= begin
      text = "#{@event[:summary]} #{@event[:description]}"
      # Korean court case number pattern: YYYY + Korean particle + digits
      match = text.match(/(\d{4}[가-힣]+\d+)/)
      match ? match[1] : nil
    end
  end

  # Extract case name from event summary
  # Removes the case number and common keywords to get the case name
  def extract_case_name
    @case_name ||= begin
      summary = @event[:summary].to_s.dup

      # Remove case number if present
      summary.gsub!(/\d{4}[가-힣]+\d+/, "")

      # Remove common keywords
      %w[변론 기일 재판 심리 검찰조사].each do |keyword|
        summary.gsub!(keyword, "")
      end

      # Remove common brackets content (e.g., [법정1])
      summary.gsub!(/\[.*?\]/, "")

      # Clean up whitespace and return
      summary.strip.presence
    end
  end
end
