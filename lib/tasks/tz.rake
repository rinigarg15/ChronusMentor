# Usage: 
# rake tz:handle_tzinfo_update
# rake tz:update_zones_in_activerecord_objects
# JIRA Ticket: AP-14440, AP-14792

namespace :tz do
  desc 'Updates relevant files whenever tzinfo-data gem is updated'
  # Should be run in LOCAL MACHINE to update the related files.
  task :handle_tzinfo_update => :environment do
    fail "Run this rake task in local machine." unless Rails.env.development?
    initialize_file_names
    update_obsolete_timezones_file
    update_timezone_locales
    update_zones_in_activerecord_objects if @updation_required_in_activerecord_objects
  end

  # Should be run in ALL ENVIRONMENTS to make sure models don't have obsolete timezones.
  task :update_zones_in_activerecord_objects => :environment do
    @obsolete_timezone_hash = load_hash_from_file(Dir.glob("#{Rails.root}/app/files/obsolete_timezones*.yml").first)
    update_zones_in_activerecord_objects
  end

  private

  def initialize_file_names
    @temp_file = File.join(Rails.root.to_s, "/tmp/backward_timezone.txt")
    @tz_yml_file_folder = File.join(Rails.root.to_s,"app", "files")
    @tz_yml_file_base_name = "obsolete_timezones"
    @tz_yml_file_full_name = prefix_folder_path("#{@tz_yml_file_base_name}.yml")
    @old_tz_yml_file_name = Dir.glob(prefix_folder_path("#{@tz_yml_file_base_name}*.yml")).first
    @tz_locales_file = "#{Rails.root}/config/locales/timezones.en.yml"
    @obsolete_timezone_hash = {}
  end

  def update_obsolete_timezones_file
    fetch_timezones_data_and_write_to_tmp_file
    generate_obsolete_timezones_hash
    fail "Obsolete timezone hash is empty. Quitting." if @obsolete_timezone_hash.blank?
    safely_write_hash_to_yml_file(@tz_yml_file_full_name, @obsolete_timezone_hash, { existing_file: @old_tz_yml_file_name, file_search_expression: "#{@tz_yml_file_base_name}*.yml", md5_hash_required: true })
    old_hash = File.basename(@old_tz_yml_file_name,".yml").split("_").last
    @updation_required_in_activerecord_objects = (old_hash != @md5_hash)
  end

  def update_timezone_locales
    tz_locales_hash = load_hash_from_file(@tz_locales_file)
    region_hash, zone_hash = tz_locales_hash["en"]["timezone"].values
    valid_timezone_identifiers.each do |tz_identifier|
      region, zone = get_area_location(tz_identifier)
      region_hash[region] ||= region.gsub("_"," ")
      zone_hash[zone] ||= zone.gsub("_"," ")
    end
    tz_locales_hash["en"]["timezone"] = {"region" => region_hash, "zone" => zone_hash}
    safely_write_hash_to_yml_file(@tz_locales_file, tz_locales_hash, { existing_file: @tz_locales_file, file_search_expression: File.basename(@tz_locales_file) })
  end

  def update_zones_in_activerecord_objects
    klasses = [Member, ProgramEvent]
    klasses.each do |klass|
      time_zones_present_in_db = klass.where(time_zone: @obsolete_timezone_hash.keys).pluck("DISTINCT(time_zone)")
      time_zones_present_in_db.each do |time_zone|
        new_time_zone = @obsolete_timezone_hash[time_zone]
        klass.where(time_zone: time_zone).update_all(time_zone: new_time_zone)
      end
      puts "#{klass} timezones updated.".green
    end
    puts "Run 'rake tz:update_zones_in_activerecord_objects' in ALL ENVIRONMENTS.".yellow
  end

  def safely_write_hash_to_yml_file(new_file, data_hash, options = {})
    existing_file_folder = File.dirname(options[:existing_file])
    backup_file = prefix_folder_path("backup_file.yml", existing_file_folder)
    File.rename(options[:existing_file], backup_file)
    begin
      File.open(new_file, "w"){|f| f.write(data_hash.to_yaml)}
      add_md5_hash_to_file_name(new_file) if options[:md5_hash_required]
      FileUtils.rm(backup_file)
      puts "Write to #{new_file} success.".green
    rescue => ex
      Dir.glob(prefix_folder_path(options[:file_search_expression], existing_file_folder)).each { |file| FileUtils.rm(file) } # removing erroraneous file
      File.rename(backup_file, options[:existing_file])
      puts ex.message.red
      puts ex.backtrace.join("\n").red
      puts "\nReverting #{options[:existing_file]} file back".red
    end
  end

  def prefix_folder_path(file_name, folder = @tz_yml_file_folder)
    File.join(folder, file_name)
  end

  def load_hash_from_file(file_name)
    YAML.load(File.open(file_name, 'r'))
  end

  def fetch_timezones_data_and_write_to_tmp_file
    puts "Fetching obsolete timezones list from https://raw.githubusercontent.com/eggert/tz/master/backward".green
    File.open(@temp_file, "w+") { |file| file << open("https://raw.githubusercontent.com/eggert/tz/master/backward").read }
  end

  def generate_obsolete_timezones_hash
    File.open(@temp_file, "rb") do |file|
      File.foreach(file) do |line|
        line.chomp!
        next if line.empty? || (line.start_with? "#")
        new_name, old_name = line.to_s.gsub(/\t+/, " ").split(" ").drop(1)
        @obsolete_timezone_hash[old_name] = new_name
      end
    end
  end

  def add_md5_hash_to_file_name(full_name, folder = @tz_yml_file_folder)
    base_name = File.basename(full_name, ".yml")
    @md5_hash = `cat #{full_name} | md5sum`.split[0]
    full_name_with_md5_hash = prefix_folder_path("#{base_name}_#{@md5_hash}.yml", folder)
    File.rename(full_name, full_name_with_md5_hash)
  end

  def get_area_location(tz_identifier)
    timezone_area, timezone_location = tz_identifier.split("/", 2)
    if timezone_location.blank?
      timezone_location = timezone_area
      timezone_area = "Others"
    end
    [timezone_area, timezone_location]
  end

  def valid_timezone_identifiers
    TZInfo::Timezone.all_identifiers - @obsolete_timezone_hash.keys
  end
end