#! /usr/local/bin/ruby
# This is currently being used by Srini on his machine. After
# the beta stage, it will be moved to one of the main monitoring
# machines.

require 'rubygems'
require 'fileutils'
require 'pony'
require 'google_spreadsheet'

Files = ["mail.log", "mail.log.0"]
TmpDir = "/tmp/mail_watch"
MonitorSpreadsheetKey = '0AiMZX83Kmj7VdFNDS3EzZVhRM0tpbjJmV25uMmdNX3c'
ThresholdRange = (5..800)

def send_alert(date, number)
  Pony.mail(
      :subject => "[Groups] Email Thershold - #{date}",
      :body => "Number of emails sent on #{date} #{Time.now.year}: #{number}. (Allowed range: #{ThresholdRange}). Check!!",
      :to => 'monitor@chronus.com',
      :via => :smtp,
      :smtp => {
        :host => 'smtp.gmail.com',
        :port => 587,
        :user => 'chronusmentor@chronus.com',
        :password => 'Varam2008!',
        :auth => :plain,
        :domain => "mail.chronus.com",
        :tls => true
      }
    )
  puts "Successfully sent email alert"
end


def update_google_spreadsheet(date, mail_count)
  session = GoogleSpreadsheet.login("monitor@chronus.com", "Chr0nusM0n1t0r")
  ss = session.spreadsheet_by_key(MonitorSpreadsheetKey)
  ws = ss.worksheets.select {|x| x.title == "Mails"}.first
  last_row = ws.num_rows
  ws[last_row + 1, 1] = date
  ws[last_row + 1, 2] = mail_count
  ws.save
  puts "Successfully updated spreadsheet"
end

FileUtils.mkdir_p(TmpDir)
Dir.chdir(TmpDir) do
  Files.each { |f| system("rm #{f}"); system("scp -i /home/mrudhu/ec2_keys/chronus-ec2-keypair root@mentor.chronus.com:/mnt/log/#{f} .") }
  yesterday = Time.now - (60*60*24)
  date = yesterday.day; month = yesterday.strftime("%b")
  date_str = sprintf("%s %2s", month, date)
  no_mails = `grep "#{date_str}" mail.log mail.log.0 | grep 'status=sent' | wc -l`.to_i
  puts "#{date_str} :: #{no_mails} mails sent"
  update_google_spreadsheet(date_str, no_mails)
  send_alert(date_str, no_mails) unless ThresholdRange.include?(no_mails)
end
