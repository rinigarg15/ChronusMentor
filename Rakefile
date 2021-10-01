#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

ChronusMentorBase::Application.load_tasks

import 'lib/matching/tasks/matching.rake'
require 'find'
require "rake/testtask.rb"
begin; require 'metric_fu'; rescue LoadError; end

task cleandb: :environment do
  Rake::Task["db:drop"].invoke
  Rake::Task["db:create"].invoke
  Rake::Task["db:structure:load"].invoke
  Rake::Task["db:migrate"].invoke
  Rake::Task["db:seed"].invoke
end

namespace :test do
  task :lib do
    # Find list of tests to run inside the lib directory.
    files = []
    next unless Dir.exists?(Rails.root.to_s + '/test/lib')
    Find.find(Rails.root.to_s + '/test/lib') do |file_name|
      # skip non test files.
      next unless file_name =~ /_test\.rb$/
      files << file_name
    end

    # Construct ruby command for running all tests.
    unless files.empty?
      cmd = files.collect{|file_name| "ruby #{file_name}"}.join(';')
      puts cmd
      system cmd
    end
  end
  Rake::TestTask.new(:engines) do |t|
    engine = ENV['ENGINE'].blank? ? '*' : ENV['ENGINE']
    t.libs += Dir.glob("vendor/engines/#{engine}/lib")
    t.libs += Dir.glob("vendor/engines/#{engine}/test")
    t.pattern = "vendor/engines/#{engine}/test/**/*_test.rb"
    t.verbose = false
  end
end

desc "removes duplicate locations from database"
task :remove_duplicate_locations => :environment do
  ActiveRecord::Base.connection.execute "SET AUTOCOMMIT=0;"
  ActiveRecord::Base.connection.execute "START TRANSACTION;"
  begin
    # All locations that have users.
    used_locations = Location.all
    duplicates = []
    unique_locations_by_address = {}

    used_locations.each do |loc|
      address = loc.full_address.gsub(/,\s+/, ",")
      original_loc = unique_locations_by_address[address]

      # Was there a location before this with the same adddress?
      if original_loc
        # Duplicate!
        puts "================ Duplicate location #{loc.full_address}."
        duplicates << loc
      else
        # This is the first! Register it and move forward.
        unique_locations_by_address[address] = loc
      end

      # Is this a duplicate location and is used by users? If so, fix them to
      # point to the original location.
      if original_loc && loc.profile_answers_count > 0
        puts "Updating locations for following users..."

        # Update all related users' locations to point to the original.
        loc.profile_answers.each do |loc_answer|
          puts loc_answer.user.member.name
          loc_answer.location = original_loc
          loc_answer.save!
        end
      end
    end

    # Destroy duplicate locations
    duplicates.each do |loc|
      loc.destroy
    end
  end

  # Commit transaction.
  ActiveRecord::Base.connection.execute "SET AUTOCOMMIT=1;"
end
