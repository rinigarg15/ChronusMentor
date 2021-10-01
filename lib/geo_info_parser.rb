# = Geographic information parser
#
# Provides the data structure and logic for parsing location information from
# raw data files and constructing the data records from that.
#
# Author    ::  Vikram Venkatesan  (mailto:vikram@chronus.com)
# Copyright ::  Copyright (c) 2009 Chronus Corporation
#

module GeoDataParser
  # Represents a Geo location record
  class Record
    attr_accessor :name, :latitude, :longitude, :feature_class, :feature_code,
      :country_code, :country_code_2, :country_name, :admin1_code, :admin2_code,
      :admin3_code, :admin4_code, :state

    # Constructs a Record object from the given values.
    def initialize(values)
      self.name           = values[:name]
      self.latitude       = values[:latitude]
      self.longitude      = values[:longitude]
      self.feature_class  = values[:feature_class]
      self.feature_code   = values[:feature_code]
      self.country_code   = values[:country_code]
      self.country_code_2 = values[:country_code_2]
      self.admin1_code    = values[:admin1_code]
      self.admin2_code    = values[:admin2_code]
      self.admin3_code    = values[:admin3_code]
      self.admin4_code    = values[:admin4_code]
    end

    # Returns a toponym string of the form 'Chennai, TamilNadu, India' for the
    # given record. The general format is
    # 
    # place, state, country
    # 
    def self.toponym_string(name, country_name, state)
      toponym = %Q[#{name}]
      toponym += %Q[,#{state}] if state
      toponym += %Q[,#{country_name}] if country_name
      return toponym
    end
  end

  # A Tree like data structure for representing location records hierarchy.
  #
  class Tree
    # The root location record node of the current tree level
    attr_accessor :record

    # An array of children of this tree node
    attr_accessor :children

    # Parent record pointer.
    attr_accessor :parent

    # Creates a new Tree with the given location record and children.
    def initialize(record = nil, children = nil, parent = nil)
      self.record = record
      self.children = children
      self.parent = parent
    end
  end

  # Utility methods for parsing geographic information data files and converting
  # them to GeoDataParser::Record's.
  #
  class Processor
    #
    # Processes the given data file and and returns an array of
    # GeoDataParser::Tree of locations.
    #
    def self.process(data_file, states_file, countries_file)
      fields_and_cities = parse(data_file)                    # Parse cities.
      fields            = fields_and_cities[0]
      cities            = fields_and_cities[1]
      state_infos       = parse_states(states_file)           # Parse states
      countries         = parse_country_codes(countries_file) # Parse countries

      return construct_geo_tree(fields, cities, state_infos, countries)
    end

    # Constructs a tree of location nodes with the given data.
    #
    # ==== Params
    # fields      - list of field names required for constructing Record objects
    # cities      - city records
    # state_infos - Map from state id to state info hash
    # countries   - Map from country codes to names
    #
    def self.construct_geo_tree(fields, cities, state_infos, countries)
      # The fields in parsed data that are required for constructing Record
      # objects
      filter_field_names = [:name, :latitude, :longitude, :feature_class,
        :feature_code, :country_code, :country_code_2, :admin1_code,
        :admin2_code, :admin3_code, :admin4_code]

      # Construct a lookup map from field name to field index.
      field_index_by_name = Hash.new
      fields.each_with_index do |field_name, index|
        field_index_by_name[field_name] = index
      end

      geo_records = Array.new
      cities_by_state = Hash.new

      # Construct GeoDataParser::Record objects from parsed data.
      cities.each do |city|
        # Prepare values hash for constructing the Record.
        values = Hash.new
        filter_field_names.each_with_index do |name, index|
          values[name] = city[field_index_by_name[name]]
        end

        geo_record = Record.new(values)
        geo_record.country_name = countries[geo_record.country_code]
        geo_records << geo_record
        state = state_infos["#{geo_record.country_code}.#{geo_record.admin1_code}"]

        # State mapping found for the city's country and admin code.
        if state
          cities_by_state[state[:name]] = Array.new unless
            cities_by_state[state[:name]]

          cities_by_state[state[:name]] << geo_record
          geo_record.state = state[:name]
        end
      end

      states_by_country = Hash.new

      # Construct records for states.
      state_infos.values.each do |state_info|
        geo_record = Record.new(state_info)
        geo_record.country_name = countries[geo_record.country_code]
        states_by_country[geo_record.country_name] = Array.new unless
          states_by_country[geo_record.country_name]

        states_by_country[geo_record.country_name] << geo_record
        geo_records << geo_record
      end

      country_records = Array.new

      # Construct records for countries from their names.
      # The country_code is set to nil
      countries.values.each do |country|
        country_record = Record.new(:name => country, :country_code => nil)
        country_records << country_record
        geo_records << country_record
      end

      # Construct Tree hierarchy of countries, states and citites.
      country_nodes = Array.new
      geo_tree = Tree.new(nil, country_nodes, nil)
      country_records.each do |country|
        state_nodes = Array.new
        country_node = Tree.new(country, state_nodes, nil)

        # If there are states inside the country, process each of them in turn.
        (states_by_country[country.name] || []).each do |state|
          cities = Array.new
          state_node = Tree.new(state, cities, country_node)

          # Process cities inside the state.
          (cities_by_state[state.name] || []).each do |city|
            cities << Tree.new(city, nil, state_node)
          end
          state_nodes << state_node
        end
        country_nodes << country_node
      end

      return geo_tree
    end

    # Parses geographical location information in the given file
    #
    # Please refer to http://earth-info.nga.mil/gns/html/help.htm for the data
    # format
    #
    # Returns an array containing an array of header fields as the first item
    # and the data as the second item.
    #  
    def self.parse(data_file)
      geo_info = Array.new
      fields = [
        :geoname_id, :non_ascii_name, :name, :alternate_names,
        :latitude, :longitude, :feature_class, :feature_code, :country_code,
        :country_code_2, :admin1_code, :admin2_code, :admin3_code, :admin4_code,
        :population, :elevation, :gtopo30, :timezone, :modification_date]

      # For each line of data in file
      File.open(data_file, "r") do |line|
        while (record = line.gets) do
          # Get the record field values in array and push record into the info
          # collection.
          geo_info << record.split("\t")
        end
      end

      # Compute geo data array and return.
      [fields, geo_info]
    end
    
    # Parses the given admin file and constructs state records.
    #
    def self.parse_states(states_file)
      state_records = Hash.new

      # For each line of data in admin file
      File.open(states_file, "r") do |line|
        while (record = line.gets) do
          # Get the record field values in array and push record into the info
          # collection.
          fields                    = record.split("\t")
          state_id                  = fields[0]
          country_and_admin_code    = state_id.split('.')
          area_name                 = fields[2]
          country_code              = country_and_admin_code[0]
          admin_code                = country_and_admin_code[1]
          geo_id                    = fields[3]

          # Remove 'State of ' prefix from state names.          
          area_name.sub!('State of ', '')

          # Create a record with fields mapped as in the format of cities file.
          state_record = {
            :name => area_name,
            :feature_code => 'ADM1',
            :country_code => country_code,
            :admin_code => admin_code
          }

          # Map from the state's CC.FC e.g., IN.25 to the state record
          state_records[state_id] = state_record
        end
      end

      return state_records
    end

    # Parses the country records in the given data file and returns a map from
    # country code to country name.
    # IN => India
    # US => United States
    # ...
    # ..
    #
    # The country code is the 1st column in the file, and the name, the 5th
    # column.
    #
    def self.parse_country_codes(countries_file)
      countries = Hash.new

      # For each line of data in admin file
      File.open(countries_file, "r") do |line|
        while (record = line.gets) do
          begin
            fields  = record.split("\t")
            code    = fields[0]
            name    = fields[4]
            countries[code] = name
          rescue
            puts 'Unable to parse the line:'
            puts line.inspect
          end
        end
      end

      return countries
    end
  end
end