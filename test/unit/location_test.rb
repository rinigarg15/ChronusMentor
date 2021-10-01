require_relative './../test_helper.rb'

class LocationTest < ActiveSupport::TestCase
  include Math

  def test_uniq_full_address
    location = locations("chennai")
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :full_address, "has already been taken" do
      Location.create!(full_address: location.full_address)
    end

    location = Location.new(full_address: "This is a new full address")
    assert location.valid?
  end

  # If google throws exception, then just create a location and return
  def test_google_result_throws_exception
    Location.stubs(:geocode).raises(Geokit::Geocoders::GeocodeError.new("Google throws Error"))
    location = nil
    assert_difference('Location.count') do
      location = Location.find_or_create_from_google_result("blah blah blah", true)
    end
    loc = Location.last
    assert_equal "blah blah blah", loc.full_address
    assert !loc.reliable
    assert loc.lat.nil?
    assert loc.lng.nil?
    assert_equal loc, location

    # If google throws error and the address is already present with clean up status TRIED_BUT_FAILED, then just return the same location
    location = nil
    assert_no_difference('Location.count') do
      location = Location.find_or_create_from_google_result("blah blah blah", true)
    end
    assert_equal loc, location
  end

  def test_notify_on_quota_limit_exceed
    Location.stubs(:geocode).raises(Geokit::Geocoders::TooManyQueriesError.new("Limit Exceeded"))
    Airbrake.expects(:notify).once
    assert_difference('Location.count') do
      Location.find_or_create_from_google_result("blah blah blah", true)
    end
  end

  def test_observers_reindex_es
    ChronusElasticsearch.skip_es_index = false
    location = locations(:chennai)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Location, [location.id]).times(1)
    location.update_columns(lat: "123")
    ChronusElasticsearch.skip_es_index = true
  end

  # Given a google result, find_or_create a record
  def test_find_or_create_from_google_result
    madurai_details = Geokit::GeoLoc.new(
        :city => "Madurai",
        :state_name => 'Tamil Nadu',
        :country_code => "IN",
        :lat => 25,
        :lng => 33,
        :full_address => "Madurai, TamilNadu, India")
    Location.stubs(:geocode).returns(madurai_details)

    # If there is no known place, then a new locaton is constructed
    assert_difference('Location.count') do
      @madurai = Location.find_or_create_from_google_result("madurai", true)
    end
    assert_equal madurai_details.city, @madurai.city
    assert_equal madurai_details.state, @madurai.state
    assert_equal "India", @madurai.country
    assert_equal madurai_details.lat, @madurai.lat
    assert_equal madurai_details.lng, @madurai.lng
    assert_equal madurai_details.full_address, @madurai.full_address
    assert @madurai.reliable # No new location is reliable
  end

  # Given a google result, find_or_create a record
  def test_google_result_does_not_create_new_record_if_already_present
    # If blank is passed, dont return anything
    assert Location.find_or_create_from_google_result(nil).nil?
    assert Location.find_or_create_from_google_result('').nil?
    chennai_details = Geokit::GeoLoc.new(
        :city => locations(:chennai).city,
        :state => locations(:chennai).state,
        :country_code => locations(:chennai).country,
        :lat => locations(:chennai).lat,
        :lng => locations(:chennai).lng,
        :full_address => locations(:chennai).full_address)

    Location.stubs(:geocode).returns(chennai_details)

    # If there is no known place, then a new locaiton is constructed
    assert_no_difference('Location.count') do
      @chennai = Location.find_or_create_from_google_result("chennai", true)
    end

    assert_equal locations(:chennai), @chennai
  end

  def test_location_lookup
    chennai_details = Geokit::GeoLoc.new(
        city: locations(:chennai).city,
        state: locations(:chennai).state,
        country_code: locations(:chennai).country,
        lat: locations(:chennai).lat,
        lng: locations(:chennai).lng,
        full_address: locations(:chennai).full_address)

    Location.stubs(:geocode).returns(chennai_details)
    # If the given address yields an location of other address, then create a location lookup for this address and do not create a new location.
    assert_no_difference('Location.count') do
      assert_difference('LocationLookup.count') do
        @chennai = Location.find_or_create_from_google_result("chennai", true)
      end
    end
    location_lookup = LocationLookup.last
    assert_equal locations(:chennai), @chennai
    assert_equal "chennai", location_lookup.address_text
    assert_equal @chennai, location_lookup.location

    # Do not fetch locations from google if the address is present in location_lookups table.
    Location.expects(:find_or_create_from_google_result).times(0)
    assert_no_difference('Location.count') do
      assert_no_difference('LocationLookup.count') do
        Location.find_or_create_by_full_address("chennai")
      end
    end
  end

  def test_find_or_create_by_full_address_empty_case
    Location.expects(:find_or_create_from_google_result).at_least(0).returns(locations(:chennai))
    assert_no_difference('Location.count') do
      assert_nil Location.find_or_create_by_full_address("")
      assert_nil Location.find_or_create_by_full_address(nil)
      assert_nil Location.find_or_create_by_full_address("City/town name")
    end
  end

  def test_geokit_gets_full_state_name
    json = "{\n   \"results\" : [\n      {\n         \"address_components\" : [\n            {\n               \"long_name\" : \"Thirumullaivoyal\",\n               \"short_name\" : \"Thirumullaivoyal\",\n               \"types\" : [ \"political\", \"sublocality\", \"sublocality_level_1\" ]\n            },\n            {\n               \"long_name\" : \"Chennai\",\n               \"short_name\" : \"Chennai\",\n               \"types\" : [ \"locality\", \"political\" ]\n            },\n            {\n               \"long_name\" : \"Tiruvallur\",\n               \"short_name\" : \"Tiruvallur\",\n               \"types\" : [ \"administrative_area_level_2\", \"political\" ]\n            },\n            {\n               \"long_name\" : \"Tamil Nadu\",\n               \"short_name\" : \"TN\",\n               \"types\" : [ \"administrative_area_level_1\", \"political\" ]\n            },\n            {\n               \"long_name\" : \"India\",\n               \"short_name\" : \"IN\",\n               \"types\" : [ \"country\", \"political\" ]\n            }\n         ],\n         \"formatted_address\" : \"Thirumullaivoyal, Chennai, Tamil Nadu, India\",\n         \"geometry\" : {\n            \"bounds\" : {\n               \"northeast\" : {\n                  \"lat\" : 13.1487391,\n                  \"lng\" : 80.1464575\n               },\n               \"southwest\" : {\n                  \"lat\" : 13.114785,\n                  \"lng\" : 80.1223009\n               }\n            },\n            \"location\" : {\n               \"lat\" : 13.1386541,\n               \"lng\" : 80.1336702\n            },\n            \"location_type\" : \"APPROXIMATE\",\n            \"viewport\" : {\n               \"northeast\" : {\n                  \"lat\" : 13.1487391,\n                  \"lng\" : 80.1464575\n               },\n               \"southwest\" : {\n                  \"lat\" : 13.114785,\n                  \"lng\" : 80.1223009\n               }\n            }\n         },\n         \"place_id\" : \"ChIJP8nO_OViUjoRvQ8Tcea9QPY\",\n         \"types\" : [ \"political\", \"sublocality\", \"sublocality_level_1\" ]\n      }\n   ],\n   \"status\" : \"OK\"\n}"
    assert_equal "Tamil Nadu", Geokit::Geocoders::GoogleGeocoder.parse_json(MultiJson.load(json)).state_name
  end

  def test_find_or_create_by_full_address
    loc = create_location(:full_address => "Chennai, TamilNadu, India", :reliable => false)
    assert_no_difference('Location.count') do
      assert_nil Location.find_or_create_by_full_address("Chennai, TamilNadu, India")
    end

    Location.stubs(:find_or_create_from_google_result).at_least(1).returns(loc)
    assert_no_difference 'Location.count' do
      assert_equal loc, Location.find_or_create_by_full_address("Madras, TamilNadu, India")
    end
  end

  def test_full_address
    l = Location.new(:full_address => "Chennai,TamilNadu, India")
    assert_equal "Chennai, TamilNadu, India", l.full_address
    assert_equal "Chennai,TamilNadu, India", l.full_address(true)
    assert_equal "Chennai,TamilNadu, India", l.full_address_db
  end

  def test_reliable_with_fulladdress
    loc_rel = locations(:chennai)
    assert_equal [loc_rel], Location.reliable.with_fulladdress("Chennai, Tamil Nadu, India")
  end

  def test_location_answers
    question = profile_answers(:location_chennai_ans).profile_question
    user = users(:f_mentor)
    answer = user.answer_for(question)
    
    assert_equal user.location, answer.location
    assert_equal user.member.location_answer, answer
    assert_equal locations(:chennai), user.location
    assert_equal locations(:chennai).full_address, user.member.location_answer.answer_text
    assert_equal 3, locations(:chennai).profile_answers_count
    assert_equal 3, locations(:delhi).profile_answers_count
    
    answer.location = locations(:delhi)
    answer.save
    assert_equal locations(:delhi), user.reload.location

    assert_equal 2, locations(:chennai).reload.profile_answers_count
    assert_equal 4, locations(:delhi).reload.profile_answers_count
    assert_equal locations(:delhi).full_address, user.member.location_answer.answer_text
  end

  def test_location_destroy
    question = profile_answers(:location_chennai_ans).profile_question
    user = users(:f_mentor)
    answer = user.answer_for(question)
    assert_equal user.location, answer.location
    assert_equal 3, user.location.profile_answers_count
    
    assert_difference('ProfileAnswer.count', -3) do
      assert_difference('Location.count', -1) do
        locations(:chennai).destroy
      end
    end
    
    assert_nil user.reload.location
    assert_nil user.member.location_answer
  end

  def test_preference_based_mentor_lists
    location = Location.last
    assert_difference 'PreferenceBasedMentorList.count' do
      location.preference_based_mentor_lists.create!(user: User.first, profile_question: ProfileQuestion.first, weight: 0.55)
    end

    assert_equal 0.55, location.preference_based_mentor_lists.last.weight

    assert_difference 'PreferenceBasedMentorList.count', -1 do
      location.destroy
    end    
  end

  def test_location_after_update
    question = profile_answers(:location_chennai_ans).profile_question
    user = users(:f_mentor)
    answer = user.answer_for(question)
    assert_equal user.location, answer.location
    assert_equal 3, user.location.profile_answers_count
    delhi = locations(:delhi)
    chennai_location = user.location
    answer.location = delhi
    answer.save!
    assert_equal delhi, user.reload.location
    assert_equal 4, user.location.profile_answers_count
    assert_equal 2, chennai_location.reload.profile_answers_count
    assert_difference 'ProfileAnswer.count', -2 do
      assert_difference 'Location.count', -1 do
        locations(:chennai).destroy
      end
    end
  end

  def test_find_reliable_location
    profile_answer = profile_answers(:location_chennai_ans)
    location = profile_answer.location
    assert_equal location, Location.find_reliable_location("Chennai, Tamil Nadu, India")

    new_address = "Chennai, Tamil Nadu, In"
    assert_nil Location.find_reliable_location(new_address)

    new_location = Location.create!(:full_address => new_address, :lat => nil, :lng => nil, :reliable => false)
    assert_nil Location.find_reliable_location(new_address)

    new_location.update_attributes!(reliable: true, lat: location.lat, lng: location.lng)
    assert_equal new_location, Location.find_reliable_location(new_address)
  end

  def test_validations
    invalid_location = locations(:invalid_geo)
    assert_false invalid_location.reliable
    assert_nil invalid_location.lat
    assert_nil invalid_location.lng
    invalid_location.reliable = true
    assert_false invalid_location.valid?
    expected = {:lat=>["can't be blank"], :lng=>["can't be blank"]}
    assert_equal expected, invalid_location.errors.messages
  end

  def test_full_city
    location = locations(:chennai)
    assert_equal "Chennai,Tamil Nadu,India", location.full_city
  end

  def test_full_state
    location = locations(:chennai)
    assert_equal "Tamil Nadu,India", location.full_state
  end

  def test_full_country
    location = locations(:chennai)
    assert_equal "India", location.full_country
  end

  def test_full_location
    location = locations(:chennai)
    location.city = nil
    location.state = nil
    location.save!
    assert_equal "India", location.full_location
  end

  def test_get_formatted_location
    location = Location.first
    location.stubs(:reliable).returns(true)
    location.stubs(:full_location).returns('a,b,c d')
    assert_equal "a, b, c d", location.get_formatted_location

    location.stubs(:reliable).returns(false)
    location.stubs(:full_address).returns("something")
    assert_equal "something", location.get_formatted_location
  end

  def test_full_locations_generator
    location = locations(:chennai)
    assert_equal "city,state,country", location.full_locations_generator("city", "state", "country", "key")
  end

  def test_location_observer_after_update
    location = locations(:chennai)
    location.update_attributes!(full_address: "IIT Madras, Chennai, Tamil Nadu, India")
    profile_answers = location.profile_answers
    assert_equal "IIT Madras, Chennai, Tamil Nadu, India", profile_answers.collect(&:answer_text).uniq.first
  end

  def test_get_other_locations_in_the_city
    location = locations(:chennai)
    assert_equal [location].collect(&:id), location.get_other_locations_in_the_city.collect(&:id)

    location2 = location.dup
    location2.full_address = "IIT Madras, Chennai, Tamil Nadu, India"
    location2.save!

    assert_equal [location, location2].collect(&:id), location.get_other_locations_in_the_city.collect(&:id)
    assert_equal [location, location2].collect(&:id), location2.get_other_locations_in_the_city.collect(&:id)
  end

  def test_find_first_reliable_location_with
    assert_nil Location.find_first_reliable_location_with('Chennai', 'Tamil Nadu', nil)
    assert_nil Location.find_first_reliable_location_with('Chennai', '', 'India')
    assert_nil Location.find_first_reliable_location_with(nil, 'Tamil Nadu', 'India')

    assert_equal locations(:chennai).id, Location.find_first_reliable_location_with('Chennai', 'Tamil Nadu', 'India').id
  end
end
