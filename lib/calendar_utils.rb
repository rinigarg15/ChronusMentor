module CalendarUtils
  module REQUEST_TYPE
    REQUEST = "REQUEST"
    CANCEL = "CANCEL"
  end


  ENCRYPTION_KEY = "01f0d45ad5e31f1b213565fd7584273f"

  def self.match_organizer_email(email, reply_to_prefix)
    email.match(/\A#{reply_to_prefix}\+(?<klass_id>[a-zA-Z0-9]+)@#{MAILGUN_DOMAIN}\z/)
  end

  def self.get_email_address(canonical_email_address)
    Mail::Address.new(canonical_email_address).address
  end

  def self.get_calendar_event_uid(object)
    "#{object.class.name.underscore.downcase}_#{DateTime.localize(object.created_at.utc, format: :ics_full_time)}@chronus.com"
  end

end