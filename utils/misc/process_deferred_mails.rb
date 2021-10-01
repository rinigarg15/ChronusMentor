# !!!NOTE: Before running this script do this: grep "status=deferred" /var/log/mail.log > deferred_mails
#
# This script parses the deferred mails list and prints the postfix queue id of the deferred email and the "to".  Run this script, see the postfix queue ids and see if the mail is still around in the postfix queue. Also notice the "to" and look up at AuthSMTP console to see if the mail has been sent.
#

f = File.open("deferred_mails")

entries = []

f.each_line do |l|
  l =~  /(.*?\]:)\s+(\w+):\s+to=<(.*)?>/
  entries << "#{$2} - #{$3}"
end

entries.uniq!
puts "Printing #{entries.size} entries:\n"
puts entries.join("\n")
