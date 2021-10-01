#!/usr/local/bin/ruby

require 'rubygems'
require 'csv'
require File.dirname(__FILE__) + "/auth_smtp_log_entry"

class Array
  def compute_mode
    h = Hash.new
    each do |val|
      h[val] ||= 0
      h[val] += 1
    end
    h.sort_by { |x| x[1] }.reverse
  end
end

module AuthSMTP
  def self.analyze(file_name = "authsmtp.csv")
    entries = CSV.read file_name
    subjects = entries.collect {|row| row[3]} 
    
    group = subjects.compute_mode
    report = ""
    [group.size, 20].min.times do |i|
      report << sprintf("%5d -- %s\n", group[i][1], group[i][0])
    end

    report
  end

  def self.report
    report =  "-" * 80
    report << "\nAuthSMTP Report on #{Time.now}\n"
    report << "-" * 80
    report << "\n\nCount -- Subject\n\n"
    report << self.analyze()
    report
  end
end

puts AuthSMTP::report() if $0 == 'authsmtp_report.rb'
