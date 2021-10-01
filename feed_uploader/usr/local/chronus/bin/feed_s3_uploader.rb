#!/usr/local/bin/ruby

require "rubygems"
require "optiflag"
require "fileutils"
require "aws-sdk-v1"
require "yaml"
require "erb"
require "rake"
require 'net/http'
require 'uri'
require_relative  "../lib/cron_monitor_sftp_feed"

include CronMonitor

module CommandLineArgs extend OptiFlagSet
  optional_flag "config_file"
  optional_flag "env"
  and_process!
end

LAST_MODIFIED_THRESHOLD = (Time.now - 900) # 15*60 = 900 sec
uploader_config_file = ARGV.flags.config_file || "#{Dir.home}/feed_s3.yml"
uploader_env = ARGV.flags.env || "staging"
LOGIN_NAME_TO_ORGANIZATION_SUBDOMAIN = YAML.load_file("/usr/local/chronus/config/sftp_users.yml")

begin
  yaml_file = File.read(uploader_config_file)
  erb_result = ERB.new(yaml_file).result
  credentials = YAML::load(erb_result)[uploader_env]
  bucket_name = credentials["bucket"]
  unless bucket_name.nil?
    LOGIN_NAME_TO_ORGANIZATION_SUBDOMAIN.keys.each do |login|
      source_directory = "/home/#{login}/uploads"
      destination_directory = File.join(login, 'latest')
      file_list = FileList["#{source_directory}/**/*"].select{|x| File.file?(x)}

      unless file_list.empty?
        unless defined?(connection_established) && connection_established
          AWS.config(:region => credentials["s3_bucket_region"], :s3_server_side_encryption => :aes256)
          connection_established = true
        end
        file_list.each do |source_file|
          if File.mtime(source_file) < LAST_MODIFIED_THRESHOLD
            base_name = File.basename(source_file)
            relative_directory = File.dirname(source_file).gsub(source_directory, "")
            destination_file = File.join(File.join(destination_directory, relative_directory), "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}_#{base_name}")
            puts("#{Time.now} Uploading #{source_file} to S3 #{destination_file}")
            begin
              AWS::S3.new.buckets[bucket_name].objects[destination_file].write(:file => File.open(source_file,'r',encoding: "UTF-8"))
              File.delete(source_file)
            rescue AWS::Errors::Base => e
              puts "Error occured #{e.message}"
            end
          else
            puts("#{Time.now} Not Uploading #{source_file} to S3: Last modified date #{File.mtime(source_file)} < 15 min ago")
          end
        end
      end
    end
  end
  CronMonitor::Signal.new(credentials["uploader_cron_monitor_signal"]).trigger
rescue => error
  puts "[#{Time.now}] UPLOAD FAILED: #{error}"
end
