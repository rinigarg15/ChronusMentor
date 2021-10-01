require 'rake'

namespace :db do
  desc "Dump the current database to a MySQL file" 
  task :database_dump do
    load 'config/environment.rb'
    abcs = ActiveRecord::Base.configurations
    case abcs[Rails.env]["adapter"]
    when 'mysql'
      ActiveRecord::Base.establish_connection(abcs[Rails.env])
      File.open("db/#{Rails.env}_data.sql", "w+") do |f|
        if abcs[Rails.env]["password"].blank?
          f << `mysqldump -h #{abcs[Rails.env]["host"]} -u #{abcs[Rails.env]["username"]} #{abcs[Rails.env]["database"]}`
        else
          f << `mysqldump -h #{abcs[Rails.env]["host"]} -u #{abcs[Rails.env]["username"]} -p#{abcs[Rails.env]["password"]} #{abcs[Rails.env]["database"]}`
        end
      end
    when 'sqlite3'
      ActiveRecord::Base.establish_connection(abcs[Rails.env])
      File.open("db/#{Rails.env}_data.sql", "w+") do |f|
        f << `sqlite3  #{abcs[Rails.env]["database"]} .dump`
      end
    else
      raise "Task not supported by '#{abcs[Rails.env]['adapter']}'"
    end
  end
end

task :alumini_student_upload_sample_pictures => :environment do
  class ProfilePicture
    def get_remote_image_data
      io = open(self.image_url)
      def io.original_filename; "image.jpg"; end
      io.original_filename.blank? ? nil : io
    end
  end

  base_dir = File.dirname(__FILE__) + '/../../fake_data/test_pictures'
  mentor_files = Dir.entries(base_dir + "/mentors").reject{|file|  !file.include?(".jpg")}.collect{|file| "#{base_dir}/mentors/#{file}"}
  mentee_files = Dir.entries(base_dir + "/mentees").reject{|file|  !file.include?(".jpg")}.collect{|file| "#{base_dir}/mentees/#{file}"}
  mentor_index = mentee_index = -1

  User.all.each_with_index do |user, index|
    member = user.member
    next if member.profile_picture
    if user.is_mentor?
      file_name = mentor_files[mentor_index += 1]
    else
      file_name = mentee_files[mentee_index += 1]
    end
    member.profile_picture = ProfilePicture.new(:image_url => file_name)
    member.save!
  end
end

task :upload_sample_pictures => :environment do
  class ProfilePicture
    def get_remote_image_data
      io = open(self.image_url)
      def io.original_filename; "image.jpg"; end
      io.original_filename.blank? ? nil : io
    end
  end

  base_dir = File.dirname(__FILE__) + '/../../fake_data/test_pictures'
  men_files = Dir.entries(base_dir + "/men").reject{|file|  !file.include?(".jpg")}.collect{|file| "#{base_dir}/men/#{file}"}
  women_files = Dir.entries(base_dir + "/women").reject{|file|  !file.include?(".jpg")}.collect{|file| "#{base_dir}/women/#{file}"}
  all_files = men_files + women_files
  Member.all.each_with_index do |user, index|
    user.profile_picture = ProfilePicture.new(:image_url => all_files[index % all_files.size ])
    user.save
  end
end
