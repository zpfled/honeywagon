require 'google/apis/calendar_v3'
require 'signet/oauth_2/client'

module Google
  class CalendarClient
    CALENDAR_ID = 'primary'

    def initialize(user)
      @user = user
    end

    def upsert_event(service_event, route_date:, summary:, description:, location: nil)
      event = build_event(route_date: route_date, summary: summary, description: description, location: location)
      if service_event.google_calendar_event_id.present?
        calendar_service.update_event(CALENDAR_ID, service_event.google_calendar_event_id, event)
      else
        created = calendar_service.insert_event(CALENDAR_ID, event)
        service_event.update_column(:google_calendar_event_id, created.id)
      end
    end

    private

    attr_reader :user

    def calendar_service
      @calendar_service ||= begin
        service = Google::Apis::CalendarV3::CalendarService.new
        service.authorization = authorization
        service
      end
    end

    def authorization
      client = Signet::OAuth2::Client.new(
        client_id: Rails.application.credentials.dig(:google_oauth, :client_id),
        client_secret: Rails.application.credentials.dig(:google_oauth, :client_secret),
        token_credential_uri: 'https://oauth2.googleapis.com/token',
        refresh_token: user.google_calendar_refresh_token,
        access_token: user.google_calendar_access_token,
        expires_at: user.google_calendar_expires_at&.to_i
      )

      if user.google_calendar_token_expired? && user.google_calendar_refresh_token.present?
        client.refresh!
        user.update!(
          google_calendar_access_token: client.access_token,
          google_calendar_expires_at: Time.at(client.expires_at)
        )
      end

      client
    end

    def build_event(route_date:, summary:, description:, location:)
      Google::Apis::CalendarV3::Event.new(
        summary: summary,
        description: description,
        location: location,
        start: Google::Apis::CalendarV3::EventDateTime.new(date: route_date),
        end: Google::Apis::CalendarV3::EventDateTime.new(date: route_date + 1.day)
      )
    end
  end
end
