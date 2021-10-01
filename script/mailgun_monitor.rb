#!/usr/bin/env ruby

# This is a half baked script which pull data from Mailgun logs using mailgun api, dont run this script as such, replace APP_CONFIG[:mailgun_api_key] with the mailgun API key. This is to be used only for pulling data for monitoring purposes.  array, description, message, count are the variables you will need.
# DO NOT run this script as such, use the methods in your console.

# gets failures grouped by error code and description/message of the first error of each error code.

require 'mailgun'
require 'active_support/core_ext/numeric'
require 'csv'


MAX_MAILGUN_EVENTS = 100
OUTPUT_FILE = "/tmp/mailgun_data.csv"
FAILED      = 'failed'

def init
  @start_time = (Time.now - 24.hours).utc.to_i
  @end_time = Time.now.utc.to_i
  @mg_client = Mailgun::Client.new(APP_CONFIG[:mailgun_api_key]) # wont work unless you set this in ENV or change it to key
  domain = "mentormg.chronus.com"
  @mg_events = Mailgun::Events.new(@mg_client, domain)
end


 
#result = mg_client.get("#{domain}/events", {:event => 'delivered'})
def get_error_code_and_description(item)
  if item['delivery-status'].present?
    return item['delivery-status']['code'], item['delivery-status']['message'] || item['delivery-status']['description']
  else
    return 0, "No description available"
  end
end

def build_mailgun_failed_events(status_str, end_time)
  result = @mg_events.get({ 
    :limit => MAX_MAILGUN_EVENTS, 
    :begin => @start_time, 
    :end => end_time, 
    :event => status_str 
  }) 

  all_failed_events = {}
  while !(items_array = result.to_h['items']).empty? 
    items_array.each do |item|
      error_code, description = get_error_code_and_description(item)
      all_failed_events[error_code] = {:count => 0, :recipients => [] } if all_failed_events[error_code].nil?
      count, recipients = all_failed_events[error_code][:count] + 1, all_failed_events[error_code][:recipients].push(item['recipient'])

      all_failed_events[error_code] =
      {
        :count => count,
        :description => description,
        :recipients => recipients
      }

      all_failed_events[error_code][:recipients].uniq!
    end 
    result = @mg_events.next 
  end
  all_failed_events
end

def generate_mailgun_log(all_failed_events, csv_file)
  CSV.open(csv_file, "w") do |csv|
    csv << ["No.", "Code", "Total Occurences", "Unique Occurences", "Description"]
      all_failed_events.each_with_index do |x, i|
      code, error = x
      csv << [i+1, code, error[:count], error[:recipients].size, error[:description]]
      puts "Error Code: #{code}"
      puts "Total Uniq Recipient: #{error[:recipients].size}"
      puts "Recipient List: #{error[:recipients]}"
    end
  end
end

init
all_failed_events = build_mailgun_failed_events(FAILED, @end_time)
generate_mailgun_log(all_failed_events, OUTPUT_FILE)

puts "Please check generated csv log file: #{OUTPUT_FILE}"

