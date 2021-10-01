#!/usr/local/bin/ruby

require 'rubygems'
require 'mechanize'
require 'hpricot'
require File.dirname(__FILE__) + "/auth_smtp_log_entry"
require File.dirname(__FILE__) + "/authsmtp_report"

USAGE = "USAGE: authsmtp_dump.rb [<no. of pages to fetch>]"
Months = %w(None Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
AuthSmtpBasePage = 'http://control.authsmtp.com/mail-history.php'

class String
  def full_squeeze
    self.strip.gsub("\n", '').gsub(/\s+/, ' ')
  end
end

def get_value_for_key(node, key)
  node.inner_text.full_squeeze.split("#{key} :").last
end

def process_node(node)
  row = node.inner_html.gsub('&nbsp;', '')
  date_time = row.split(" | ").first.split(" : ").last

  from = node.parent.next_node.next_node
  to = from.next_node.next_node
  subject = to.next_node.next_node

  from_text = get_value_for_key(from, "From")
  to_text = get_value_for_key(to, "To")
  subject_text = get_value_for_key(subject, "Subject")
  
  AuthSMTPLogEntry.new(date_time, from_text, to_text, subject_text)
end


def process_page(url)
  page = $agent.get url
	doc = Hpricot.parse(page.body)

	# Obtain the header info (date, time, size, post, id, msg-id)
	header_nodes = (doc/"td[@bgcolor = '#eeeeee']").select {|x| x.inner_text =~ /Date \/ Time/ }
	header_nodes.each do |node|
    obj = process_node(node)
    log obj
    $csv_file << "#{obj.to_csv}"
  end
end

def setup()
  $log_level = ARGV.include?("-v") ? :verbose : :normal
  abort(USAGE) if ARGV.include?("-h")
  $csv_file = File.new("authsmtp.csv", "a+")  
  arg = (ARGV.last || 0).to_i
  $page_count = (arg == 0 ? 10 : arg)
  $agent = WWW::Mechanize.new
  
  log "logging in.."
  login = $agent.get 'http://control.authsmtp.com/signin.php'
  form = login.forms.first
  form.user_id = 'ac35265'
  form.password = 'znqw4tdqj'
  
  login_success = $agent.submit(form,form.buttons.first)
  log "logged in successfully"
end

def run()
  $page_count.times { |i| 
    log "Processing page #{i}", :force
    process_page("#{AuthSmtpBasePage}?page=#{i}&err=0")
  }
end

def finish()
  $csv_file.close
end

def log(msg, mode=:normal)
  puts msg if ($log_level == :verbose || mode == :force)
end

abort(USAGE) if ARGV[0] == '-h'
setup()
run()
finish()
puts AuthSMTP::report()
