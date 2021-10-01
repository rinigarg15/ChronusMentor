namespace :cleanup do
  namespace :location do
    def print_info(counter, locations_to_be_cleaned_size, start_time)
      print("\r[")
      print(['|','/','-','\\',][(counter/5)%4])
      fill = [[(counter / (locations_to_be_cleaned_size / 100.0)).round, 0].max, 100].min
      print("] |#{"█"*(fill)}#{"·"*(100-fill)}|")
      print(" ETA: ~ #{Time.at((Time.now-start_time)/counter.to_f*(locations_to_be_cleaned_size-counter)).utc.strftime("%H:%M:%S")} to complete")
    end

    desc 'Cleanup state, country and city values'
    task entities: :environment do
      success_str = "Success"
      location_not_found_str = "Location not found"
      key = ENV["KEY"]
      limit = (ENV["LIMIT"] || 100).to_i
      locations_to_be_cleaned = Location.where(cleanup_status: Location::CleanupStatus::NOT_DONE, reliable: true).limit(limit)
      locations_to_be_cleaned += Location.where(cleanup_status: Location::CleanupStatus::NOT_DONE, reliable: false).limit(limit - locations_to_be_cleaned.size) if locations_to_be_cleaned.size < limit
      counter = 1
      status_message = nil
      start_time = Time.now
      CSV.open("/tmp/location_data_updates.csv", 'w') do |csv|
        csv << ["Location ID", "Previous City", "Previous State", "Previous Country", "Previous Lat", "Previous Lng", "Previous Reliable", "City", "State", "Country", "Lat", "Lng", "Reliable", "Status"]
        locations_to_be_cleaned.each do |location|
          begin
            status_message = location_not_found_str
            address = location.full_address
            row = [location.id, location.city, location.state, location.country, location.lat, location.lng, location.reliable.to_s, nil, nil, nil, nil, nil, nil]
            geoloc = if key
              Geokit::Geocoders::GoogleGeocoder.send(:parse_json, MultiJson.load(URI.parse("https://maps.googleapis.com/maps/api/geocode/json?sensor=false&address=#{Geokit::Inflector::url_escape(address)}&key=#{key}").read))
            else
              Location.geocode(address) # this is not the primary purpose
            end
            row[7] = geoloc.city || location.city
            row[8] = geoloc.state_name || location.state
            row[9] = CountryCodes.find_by_a2(geoloc.country_code)[:name] || location.country
            row[10] = geoloc.lat || location.lat
            row[11] = geoloc.lng || location.lng
            row[12] = geoloc.country_code.present?
            location.update_attributes!({
              city: row[7],
              state: row[8],
              country: row[9],
              lat: row[10],
              lng: row[11],
              reliable: row[12],
              cleanup_status: (geoloc.country_code.nil? ? Location::CleanupStatus::TRIED_BUT_FAILED : Location::CleanupStatus::DONE)
            })
            status_message = success_str if location.cleanup_status == Location::CleanupStatus::DONE
            print_info(counter, locations_to_be_cleaned.size, start_time) if key
          rescue Geokit::TooManyQueriesError => error
            status_message = error.message
            sleep(2)
          rescue Geokit::Geocoders::GeocodeError, StandardError => error
            status_message = error.message
            location.update_attributes({cleanup_status: Location::CleanupStatus::TRIED_BUT_FAILED})
          ensure
            counter += 1
            puts status_message if key && status_message != success_str && status_message != location_not_found_str
            row << status_message
            csv << row
            csv.flush
          end
          sleep(0.04) # rate limiting to maximum of 25 / sec
        end
      end
      puts "\nDONE" if key
    end

    # CSV format ["full_address, city, state, country, lat, lng, reliable, cleanup_status"]
    # USAGE: rake cleanup:location:reimport_locations FILE_PATH="location.csv"
    desc "Update locations from CSV"
    task reimport_locations: :environment do
      file_path = ENV["FILE_PATH"]
      location_file = CSV.read(file_path, headers: true)
      file_validation(location_file)
      location_file.each do |location_row|
        row = location_row.to_h
        full_address = row["full_address"]
        locations_to_update = Location.where(full_address: full_address)
        next unless locations_to_update.present?
        attributes = row.slice("city", "state", "country", "lat", "lng", "reliable", "cleanup_status")
        attributes["reliable"] = attributes["reliable"].to_s.to_boolean
        locations_to_update.update_all(attributes.merge(skip_delta_indexing: true))
        puts "#{locations_to_update.size} locations updated for #{full_address}"
      end
    end

    # USAGE: rake cleanup:location:remove_duplicates"
    desc "Cleanup Duplicate Locations"
    task remove_duplicates: :environment do
      duplicate_address_locations = Location.all.order("reliable DESC")
                                      .group_by { |location| location.full_address_db }
                                      .select { |_full_address, locations| locations.size > 1 }
      puts "Starting cleaning up of #{duplicate_address_locations.size} duplicate locations..."
      counter = 0
      to_delete = []
      duplicate_address_locations.each do |_full_address, locations|
        location_to_retain = locations.first
        location_id_to_retain = location_to_retain.id
        location_ids_to_delete = (locations.map(&:id) - [location_id_to_retain])
        selector = { location_id: location_ids_to_delete }

        LocationLookup.where(selector).update_all(location_id: location_id_to_retain)
        profile_answers_to_update = ProfileAnswer.where(selector)
        profile_answers_to_update.update_all(location_id: location_id_to_retain, skip_delta_indexing: true)

        location_to_retain.update_columns(profile_answers_count: location_to_retain.profile_answers_count + profile_answers_to_update.size, skip_delta_indexing: true)
        to_delete << location_ids_to_delete

        counter += 1
        print "." if (counter % 100) == 0
      end
      puts "Done with updating location_id's in associated models"
      Location.where(id: to_delete.flatten).delete_all if to_delete.present?
      handle_delta_profile_answers
      validate_answer_locations
      ElasticsearchReindexing.indexing_flipping_deleting([Location.name])
    end
  end

  namespace :user_content do
    desc "Cleanup activity feed history in a program prior to a specified date"
    task activity_feed: :environment do
      organization = Program::Domain.get_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])
      raise "Organization not found!" unless organization.present?
      program = organization.programs.find_by(root: ENV["ROOT"])
      raise "Program not found!" unless program.present?

      date_str = ENV["DATE"]
      timezone = ENV["TIMEZONE"]
      raise "Date/Timezone not specified!" unless (date_str.present? && timezone.present?)
      raise "Time zone is invalid!" unless timezone.present? && TimezoneConstants::VALID_TIMEZONE_IDENTIFIERS.include?(timezone)

      Time.zone = ENV["TIMEZONE"]
      time = DateTime.strptime(ENV["DATE"], '%Y-%m-%d').change(offset: Time.zone.now.strftime("%z"))
      recent_activities = program.recent_activities.includes(:program_activities, :connection_activities).where("recent_activities.created_at < ?", time)
      puts "Number of RAs created before #{time} is #{recent_activities.size}"
      recent_activities.destroy_all
    end
  end

  namespace :mailer_template do
    desc  'Cleanup mailer templates for mails which are removed from app'
    task cleanup_mailer_templates: :environment do
      mailer_class_list = [InviteNotification, UserWithSetOfRolesAddedNotificationToReviewProfile, UserWithSetOfRolesAddedNotification]
      uids_to_delete = mailer_class_list.map{|m| m.mailer_attributes[:uid]}
      Mailer::Template.where("campaign_message_id IS NULL AND uid NOT IN (?)", ChronusActionMailer::Base.get_descendants.collect{|e| e.mailer_attributes[:uid]} - uids_to_delete).destroy_all
    end

    desc 'Switch back to new default content for admin message mail'
    task handle_admin_message_mailer_template: :environment do
      Mailer::Template.reset_content_for(Mailer::Template.where(uid: AdminMessageNotification.mailer_attributes[:uid])) 
    end

    desc 'Handle mailer templates for merged welcome mails which are removed from app'
    task handle_merged_welcome_mails: :environment do
      removed_mailer_classes_uids = ["tryi2ns1", "94q5pefi"]
      mailer_classes_uids = ["jvak8hbo", "pt0mnnpl", "24vvapdy", "tryi2ns1"] # first three will replace last one

      Program.includes(:mailer_templates).each do |program|
        mts = program.mailer_templates.where(uid: mailer_classes_uids)
        mts.update_all(enabled: true) if mts.enabled.size > 0 || mts.size != mailer_classes_uids.size
      end

      handle_mailer_templates_for_merged_mails("94q5pefi", "jwfp646n") # replacing admin_imported_notification with admin_added_directly_notification

      Mailer::Template.where(:uid => removed_mailer_classes_uids).destroy_all
    end

    desc 'Handle mailer templates for merged role mails which are removed from app'
    task handle_merged_role_mails: :environment do
      removed_mailer_classes_uids = ["284oda1i", "79mbkppw"]

      handle_mailer_templates_for_merged_mails("284oda1i", "z6g2m5of")
      handle_mailer_templates_for_merged_mails("79mbkppw", "60iqcv2c")

      Mailer::Template.where(:uid => removed_mailer_classes_uids).destroy_all
    end

    desc 'Handle mailer templates for merged add user mails which are removed from app'
    task handle_merged_add_user_mails: :environment do
      removed_mailer_classes_uids = ["iwo8oh7s", "pkgxew7r", "gcfdjq6q"]

      handle_mailer_templates_for_merged_mails("iwo8oh7s", "jvak8hbo")
      handle_mailer_templates_for_merged_mails("pkgxew7r", "pt0mnnpl")
      handle_mailer_templates_for_merged_mails("gcfdjq6q", "24vvapdy")

      Mailer::Template.where(:uid => removed_mailer_classes_uids).destroy_all
    end
  end
