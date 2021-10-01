#!/usr/bin/env ruby

# This is a simple script to send mail via an alternate server when there are
# errors with the normal queueing mail sender
# The subject is the first command-line arg and the body is received on stdin

#################################

from_address             = "chronusmentor@chronus.com"
to_address               = "monitor@chronus.com"
smtp_server              = "smtp.gmail.com"
smtp_port                = 587
smtp_mail_from_domain    = "chronus.com"
smtp_account_name        = "chronusmentor@chronus.com"
smtp_password            = "Varam2008!"
smtp_authentication_type = :plain
debug                    = false

#################################

subject = ARGV[0]
body = $stdin.read

require 'rubygems'
require 'net/smtp'

exit if body.nil? || body == ""

msgstr = <<END_OF_MESSAGE
Subject: #{subject}

#{body}
END_OF_MESSAGE

smtp = Net::SMTP.new(smtp_server, smtp_port)
smtp.enable_starttls
smtp.set_debug_output $stderr if debug
smtp.start(smtp_mail_from_domain, smtp_account_name, smtp_password, smtp_authentication_type) do |s|
  s.send_message msgstr, from_address, to_address
end