class OAuthCredential < ActiveRecord::Base
  INVALID_GRANT = "invalid_grant"

  module Provider
    def self.supported
      [GoogleOAuthCredential, OutlookOAuthCredential, Office365OAuthCredential]
    end

    def self.supported_provider_urls
      [GoogleOAuthCredential::AUTHORIZE_URL, MicrosoftOAuthCredential::SITE + MicrosoftOAuthCredential::AUTHORIZE_URL]
    end
  end

  module ErrorCode
    INVALID_CREDENTIALS = "401"
  end

  belongs_to :ref_obj, polymorphic: true
  validates :ref_obj, presence: true

  def get_oauth2_access_token_obj(options = {})
    OAuth2::AccessToken.new(self.class.get_oauth_client(options), access_token, refresh_token: refresh_token)
  end

  def get_free_busy_slots(start_time, end_time, options = {})
    begin
      busy_slots = []
      parsed_response = nil
      loop do
        parsed_response = get_response_from_api_call_and_update_data_obj!(busy_slots, start_time, end_time, target_api_url: (parsed_response && get_url_for_next_set_of_data(parsed_response)), calendar_key: options[:calendar_key])
        break unless more_data_present?(parsed_response)
      end
      {error_occured: false, busy_slots: busy_slots}
    rescue => error
      handle_exception(error, start_time, end_time, options)
    end
  end

  def get_response_from_api_call_and_update_data_obj!(busy_slots, start_time, end_time, options = {})
    parsed_response = get_parsed_response_for_free_busy_slots(start_time, end_time, options)
    update_busy_slots_ary!(busy_slots, fetch_freebusy_ary(parsed_response, options))
    parsed_response
  end

  def update_busy_slots_ary!(busy_slots, freebusy_ary)
    freebusy_ary.each do |obj|
      busy_slots << {start_time: convert_provider_datetime_str_to_ruby_time(obj, boundary: :start), end_time: convert_provider_datetime_str_to_ruby_time(obj, boundary: :end)}
    end
  end

  def get_parsed_response_for_free_busy_slots(start_time, end_time, options = {})
    response = get_raw_response_for_free_busy_slots(get_oauth2_access_token_obj, start_time, end_time, options)
    get_parsed_response(response)
  end

  def get_parsed_response(response)
    JSON(response.body)
  end

  def refresh
    begin
      oauth2_access_token_obj = get_oauth2_access_token_obj.refresh!
      self.access_token = oauth2_access_token_obj.token
      self.refresh_token = oauth2_access_token_obj.refresh_token
      save!
      { refreshed_successfully: true }
    rescue => refresh_error
      ret = { refreshed_successfully: false }
      if refresh_error.class == OAuth2::Error
        destroy if refresh_token_expired?(refresh_error) # User has revoked the access, in that case destroy this credential object.
        ret.merge!(error_code: get_oauth2_error_code(refresh_error), error_message: get_oauth2_error_message(refresh_error))
      end
      ret
    end
  end

  def handle_exception(error, start_time, end_time, options = {})
    hsh = (error.class == OAuth2::Error ? handle_oauth2_exception(error, start_time, end_time, options) : exception_return_value(message: error.try(:message).to_s))
    error_code = hsh.try(:[], :error_code).to_s.presence || 'N/A'
    error_message = hsh.try(:[], :error_message).presence || '<no error message>'
    Airbrake.notify("#{self.class.name} (id: #{id || 'nil'}) Error Code (#{error_code}) : #{error_message}") if hsh[:error_occured]
    hsh
  end

  def handle_oauth2_exception(error, start_time, end_time, options = {})
    error_code = get_oauth2_error_code(error)
    error_message = get_oauth2_error_message(error)
    case error_code
    when ErrorCode::INVALID_CREDENTIALS # Suggested action is to try refreshing access token using refresh token
      unless options[:dont_refresh]
        refresh_result = refresh
        return get_free_busy_slots(start_time, end_time, dont_refresh: true, calendar_key: options[:calendar_key]) if refresh_result[:refreshed_successfully]
        error_code = refresh_result[:error_code].to_s
        error_message = refresh_result[:error_message].to_s
      end
    end
    exception_return_value(code: error_code, message: error_message)
  end

  private

  def exception_return_value(options = {})
    hsh = {error_occured: true, busy_slots: []}
    hsh[:error_code] = options[:code] if options[:code]
    hsh[:error_message] = options[:message] if options[:message]
    hsh
  end
end