end

private

def handle_mailer_templates_for_merged_mails(removed_mailer_class_uid, used_mailer_class_uid)
  Mailer::Template.where(:uid => used_mailer_class_uid).includes(:program).each do |mt|
    rmt = Mailer::Template.where(:uid => removed_mailer_class_uid, :program_id => mt.program)
    mt.update_attribute(:enabled, true) unless !mt.enabled && rmt.present? && !rmt.first.enabled
  end
end

def file_validation(location_file)
  expected_headers = ["full_address", "city", "state", "country", "lat", "lng", "reliable", "cleanup_status"]
  missing_headers = expected_headers - location_file.headers
  raise "Missing headers: #{missing_headers}" if missing_headers.present?
  raise "Reliable field should be Either True/False" if (location_file["reliable"].uniq.map(&:downcase) - ["true", "false"]).present?
end


def handle_delta_profile_answers
  delta_profile_answers = ActiveRecord::Base.connection.exec_query("select profile_answer_id, location_id, full_address from temp_profile_answer_locations").rows
  recalculate_locations(delta_profile_answers)
end


def recalculate_locations(delta_profile_answers)
  delta_profile_answers.each do |row|
    profile_answer_id = row[0].to_i
    location_id = row[1].to_i
    full_address = row[2]

    unless Location.find_by(id: location_id).present?
      location = Location.find_or_create_by_full_address(full_address)
      profile_answer = ProfileAnswer.find_by(id: profile_answer_id)
      if profile_answer.present?
        profile_answer.update_columns(location_id: location.id, skip_delta_indexing: true)
        puts "Updated location for Profile Answer #{profile_answer_id}"
      end
    end
  end
end

def validate_answer_locations
  invalid_profile_answers = ProfileAnswer.where.not(location_id: nil)
    .joins("LEFT JOIN locations ON profile_answers.location_id = locations.id")
    .where(locations: { id: nil })
  Common::RakeModule::Utils.print_error_messages("There are profile answers with invalid locations. Profile answer ID: #{invalid_profile_answers.pluck(:id).join(", ")}") if invalid_profile_answers.present?
end