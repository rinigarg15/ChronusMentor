require 'mail'

mail = Mail.deliver_now do
  to      'apollodev@chronus.com'
  from    'Architecture Team <no-reply@chronus.com>'
  subject 'Tests which run longer time needed to be fixed'

  html_part do
    content_type 'text/html; charset=UTF-8'
    body File.read(ARGV[0])
  end
  add_file filename: 'tests.txt', content: File.read(ARGV[1])
end
