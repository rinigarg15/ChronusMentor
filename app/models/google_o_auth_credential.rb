class GoogleOAuthCredential < OAuthCredential
  CLIENT_ID = APP_CONFIG[:google_oauth_calendar_sync_v2_client_id]
  CLIENT_SECRET = APP_CONFIG[:google_oauth_calendar_sync_v2_client_secret]
  AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth?prompt=consent&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcalendar.readonly&access_type=offline"
  TOKEN_URL = "https://www.googleapis.com/oauth2/v4/token"
  API_ENDPOINT = "https://www.googleapis.com/calendar/v3/freeBusy"

  belongs_to :ref_obj, polymorphic: true

  module Provider
    NAME = "feature.calendar_sync_v2.label.google".translate
    IMAGE_URL = "calendar_sync_v2/google.png"
  end

  class << self
    def get_oauth_client(options = {})
      OAuth2::Client.new(CLIENT_ID, CLIENT_SECRET, {
        authorize_url: AUTHORIZE_URL,
        redirect_uri: options[:redirect_uri],
        token_url: TOKEN_URL
      })
    end
  end

  private

  def get_raw_response_for_free_busy_slots(oauth2_access_token_obj, start_time, end_time, options = {})
    # https://developers.google.com/google-apps/calendar/v3/reference/freebusy/query
    oauth2_access_token_obj.post(API_ENDPOINT, {
      headers: {"Content-type" => "application/json"},
      body: {
        items: [{id: options[:calendar_key]}],
        timeMin: convert_ruby_time_to_google_datetime_str(start_time),
        timeMax: convert_ruby_time_to_google_datetime_str(end_time)
      }.to_json
    })
  end

  def fetch_freebusy_ary(parsed_response, options = {})
    # https://developers.google.com/google-apps/calendar/v3/reference/freebusy/query
    calendar_key = options[:calendar_key] || "primary"
    parsed_response["calendars"][calendar_key]["busy"]
  end

  def more_data_present?(_parsed_response)
    false
  end

  def convert_ruby_time_to_google_datetime_str(time_obj)
    time_obj.utc.iso8601
  end

  def convert_provider_datetime_str_to_ruby_time(obj, options = {})
    convert_google_datetime_str_to_ruby_time(obj.try(:[], (options[:boundary] == :start ? "start" : "end")))
  end

  def convert_google_datetime_str_to_ruby_time(datetime_str)
    Time.iso8601(datetime_str)
  end

  def get_oauth2_error_code(error) # https://developers.google.com/google-apps/calendar/v3/errors
    (error.code.try(:[], "code") || error.code).to_s
  end

  def get_oauth2_error_message(error)
    (error.code.try(:[], "message") || error.description).to_s
  end

  def refresh_token_expired?(error)
    get_oauth2_error_code(error) == INVALID_GRANT
  end
end
