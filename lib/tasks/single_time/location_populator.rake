require "activerecord-import"
#usage rake single_time:location_populator:get_location_and_export LOCATION_FILE_NAME=<location_file_name>
#Example rake single_time:location_populator:get_location_and_export LOCATION_FILE_NAME='locations.csv'
#usage rake single_time:location_populator:import_locations LOCATION_FILE_NAME=<location_file_name> LOOKUP_FILE_NAME<lookup_file_name>
#Example rake single_time:location_populator:import_locations LOCATION_FILE_NAME='locations.csv' LOOKUP_FILE_NAME='lookups.csv'

namespace :single_time do
  namespace :location_populator do
    desc "Get location from google and export to csv"
    task get_location_and_export: :environment do
      full_addresses_to_export = SmarterCSV.process(ENV["LOCATION_FILE_NAME"]).map{ |location_hash| [location_hash[:locality], location_hash[:state], location_hash[:country]].join(", ") }.uniq
      lookups_to_export = {}
      locations_to_export = []
      errors = []

      full_addresses_to_export.each do |full_address|
        begin
          google_res = Location.geocode(full_address)
          locations_to_export << [google_res.city, google_res.state_name, CountryCodes.find_by_a2(google_res.country_code)[:name], google_res.full_address, google_res.lat, google_res.lng]
          lookups_to_export[full_address] = google_res.full_address if google_res.full_address != full_address
        rescue Geokit::Geocoders::TooManyQueriesError => error
          errors << [full_address, error.message]
          sleep(2)
        rescue Geokit::Geocoders::GeocodeError, StandardError => error
          errors << [full_address, error.message]
        end
        sleep(0.04)
      end

      Common::RakeModule::Utils.export_to_csv("#{Rails.root}/tmp/locations_#{Time.now.to_i}.csv", ["city", "state", "country", "full_address", "lat", "lng"], locations_to_export)
      Common::RakeModule::Utils.export_to_csv("#{Rails.root}/tmp/lookups_#{Time.now.to_i}.csv", ["lookup_address", "location_address"], lookups_to_export)
      Common::RakeModule::Utils.export_to_csv("#{Rails.root}/tmp/errors_#{Time.now.to_i}.csv", ["full_address", "error"], errors)
    end

    desc "Import locations from csv"
    task import_locations: :environment do
      location_rows = SmarterCSV.process(ENV["LOCATION_FILE_NAME"])
      lookup_rows = SmarterCSV.process(ENV["LOOKUP_FILE_NAME"])

      full_addresses_to_import = location_rows.collect{ |location| location[:full_address] }
      existing_locations_hash = Location.connection.select_all(Location.where(reliable: true, full_address: full_addresses_to_import).select("full_address, id")).rows.to_h
      existing_location_lookups_hash = LocationLookup.connection.select_all(LocationLookup.where(address_text: full_addresses_to_import).joins(:location).where(locations: { reliable: true }).select("address_text, location_lookups.id")).rows.to_h

      locations_to_import = []
      location_rows.each do |location_hash|
        full_address = location_hash[:full_address]
        next if existing_locations_hash[full_address].present? || existing_location_lookups_hash[full_address].present?
        locations_to_import << Location.new(location_hash.merge(reliable: true, cleanup_status: Location::CleanupStatus::DONE))
      end
      puts "Importing #{locations_to_import.size} locations"
      result = Location.import(locations_to_import)
      puts result

      lookups_to_import = []
      location_addresses_to_lookup = []
      lookup_rows.each do |lookup_hash|
        lookups_to_import << lookup_hash[:lookup_address]
        location_addresses_to_lookup << lookup_hash[:location_address]
      end

      existing_location_lookups_hash = LocationLookup.connection.select_all(LocationLookup.where(address_text: lookups_to_import).joins(:location).where(locations: { reliable: true }).select("address_text, location_lookups.id")).rows.to_h
      locations_to_lookup = Location.connection.select_all(Location.where(full_address: location_addresses_to_lookup, reliable: true).select("full_address, id")).rows.to_h
      location_lookups_to_lookup = LocationLookup.connection.select_all(LocationLookup.where(address_text: location_addresses_to_lookup).joins(:location).where("locations.reliable = true").select("address_text, location_id")).rows.to_h

      location_lookups_to_import = []
      lookup_rows.each do |lookup_hash|
        original_address = lookup_hash[:lookup_address]
        location_full_address = lookup_hash[:location_address]
        next if existing_location_lookups_hash[original_address].present?
        location_id = locations_to_lookup[location_full_address] || location_lookups_to_lookup[location_full_address]
        next unless location_id.present?
        location_lookups_to_import << LocationLookup.new(address_text: original_address, location_id: location_id)
      end
      puts "Importing #{location_lookups_to_import.size} lookups"
      result = LocationLookup.import(location_lookups_to_import)
      puts result
    end
  end
end