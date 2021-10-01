#! /usr/local/bin/ruby
#
require 'rubygems'
# top_status log parser. Prints the processes that take up most memory

USAGE = "top_status_log_analyzer.rb <log-files>"
KB = 1024
MB = 1024 * KB


# Parses string to forms '10m' and "1024" and returns the memory in KB. Returns 10*1024 in former case and 1024 in later 
def str_to_mem(str)
  str =~ /(\d+)(m)?/
  mem = $1; mb_unit = $2
  if mb_unit
    mem.to_i * 1024
  else
    return mem.to_i
  end
end

class Array
  def average
    self.inject(0) { |i, v| i += v } / self.count
  end
end

file_names = ARGV
if file_names.nil? or file_names.empty?
  abort USAGE
end

files = file_names.map { |f| File.open(f) }
puts "#{files.size} files open"

processes = Hash.new

files.each do |f|
  # Skip the header
  7.times { f.readline }

  while !f.eof?
    ps = f.readline
    pid, user, pr , ni, virt, res, shr, s, cpu, mem, time, cmd = ps.split(" ")
    next unless cmd && res
    processes[cmd] ||= Array.new
    processes[cmd] << str_to_mem(res)
  end

  f.close
end

rank_map = Hash.new
processes.each do |ps, mem|
  rank_map[mem.average] = [ps, mem.size, mem.min, mem.max]
end

rank_map.keys.sort {|x, y| y <=> x}.each do |k|
  printf "\n%15s (%3d) : #{k} (min: #{rank_map[k][2]}, max: #{rank_map[k][3]})", rank_map[k][0], rank_map[k][1], rank_map
end

puts
