# == Schema Information
#
# Table name: received_mails
#
#  id            :integer          not null, primary key
#  message_id    :string(255)
#  stripped_text :text(16777215)
#  from_email    :string(255)
#  to_email      :string(255)
#  data          :text(16777215)
#  response      :string(255)
#  sender_match  :boolean
#

class ReceivedMail < ActiveRecord::Base
  module Response
    def self.invalid_signature
      'feature.email.received_mail.invalid_signature'.translate
    end

    def self.invalid_receiver
      'feature.email.received_mail.invalid_receiver'.translate
    end

    def self.no_content
      'feature.email.received_mail.no_content'.translate
    end

    def self.invalid_object_type
      'feature.email.received_mail.invalid_object_type'.translate
    end

    def self.invalid_api_token
      'feature.email.received_mail.invalid_api_token'.translate
    end

    def self.original_message_deleted
      'feature.email.received_mail.original_message_deleted'.translate
    end

    def self.successfully_accepted
      'feature.email.received_mail.successfully_accepted'.translate
    end
  end
end
