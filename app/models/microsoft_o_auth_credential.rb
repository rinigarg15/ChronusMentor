class MicrosoftOAuthCredential < OAuthCredential
  CLIENT_ID = APP_CONFIG[:microsoft_oauth_calendar_sync_v2_client_id]
  CLIENT_SECRET = APP_CONFIG[:microsoft_oauth_calendar_sync_v2_client_secret]
  AUTHORIZE_URL = "/common/oauth2/v2.0/authorize?scope=offline_access+https%3A%2F%2Foutlook.office.com%2FCalendars.Read"
  TOKEN_URL = "/common/oauth2/v2.0/token"
  SITE = "https://login.microsoftonline.com"
  API_ENDPOINT = "https://outlook.office.com/api/v2.0/me/calendarview"
  # running on any other port may not work
  REDIRECT_URL_FOR_DEVELOPMENT = "http://localhost:3000/authorize_outlook"

  belongs_to :ref_obj, polymorphic: true
  
  class << self
    def get_oauth_client(options = {})
      OAuth2::Client.new(CLIENT_ID, CLIENT_SECRET, {
        site: SITE,
        authorize_url: AUTHORIZE_URL,
        token_url: TOKEN_URL,
        redirect_uri: options[:redirect_uri],
      })
    end
  end

  private

  def get_raw_response_for_free_busy_slots(oauth2_access_token_obj, start_time, end_time, options = {})
    target_api_url = options[:target_api_url]
    unless target_api_url
      start_time_str = convert_ruby_time_to_microsoft_datetime_str(start_time)
      end_time_str = convert_ruby_time_to_microsoft_datetime_str(end_time)
      request_params = "startDateTime=#{start_time_str}&endDateTime=#{end_time_str}&$select=Start,End&$top=100"
      target_api_url = "#{API_ENDPOINT}?#{request_params}"
    end
    oauth2_access_token_obj.get(target_api_url, {headers: {"Content-type" => "application/json"}})
  end

  def fetch_freebusy_ary(parsed_response, _options = {})
    parsed_response["value"]
  end

  def get_url_for_next_set_of_data(parsed_response)
    parsed_response["@odata.nextLink"]
  end

  def more_data_present?(parsed_response)
    get_url_for_next_set_of_data(parsed_response).present?
  end

  def convert_ruby_time_to_microsoft_datetime_str(time_obj)
    time_obj.utc.strftime("%Y-%m-%dT%H:%M")
  end

  def convert_provider_datetime_str_to_ruby_time(obj, options = {})
    convert_microsoft_datetime_str_to_ruby_time(obj, (options[:boundary] == :start ? "Start" : "End"))
  end

  def convert_microsoft_datetime_str_to_ruby_time(obj, key)
    datetime_str = "#{obj[key]["DateTime"]} #{obj[key]["TimeZone"]}"
    Time.parse(datetime_str)
  end

  def get_oauth2_error_code(error)
    error.response.status.to_s
  end

  def get_oauth2_error_message(error)
    error.try(:description).presence || ""
  end

  def refresh_token_expired?(error)
    error.try(:code).to_s == INVALID_GRANT
  end
end
