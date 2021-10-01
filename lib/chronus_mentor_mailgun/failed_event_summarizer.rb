# https://github.com/mailgun/mailgun-ruby
# http://stackoverflow.com/questions/10733717/initializing-ruby-singleton
require 'mailgun'

module ChronusMentorMailgun

  class FailedEventSummarizer
    # We can support time range in the future
    DEFAULT_NO_OF_DAYS_TO_CONSIDER = 1
    MAX_MAILGUN_EVENTS = 100
    IGNORE_ERROR_CODES = [605]
    NOT_DELIVERING_MAIL_ERROR_CODE = 605
    INVALID_RECEIPENT_ERROR_CODE = 550
    INVALID_RECEIPENT_ERROR_REASON = "bounce"
    PERMANENT_FAILED_EVENT_SEVERITY = "permanent"

    attr_reader :failed_events_hash, :all_failed_events

    def initialize(days_to_consider = DEFAULT_NO_OF_DAYS_TO_CONSIDER)
      @mg_client = Mailgun::Client.new(APP_CONFIG[:mailgun_api_key])
      @mg_events = Mailgun::Events.new(@mg_client, MAILGUN_DOMAIN)
      @start_time = (days_to_consider.days + 30.minutes).ago.to_i
      @params_hash = Hash[
        :limit => MAX_MAILGUN_EVENTS,
        :begin => @start_time,
        :end => Time.now.to_i
      ]
      @failed_events_hash = Hash[
        ChronusMentorMailgun::Event::FAILED => [],
        ChronusMentorMailgun::Event::BOUNCED => [],
        ChronusMentorMailgun::Event::SPAMMED => []
      ]

      # All events here
      @all_failed_events = {}
    end

    def summarize
      populate_permanently_failed_and_bounced_events
      populate_spammed_events
      populate_all_failed_events

      InternalMailer.mailgun_failed_summary_notification(@failed_events_hash, @all_failed_events).deliver_now
    end

    private

    def populate_permanently_failed_and_bounced_events
      params_hash = @params_hash.merge(:event => ChronusMentorMailgun::Event::FAILED, :severity => PERMANENT_FAILED_EVENT_SEVERITY)
      # Permanent failures here. Bounced is a subset of these events but not complained!!
      mailgun_events = @mg_events.get(params_hash)
      # Do not consider failed events with error code - 605 'Not delivering to previously bounced address'.
      while !(items_array = mailgun_events.to_h['items']).empty?
        items_array.each do | item |
          event_type = ChronusMentorMailgun::Event::FAILED
          error_code, description = self.class.get_error_code_and_description(item)
          # Ignore 605 errors
          next if error_code == NOT_DELIVERING_MAIL_ERROR_CODE

          # Bounced events are nothing but failed events with error code 550 and reason as bounce
          if self.class.is_bounced_event?(error_code, item['reason'])
            event_type = ChronusMentorMailgun::Event::BOUNCED
          end
          @failed_events_hash[event_type] << self.class.make_hash_of_mailgun_item(item)
        end
        mailgun_events = @mg_events.next
      end
    end

    def populate_spammed_events
      # Spammed Events here:
      event_type = ChronusMentorMailgun::Event::SPAMMED
      params_hash = @params_hash.merge(:event => event_type)
      mailgun_events = @mg_events.get(params_hash)
      while !(items_array = mailgun_events.to_h['items']).empty?
        items_array.each do | item |
          failed_events_hash[event_type] << self.class.make_hash_of_mailgun_item(item)
        end
        mailgun_events = @mg_events.next
      end
    end

    def populate_all_failed_events
      params_hash = @params_hash.merge(:event => ChronusMentorMailgun::Event::FAILED)
      all_failures = @mg_events.get(params_hash)
      while !(items_array = all_failures.to_h['items']).empty?
        items_array.each do | item |
          @all_failed_events = self.class.make_hash_of_mailgun_all_item(all_failed_events, item)
        end
        all_failures = @mg_events.next
      end
    end

    def self.get_error_code_and_description(item)
      if item['delivery-status'].present?
        return item['delivery-status']['code'], item['delivery-status']['message'] || item['delivery-status']['description']
      else
        return 0, "No description available"
      end
    end
    
    def self.get_subject_and_message_id(item)
      if item['message'].present? && item['message']['headers'].present?
        return item['message']['headers']['subject'], item['message']['headers']['message-id']
      else
        return "No subject available", "No message_id available"
      end
    end

    def self.make_hash_of_mailgun_item(item)
      error_code, error_description = get_error_code_and_description(item)
      subject , message_id = get_subject_and_message_id(item)
      {
        :timestamp => Time.at(item['timestamp'].to_f).to_s,
        :recipient => item['recipient'],
        :subject => subject, 
        :error_code => error_code, 
        :error_description => error_description,
        :message_id => message_id
      }
    end

    def self.make_hash_of_mailgun_all_item(all_failed_events, item)
      error_code, description = get_error_code_and_description(item)
      unless all_failed_events[error_code].present?
        all_failed_events[error_code] = {
          :count => 0,
          :recipients => []
        }
      end
      count, recipients = all_failed_events[error_code][:count] + 1, all_failed_events[error_code][:recipients].push(item['recipient'])
      all_failed_events[error_code] = 
      {
        :count => count,
        :timestamp => Time.at(item['timestamp'].to_f).to_s,
        :error_description => description,
        :recipients => recipients
      }
      all_failed_events[error_code][:recipients].uniq!
      all_failed_events
    end

    def self.is_bounced_event?(error_code, reason)
      (error_code == INVALID_RECEIPENT_ERROR_CODE && reason == INVALID_RECEIPENT_ERROR_REASON )
    end


  end

end

