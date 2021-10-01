require_relative './../test_helper.rb'

class LocationsControllerTest < ActionController::TestCase
  def test_index_does_not_require_program_or_login
    mock_elasticsearch("Che", ["Chennai, Tamil Nadu, India"])
    get :index, xhr: true, params: { :loc_name => "Che", :format => :json}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["Chennai, Tamil Nadu, India"], JSON.parse(@response.body)
  end

  def test_make_sure_properly_escaped
    mock_elasticsearch("Che/", [])
    assert_nothing_raised do
      get :index, xhr: true, params: { :loc_name => "Che/", :format => :json}
    end
    @response.stubs(:content_type).returns "application/json"
    assert_equal [], JSON.parse(@response.body)
    assert_response :success
  end

  # Index returns the auto suggestion list
  def test_index_suggests_for_auto_complete
    current_program_is :albers
    current_user_is :f_student

    mock_elasticsearch("Ind", ["New Delhi, Delhi, India", "Chennai, Tamil Nadu, India", "Pondicherry, Pondicherry, India"])
    get :index, xhr: true, params: { :loc_name => "Ind"}
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["New Delhi, Delhi, India", "Chennai, Tamil Nadu, India", "Pondicherry, Pondicherry, India"], JSON.parse(@response.body)
  end

  def test_index_with_reliable_false
    current_program_is :albers
    current_user_is :f_student
    mock_elasticsearch("Invalid", [])
    get :index, xhr: true, params: { :loc_name => "Invalid", :format => :json}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal [], JSON.parse(@response.body)
  end

  def test_get_filtered_locations_for_autocomplete
    current_program_is :albers
    current_user_is :f_student

    mock_elasticsearch_for_locations_auto_complete(members(:f_student), "Ind", ["Indinapolis, Victoria, United States of America", "India"])
    get :get_filtered_locations_for_autocomplete, xhr: true, params: { :loc_name => "Ind", :format => :json}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["Indinapolis, Victoria, United States of America", "India"], JSON.parse(@response.body)
  end

  private
  def mock_elasticsearch(loc_name, expected_result)
    Location.expects(:get_list_of_autocompleted_locations).with(loc_name).returns(expected_result)
  end

  def mock_elasticsearch_for_locations_auto_complete(member, loc_name, expected_result)
    Location.expects(:get_filtered_list_of_autocompleted_locations).with(loc_name, member).returns(expected_result)
  end
end
