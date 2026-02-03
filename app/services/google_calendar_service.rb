# frozen_string_literal: true

# @TASK T2.1 - Google Calendar Service for calendar list retrieval
# @SPEC REQ-CAL-01: Retrieve user's Google Calendar list via API

require "google/apis/calendar_v3"
require "googleauth"

class GoogleCalendarService
  CACHE_TTL = 1.hour
  CALENDAR_SCOPE = "https://www.googleapis.com/auth/calendar.readonly"

  attr_reader :user

  def initialize(user)
    @user = user
    raise ArgumentError, "User must have Google OAuth token" unless user.google_access_token.present?
  end

  # List all calendars for the user
  # @return [Array<Hash>] Array of calendar objects
  def list_calendars(force_refresh: false)
    cache_key = "user_#{user.id}_calendars"

    if force_refresh
      Rails.cache.delete(cache_key)
    end

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      fetch_calendars_from_api
    end
  end

  # List events from a specific calendar
  # @param calendar_id [String] Google Calendar ID
  # @param time_min [Time] Start of time range (default: now)
  # @param time_max [Time] End of time range (default: 30 days from now)
  # @param max_results [Integer] Maximum events to return (default: 50)
  # @return [Array<Hash>] Array of event objects
  def list_events(calendar_id:, time_min: Time.current, time_max: 30.days.from_now, max_results: 50)
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = authorization

    begin
      response = service.list_events(
        calendar_id,
        time_min: time_min.iso8601,
        time_max: time_max.iso8601,
        max_results: max_results,
        single_events: true,
        order_by: "startTime"
      )

      (response.items || []).map do |event|
        {
          id: event.id,
          summary: event.summary,
          description: event.description,
          start_date: parse_event_date(event.start),
          end_date: parse_event_date(event.end),
          location: event.location,
          status: event.status
        }
      end
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "Google Calendar API authorization error: #{e.message}"
      refresh_access_token
      retry
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Google Calendar API client error: #{e.message}"
      []
    end
  end

  # Check if an event exists in Google Calendar
  # @param calendar_id [String] Google Calendar ID
  # @param event_id [String] Google Calendar event ID
  # @return [Boolean] true if event exists and is not cancelled, false otherwise
  def event_exists?(calendar_id:, event_id:)
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = authorization

    begin
      event = service.get_event(calendar_id, event_id)
      # Event exists and is not cancelled
      event.status != "cancelled"
    rescue Google::Apis::ClientError => e
      # 404 = event not found (deleted)
      if e.status_code == 404
        false
      else
        Rails.logger.error "Google Calendar API error checking event: #{e.message}"
        raise
      end
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "Google Calendar API authorization error: #{e.message}"
      refresh_access_token
      retry
    end
  end

  # Get a specific event from Google Calendar
  # @param calendar_id [String] Google Calendar ID
  # @param event_id [String] Google Calendar event ID
  # @return [Hash, nil] Event data or nil if not found/deleted
  def get_event(calendar_id:, event_id:)
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = authorization

    begin
      event = service.get_event(calendar_id, event_id)
      {
        id: event.id,
        summary: event.summary,
        description: event.description,
        start_date: parse_event_date(event.start),
        end_date: parse_event_date(event.end),
        status: event.status,
        updated: event.updated
      }
    rescue Google::Apis::ClientError => e
      if e.status_code == 404
        nil
      else
        Rails.logger.error "Google Calendar API error getting event: #{e.message}"
        nil
      end
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "Google Calendar API authorization error: #{e.message}"
      refresh_access_token
      retry
    end
  end

  # Create an event in a calendar
  # @param calendar_id [String] Google Calendar ID
  # @param summary [String] Event title
  # @param description [String] Event description
  # @param start_date [Date] Event start date
  # @param end_date [Date] Event end date
  # @return [Hash, nil] Created event or nil on failure
  def create_event(calendar_id:, summary:, description: nil, start_date:, end_date: nil)
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = authorization

    end_date ||= start_date

    event = Google::Apis::CalendarV3::Event.new(
      summary: summary,
      description: description,
      start: Google::Apis::CalendarV3::EventDateTime.new(date: start_date.to_s),
      end: Google::Apis::CalendarV3::EventDateTime.new(date: (end_date + 1.day).to_s)
    )

    begin
      result = service.insert_event(calendar_id, event)
      {
        id: result.id,
        summary: result.summary,
        html_link: result.html_link
      }
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "Google Calendar API authorization error: #{e.message}"
      refresh_access_token
      retry
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Google Calendar API client error creating event: #{e.message}"
      nil
    end
  end

  private

  def parse_event_date(event_time)
    return nil unless event_time

    if event_time.date
      Date.parse(event_time.date)
    elsif event_time.date_time
      event_time.date_time.to_date
    end
  end

  def fetch_calendars_from_api
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = authorization

    begin
      response = service.list_calendar_lists
      calendars = response.items.map do |calendar|
        {
          id: calendar.id,
          summary: calendar.summary,
          description: calendar.description,
          time_zone: calendar.time_zone,
          primary: calendar.primary || false,
          access_role: calendar.access_role,
          background_color: calendar.background_color,
          foreground_color: calendar.foreground_color
        }
      end

      calendars
    rescue Google::Apis::AuthorizationError => e
      # Token expired, attempt to refresh
      Rails.logger.error "Google Calendar API authorization error: #{e.message}"
      refresh_access_token
      retry
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Google Calendar API client error: #{e.message}"
      raise
    rescue StandardError => e
      Rails.logger.error "Unexpected error fetching calendars: #{e.message}"
      raise
    end
  end

  def authorization
    # Create OAuth2 credentials from user's stored tokens
    # Use ENV variables (same as GoogleOauthController)
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
      client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
      scope: CALENDAR_SCOPE,
      access_token: user.google_access_token,
      refresh_token: user.google_refresh_token
    )

    # Check if token is expired
    if user.google_token_expires_at && user.google_token_expires_at < Time.current
      credentials.refresh!
      update_user_tokens(credentials)
    end

    credentials
  end

  def refresh_access_token
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
      client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
      scope: CALENDAR_SCOPE,
      refresh_token: user.google_refresh_token
    )

    credentials.refresh!
    update_user_tokens(credentials)
  end

  def update_user_tokens(credentials)
    user.update!(
      google_access_token: credentials.access_token,
      google_token_expires_at: Time.current + credentials.expires_in.seconds
    )
  end
end
