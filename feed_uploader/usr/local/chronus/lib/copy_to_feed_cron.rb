require "rubygems"
require "yaml"

File.open("/etc/cron.d/feed_s3_cron", "w") do |f|
  YAML.load_file("/usr/local/chronus/config/feed_cron.yml")["feed"].each do |cron_task|
    f << cron_task.gsub("RAILS_ENV", "#{ARGV[0]}")
    f << "\n"
  end
  f.close
end