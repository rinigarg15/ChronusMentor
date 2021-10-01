ValidatesEmailFormatOf.module_eval do
  mattr_accessor :email_domain_validity_cache, instance_accessor: false

  self.email_domain_validity_cache = {}
end

ValidatesEmailFormatOf.class_eval do
  def self.validate_email_domain(email)
    domain = email.to_s.downcase.match(/\@(.+)/)[1]
    result = self.email_domain_validity_cache[domain].nil? ? self.validate_email_domain_super(email) : self.email_domain_validity_cache[domain]
    self.email_domain_validity_cache[domain] = result
    return result
  end

  def self.validate_email_domain_super(email)
    domain = email.to_s.downcase.match(/\@(.+)/)[1]
    Resolv::DNS.open do |dns|
      @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX) + dns.getresources(domain, Resolv::DNS::Resource::IN::A)
    end
    @mx.size > 0
  end
end

module ActiveModel
  module Validations
    EmailFormatValidator.class_eval do
      def validate_each(record, attribute, value)
        # If generate_message is true then I18n key of the error message will be returned instead of the error message and Validates email format gem have defined error messages for 18n keys in its own locale files. We need to set generate_message false to pick our custom error message.
        (ValidatesEmailFormatOf::validate_email_format(value, options.merge(:generate_message => false)) || []).each do |error|
          record.errors.add(attribute, error)
        end
      end
    end
  end
end