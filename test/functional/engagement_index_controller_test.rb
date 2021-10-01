require_relative "./../test_helper.rb"

class EngagementIndexControllerTest < ActionController::TestCase
  def test_track_activity_no_organization
    @controller.expects(:track_activity_for_ei).with("Something", {:context_place => nil, :context_object => nil}).never
    get :track_activity, params: { activity: "Something"}
  end

  def test_track_activity_not_loggedin
    current_organization_is :org_primary
    @controller.expects(:track_activity_for_ei).with("Something", {:context_place => nil, :context_object => nil}).never
    get :track_activity, params: { activity: "Something"}
  end

  def test_track_activity_success
    current_member_is :f_admin
    @controller.expects(:track_activity_for_ei).with("Something", {:context_place => nil, :context_object => nil}).once
    get :track_activity, params: { activity: "Something"}

    @controller.expects(:track_activity_for_ei).with("Something", {:context_place => "src", :context_object => "test"}).once
    get :track_activity, params: { activity: "Something", src: "src", description: "test"}
  end
end