# = Geo Location populator
#
# Parses location information from raw data files and populates the locations
# table.
#
# Author    :: Vikram
# Copyright ::  Copyright (c) 2009 Chronus Corporation
#

# Geo data file parsing library
require File.join(Rails.root, "lib", "geo_info_parser")

# The data files to download from (and save to locally) Amazon buckets.
GEO_LOCATION_FILES = ['cities.txt', 'states.txt', 'countries.txt']

namespace :geo do
  # Loads geo information from flat files for each country (currently India and
  # US) and creates a SQL script containing statements for populating location
  # records
  #
  desc "Loads geo information from flat files uploads them to locations table in the database"
  task(:populate => :environment) do
    # Construct GeoDataParser::Records from data files.
    geo_tree = GeoDataParser::Processor.process(GEO_LOCATION_FILES[0],
                                                GEO_LOCATION_FILES[1],
                                                GEO_LOCATION_FILES[2])

    countries = geo_tree.children
    states    = countries.collect{|country| country.children}.flatten
    cities    = states.collect{|state| state.children}.flatten

    print "Creating location records. This may take a few minutes..."

    # Switch off autocommit. We will commit the whole transaction at the end.
    ActiveRecord::Base.transaction do
      begin
        [countries, states, cities].flatten.each do |location|
          if location.record.latitude && location.record.longitude
            create_record(location.record)
          end
        end
      end
    end

    puts "done"
  end

  # Creates a location record for the given location.
  #
  # ==== Params
  # location  ::  <code>GeoDataParser::Record</code> record representing the
  #               location node to be saved.
  def create_record(record)
    lat = record.latitude || "NULL"
    lon = record.longitude || "NULL"

    # Construct sql for creating db record for the current geo record.
    # The last value 0 is for the users count
    sql_cmd =
      <<-SQL
      INSERT INTO locations (city,state,country,lat,lng,full_address,reliable,profile_answers_count) VALUES(?,?,?,#{lat},#{lon},?,?,0)
      SQL

    country_name = CountryCodes.find_by_a2(record.country_code)[:name]
    create_geo_location_sql = Location.sanitize_the_sql(
      [ sql_cmd,
        record.name,
        record.state,
        country_name,
        GeoDataParser::Record.toponym_string(
          record.name,
          country_name,
          record.state),
        true
      ])

    # Execute SQL to create record
    begin
      ActiveRecord::Base.connection.execute create_geo_location_sql
    rescue
      puts "ERROR: #{$!}"
    end
    puts record.name
  end
end
