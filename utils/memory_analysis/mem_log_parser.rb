# This script parses the rails log and prints the names of those actions that 
# 1. cause the mongrel mem. usage to increase more than 40MB.
# 2. cause the mongrel mem. usage to increase by 10MB if the process is already
#    consuming > 180MB 
#
# Usage: ruby mem_log_parser.rb [-g] <rails-log-files>
# -g: generate graphs for mongrels too. Default off. Graphs on the directory 
# named <logfile>-graphs. Before using this, enable graphs (see note below).
#
# NOTE: The graphing part is commented out by default. If needed, uncomment 
# the lines around "def write_graph" and the "write_graph" call inside 
# analyze_memory_stats
#

require 'rubygems'
require 'fileutils'

DELTA = (40 * 1024)
THRESHOLD = (180 * 1024)

# Parse the log file and aggregate data in a hash with format
# { 
#   mongrel_pid => [
#     [Controller#action, memory, time of request],
#     ...
#   ],
#   other_mongrel_pid => [...],
#   ...
# }
#
# Keys for the hash: ongrel pids,
# Values of the hash: arrays of array
#
def process_log_file(f)
  processes = Hash.new

  File.open(f) do |f|
    current_action = nil
    current_time = nil
    while !f.eof?
      line = f.readline
      if line =~ /Processing (.+)#(.+) \(for ([\d\.]+) at (.*)\)/
        current_action = "#{$1}##{$2}"
        current_time = $4
      elsif line =~ /Memory usage: (\d+) \| PID: (\d+)/
        processes[$2] ||= Array.new
        processes[$2] << [ current_action,  $1.to_i , current_time]
      end
    end
  end

  return processes
end

# 
# Parse the stats hash and print out requests with memory shootups.
#
def analyze_memory_stats(processes, logfile=nil, graph=false)
  puts "-- Analyzing data for log #{logfile} --"
  processes.each_pair do |p, arr|
    labels = {}
    arr.each_with_index do |a, i|
      next if i == 0
      if arr[i - 1][1] <= THRESHOLD
        if ((delta = arr[i][1] - arr[i - 1][1]) > DELTA)
          printf "%s :: #{delta} (Jump from #{arr[i-1][1]} to #{arr[i][1]} at #{arr[i][2]} for #{p})\n", arr[i][0]
          labels[i] = arr[i][0]
        end
      else
        if ((delta = arr[i][1] - arr[i - 1][1]) > (10 * 1024))
          printf "%s :: #{delta} (Jump from #{arr[i-1][1]} to #{arr[i][1]} at #{arr[i][2]} for #{p})\n", arr[i][0]
          labels[i] = arr[i][0]
        end
      end
    end
    # write_graph(p, arr, labels, logfile) if graph
  end
  puts
end

# require 'gruff'
# def write_graph(mongrel_pid, info_array, labels, logfile)
#   g = Gruff::Line.new
#   g.marker_font_size = 11
#   g.title = "Mongrel #{mongrel_pid}" 
#   g.labels = labels
#   title = "Mongrel at #{mongrel_pid} (from #{info_array.first[2]} to #{info_array.last[2]})"
#   g.data(title, info_array.collect { |x| x[1] })
#
#   dirname = "#{File.basename(logfile)}-graphs"
#   FileUtils.mkdir_p(dirname)
#   Dir.chdir(dirname)
#   g.write("mongrel-#{mongrel_pid}.png")
#   Dir.chdir("..")
# end

args = ARGV.dup
graph_needed = (args.delete("-g") == "-g")
args.each do |fname|
  stats = process_log_file(fname)
  analyze_memory_stats(stats, fname, graph_needed)
end
