require 'rubygems'
require 'csv'

class AuthSMTPLogEntry
  attr_accessor :date_time, :subject, :from, :to
  
  def initialize(a_date, a_from, a_to, a_subject)
    self.date_time = a_date
    self.from = a_from
    self.to = a_to
    self.subject = a_subject
  end

  def to_csv
    [date_time, from, to, subject].to_csv
  end

  def to_s
    "Sent: #{date_time}, From: #{from}, To: #{to}, Subject: #{subject}"
  end

  def inspect
    self.to_s
  end
end

