require_relative './../../test_helper.rb'

class MentorRequestViewTest < ActiveSupport::TestCase
  def test_count
    program = programs(:albers)
    MentorRequest.expects(:get_mentor_requests_search_count).with({"list"=>"pending", "search_filters"=>{"sender"=>nil, "receiver"=>nil}}, {program_id: program.id}).returns(15)
    pending_mentoring_request_view = MentorRequestView::DefaultViews.create_for(program)[0]
    initial_count = program.mentor_requests.active.count
    assert_equal initial_count, pending_mentoring_request_view.count
  end

  def test_default_views_create_for
    program = programs(:albers)
    program.abstract_views.where(type: "MentorRequestView").destroy_all
    mentoring_request_views = MentorRequestView::DefaultViews.create_for(program)
    pending_mentoring_request_view = mentoring_request_views[0]
    assert_equal 1, mentoring_request_views.size
    assert_equal_hash({status: AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED]}, pending_mentoring_request_view.filter_params_hash)
    assert_equal "feature.abstract_view.mentoring_request_view.pending_title".translate(program.management_report_related_custom_term_interpolations), pending_mentoring_request_view.title
    assert_equal "feature.abstract_view.mentoring_request_view.pending_description".translate(program.management_report_related_custom_term_interpolations), pending_mentoring_request_view.description
  end

  def test_default_views_create_for_portal
    program = programs(:primary_portal)
    program.abstract_views.where(type: "MentorRequestView").destroy_all
    assert_no_difference 'MentorRequestView.count' do
      MentorRequestView::DefaultViews.create_for(program)
    end
  end

  def test_get_params_to_service_format
    time = Time.now
    Time.stubs(:now).returns(time)
    hash = {status: "active", sender: "User1", receiver: "User2"}
    mrview = MentorRequestView.create!(program: programs(:albers), title: "Test", filter_params: AbstractView.convert_to_yaml(hash))
    assert_equal_hash({list: "active", search_filters: {sender: "User1", receiver: "User2"}}, mrview.get_params_to_service_format)

    hash = {status: "active", sender: "User1", receiver: "User2", sent: {after: 90} }
    mrview.update_attribute(:filter_params, AbstractView.convert_to_yaml(hash))
    assert_equal (Time.now() - 90.days).to_s, mrview.get_params_to_service_format[:search_filters][:expiry_date][0].to_s
    assert_equal Time.now().to_s, mrview.get_params_to_service_format[:search_filters][:expiry_date][1].to_s

    hash = {status: "active", sender: "User1", receiver: "User2", sent: {before: 10} }
    mrview.update_attribute(:filter_params, AbstractView.convert_to_yaml(hash))
    assert_equal DEFAULT_START_TIME.to_s, mrview.get_params_to_service_format[:search_filters][:expiry_date][0].to_s
    assert_equal (Time.now() - 10.days).to_s, mrview.get_params_to_service_format[:search_filters][:expiry_date][1].to_s

    hash = {status: "active", sender: "User1", receiver: "User2", sent: {before: 10, after: 90} }
    mrview.update_attribute(:filter_params, AbstractView.convert_to_yaml(hash))
    assert_equal (Time.now() - 90.days).to_s, mrview.get_params_to_service_format[:search_filters][:expiry_date][0].to_s
    assert_equal (Time.now() - 10.days).to_s, mrview.get_params_to_service_format[:search_filters][:expiry_date][1].to_s
  end

  def test_is_accessible
    prog = programs(:albers)
    assert  MentorRequestView.is_accessible?(prog)

    prog.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert_false  MentorRequestView.is_accessible?(prog)

    prog.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false  MentorRequestView.is_accessible?(prog)

    prog.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    assert  MentorRequestView.is_accessible?(prog)

    prog.update_attribute(:allow_mentoring_requests, false)
    assert_false  MentorRequestView.is_accessible?(prog)

    prog.update_attribute(:allow_mentoring_requests, true)
    assert  MentorRequestView.is_accessible?(prog)

    prog.mentor_request_style = Program::MentorRequestStyle::NONE
    assert_false  MentorRequestView.is_accessible?(prog)

    prog.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_ADMIN
    assert  MentorRequestView.is_accessible?(prog)

    prog.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_MENTOR
    assert  MentorRequestView.is_accessible?(prog)
  end
end