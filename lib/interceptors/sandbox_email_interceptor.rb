module Interceptors

  class SandboxEmailInterceptor
    ALLOWED_EMAIL_DOMAIN = ["chronus.com"]
    MATCH_TEXT = Regexp.union(ALLOWED_EMAIL_DOMAIN.map{|domain| "@#{domain}"})
    SYSTEM_POPULATED_USERS_EMAIL_REGEX = /minimal/
    SEPERATOR = "-" * 80
    EMAIL_LOG_FILE_LOCATION = Rails.root.to_s + '/log/emails_logger.log'
    EXCLUDED_EMAILS = Regexp.union(["sendmail"]) #emails will skip interceptor and will be sent if this text is appended

    def self.delivering_email(message)
      emails = message_receivers(message)
      mails_to_filter = emails.select{|email| (MATCH_TEXT =~ email).nil? }

      if mails_to_filter.present?
        message.perform_deliveries = false        
      elsif defined?(PREVENT_EMAILS) && PREVENT_EMAILS
        content = [message.date, message.from.inspect, emails.inspect, message.subject]
        content.append(message.text_part.body) if message.text_part.present? && emails.reject{|email| (SYSTEM_POPULATED_USERS_EMAIL_REGEX =~ email)}.any?
        content.append(SEPERATOR)
        File.open(EMAIL_LOG_FILE_LOCATION, 'a') {|file| file.write(content.join("\n"))}
        update_message_receiver!(message)
        emails_to_send = message_receivers(message)
        message.perform_deliveries = emails_to_send.present?
      end
      message
    end    

    def self.message_receivers(message)
      (message.to || []) + ( message.cc || [])  + (message.bcc || [])
    end

    def self.update_message_receiver!(message)
      ["to", "cc", "bcc"].each do |target|
        message.send(target + "=", filter_excluded_mails(message.send(target)))
      end
    end

    def self.filter_excluded_mails(email_addresses)
      email_addresses.select{|email| (EXCLUDED_EMAILS =~ email)} if email_addresses
    end
  end
end