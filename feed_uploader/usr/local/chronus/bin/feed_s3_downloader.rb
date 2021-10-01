#!/usr/local/bin/ruby

require "optiflag"
require "fileutils"
require "yaml"
require "erb"
require "net/http"
require "uri"
require "aws-sdk-v1"
require_relative  "../lib/cron_monitor_sftp_feed"

include CronMonitor

module CommandLineArgs extend OptiFlagSet
  optional_flag "config_file"
  optional_flag "env"
  and_process!
end

downloader_config_file = ARGV.flags.config_file || "#{Dir.home}/feed_s3.yml"
downloader_env = ARGV.flags.env || "staging"

begin
  yaml_file = File.read(downloader_config_file)
  erb_result = ERB.new(yaml_file).result
  credentials = YAML::load(erb_result)[downloader_env]
  bucket_name = credentials["bucket"]
  export_accounts = credentials["export_accounts"]

  unless bucket_name.nil?
    export_accounts.each do |account|
      s3_downloads_directory = File.join(account, "downloads")
      s3_downloads_archive_directory = File.join(account, "archive_downloads")
      sftp_downloads_directory = File.join("", "home", account, "downloads")
      AWS.config(:region => credentials["s3_bucket_region"], :s3_server_side_encryption => :aes256)
      bucket = AWS::S3.new.buckets[bucket_name]
      objects_withprefix = bucket.objects.with_prefix(s3_downloads_directory)
      objects = objects_withprefix.select{|object| File.basename(object.key).match(/\d+_(.*)/)}
      unless objects.empty?
        ### Delete the existing files in the server.
        unless Dir[File.join(sftp_downloads_directory, "*")].empty?
          files_to_delete = Dir.entries(sftp_downloads_directory).reject{ |file| file[0].eql?(".") }
          files_to_delete.each {|file| File.delete(File.join(sftp_downloads_directory, file))}
        end

        ### Copy the files from S3 into server and archive the s3 files.
        objects.each do |object|
          file_path = File.join(sftp_downloads_directory, File.basename(object.key))
          File.open(file_path, "w", encoding: "UTF-8") {|file| file.write(object.read.force_encoding("UTF-8")) }

          ### If already archived, just remove the object
          archived_objects = bucket.objects.with_prefix(s3_downloads_archive_directory)
          if !archived_objects.select {|archived_object| File.basename(object.key) == File.basename(archived_object.key)}.any?
            object.copy_to(File.join(s3_downloads_archive_directory, File.basename(object.key)))
          end
          object.delete
        end
      end
    end
  end
  CronMonitor::Signal.new(credentials["downloader_cron_monitor_signal"]).trigger
rescue => error
  puts "DOWNLOADER FAILED: #{error}"
end