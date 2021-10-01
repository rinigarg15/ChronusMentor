# == Schema Information
#
# Table name: locations
#
#  id                    :integer          not null, primary key
#  city                  :string(255)
#  state                 :string(255)
#  country               :string(255)
#  lat                   :float(24)
#  lng                   :float(24)
#  full_address          :string(255)
#  reliable              :boolean          default(FALSE)
#  user_answers_count    :integer          default(0)
#  profile_answers_count :integer          default(0)
#  cleanup_status        :integer          default(0)
#

class Location < ActiveRecord::Base
  include Geokit::Geocoders
  include LocationElasticsearchQueries
  include LocationElasticsearchSettings

  ES_SCOPE = "reliable"
  FULL_LOCATION_SPLITTER = ','
  acts_as_mappable :default_units => :kms, :distance_field_name => :distance

  has_many :profile_answers, :dependent => :destroy
  has_many :members, through: :profile_answers, source: :ref_obj, source_type: Member.name
  has_many :location_lookups, dependent: :destroy
  has_many :preference_based_mentor_lists, dependent: :destroy, as: :ref_obj
  validates :lat, :lng, presence: true, :if => :reliable?
  validates :full_address, uniqueness: true

  scope :reliable, -> {where(:reliable => true)}
  scope :with_fulladdress, ->(full_address) {
    where(["full_address = ? AND lat IS NOT NULL AND lng IS NOT NULL", full_address])
  }

  module CleanupStatus
    NOT_DONE = 0
    TRIED_BUT_FAILED = 1
    DONE = 2
  end

  module LocationFilter
    FULL_CITY = 'full_city'
    FULL_STATE = 'full_state'
    FULL_COUNTRY = 'full_country'
    DEFAULT_RADIUS = "10mi"
    MINIMUM_USERS = 3
    MINIMUM_CHARACTERS_FOR_AUTOCOMPLETE = 3
    MAXIMUM_RESULTS_FOR_LOCATION = {FULL_CITY => 10, FULL_STATE => 3, FULL_COUNTRY => 2}

    def self.indexed_fields
      [FULL_CITY, FULL_STATE, FULL_COUNTRY]
    end
  end

  def full_address(db = false)
    return self[:full_address] if db
    self[:full_address].gsub(/,\s*/, ", ")
  end

  def full_address_db
    self.full_address(true)
  end

  def point
    return nil if self.lng.nil? && self.lat.nil?
    [self.lng, self.lat]
  end

  def full_locations_generator(city, state, country, key)
    return nil if key.nil?
    join_location_attributes(city, state, country)
  end

  def full_city
    full_locations_generator(city, state, country, city)
  end

  def full_state
    full_locations_generator(nil, state, country, state)
  end

  def full_country
    full_locations_generator(nil, nil, country, country)
  end

  def full_location
    join_location_attributes(city, state, country)
  end

  def get_formatted_location
    reliable ? full_location.split(FULL_LOCATION_SPLITTER).join(', ') : full_address
  end

  def get_other_locations_in_the_city
    Location.reliable.where(city: city, state: state, country: country)
  end

  # If similar address is present, then return it
  # Try finding or constructing from google result
  # If not possible, create your own location
  #
  def self.find_or_create_by_full_address(full_address)
    return if full_address.blank? || full_address == "app_constant.city_town_name".translate
    self.find_reliable_location(full_address) || # If the location already exists then return it
      self.find_by_location_lookup(full_address) || # If the location exists in different text
        self.find_or_create_from_google_result(full_address)
  end

  def self.find_by_location_lookup(original_address)
    LocationLookup.where(address_text: original_address).first.try(:location)
  end

  # Looks up if there is any existing location with the given <i>full_address</i>.
  # Returns it if present. Or else, makes a query to google to find a matching
  # location and creates a <code>Location</code> record filled with the
  # resulting information.
  #
  def self.find_or_create_from_google_result(full_address, force_find = false)
    return if full_address.blank? || (Rails.env.test? && !force_find)
    begin
      google_res = self.geocode(full_address)

      # First check whether we have a location with the same location full
      # address that we got from google. If present, create a look up with the original address
      # to the location in LocationLookup table. If not present, create a location entry.
      # 
      # Since we lookup from google and fill the address, mark the location as
      # <i>reliable</i> so that it is eligible for autocompletion.
      self.create_lookup_if_full_address_present(google_res.full_address, full_address) ||
        self.create!(:city => google_res.city,
                     :state => google_res.state_name,
                     :country => CountryCodes.find_by_a2(google_res.country_code)[:name],
                     :lat => google_res.lat,
                     :lng => google_res.lng,
                     :reliable => true,
                     :full_address => google_res.full_address,
                     :cleanup_status => Location::CleanupStatus::DONE)
    rescue Geokit::Geocoders::TooManyQueriesError => error
      Airbrake.notify(error.message)
      handle_location_after_exception(full_address)
    rescue Geokit::Geocoders::GeocodeError => exception
      logger.error "Error while geocoding '#{full_address}' - #{exception.inspect}"
      # Airbrake.notify("Error while geocoding '#{full_address}'")
      handle_location_after_exception(full_address)
    end
  end

  def self.find_reliable_location(address_text)
    Location.where(reliable: true, full_address: address_text).first
  end

  def self.find_first_reliable_location_with(city, state, country)
    Location.where(reliable: true, city: city, state: state, country: country).first if city.present? && state.present? && country.present?
  end

  def self.find_tried_but_failed_location(full_address)
    Location.where(full_address: full_address, cleanup_status: Location::CleanupStatus::TRIED_BUT_FAILED).first
  end

  def self.create_lookup_if_full_address_present(full_address, original_address)
    location = self.find_reliable_location(full_address)
    LocationLookup.create!(address_text: original_address, location: location) if location.present?
    location
  end

  private

  def self.handle_location_after_exception(full_address)
    self.find_tried_but_failed_location(full_address) || self.create!(
      full_address: full_address,
      lat: nil,
      lng: nil,
      reliable: false,
      cleanup_status: Location::CleanupStatus::TRIED_BUT_FAILED
    )
  end

  def join_location_attributes(city, state, country)
    [city, state, country].compact.join(Location::FULL_LOCATION_SPLITTER)
  end
end
