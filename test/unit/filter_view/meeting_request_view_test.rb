require_relative './../../test_helper.rb'

class MeetingRequestViewTest < ActiveSupport::TestCase
  def test_count
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    pending_meeting_request_view = MeetingRequestView::DefaultViews.create_for(program)[0]
    initial_count = program.meeting_requests.active.count
    meeting_request = program.meeting_requests.first
    meeting_request.skip_observer = true
    AbstractRequest::Status.all.reverse.each do |status|
      meeting_request.update_attribute(:status, status)
      assert_equal (status == AbstractRequest::Status::NOT_ANSWERED ? initial_count : (initial_count - 1)), pending_meeting_request_view.reload.count
    end
  end

  def test_default_views_create_for
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.abstract_views.where(type: "MeetingRequestView").destroy_all
    meeting_request_views = MeetingRequestView::DefaultViews.create_for(program)
    pending_meeting_request_view = meeting_request_views[0]
    assert_equal 1, meeting_request_views.size
    assert_equal_hash({list: :active}, pending_meeting_request_view.filter_params_hash)
  end

  def test_default_views_create_for_portal
    program = programs(:primary_portal)
    program.abstract_views.where(type: "MeetingRequestView").destroy_all
    assert_no_difference 'MeetingRequestView.count' do
      MeetingRequestView::DefaultViews.create_for(program)
    end
  end

  def test_is_accessible
    prog = programs(:albers)
    assert_false MeetingRequestView.is_accessible?(prog)
    
    prog.enable_feature(FeatureName::CALENDAR)
    assert MeetingRequestView.is_accessible?(prog)

    disable_feature(prog, FeatureName::CALENDAR)
    assert_false MeetingRequestView.is_accessible?(prog)
    
    prog.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert_false MeetingRequestView.is_accessible?(prog)
  end
end