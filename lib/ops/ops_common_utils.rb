require 'colorize'

def error_log(str)
  puts str.red
end


def success_log(str)
  puts str.green
end

def info_log(str)
  puts str.yellow
end
