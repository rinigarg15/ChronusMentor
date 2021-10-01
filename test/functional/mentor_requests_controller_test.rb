require_relative './../test_helper.rb'

class MentorRequestsControllerTest < ActionController::TestCase

  def test_login_required_for_new_mentor_request_form
    current_program_is :albers
    get :new
    assert_redirected_to new_session_path
  end

  def test_csv_export_with_empty_data
    program = programs(:ceg)
    assert_empty program.mentor_requests

    MentorRequest.expects(:get_filtered_mentor_requests).with({"format"=>"csv", "controller"=>"mentor_requests", "action"=>"index", "root"=>nil, "sort_field"=>"id", "sort_order"=>"desc"}, {program_id: program.id}, true, ["id"]).returns([])
    current_user_is :ceg_admin
    get :index, params: { format: 'csv'}
    assert_redirected_to(mentor_requests_path(list: 'active'))
    assert_equal "No requests to export!", flash[:error]
  end

  def test_csv_export
    program = programs(:moderated_program)
    assert_not_empty program.mentor_requests.active

    MentorRequest.expects(:get_filtered_mentor_requests).with({"format"=>"csv", "controller"=>"mentor_requests", "action"=>"index", "root"=>nil, "sort_field"=>"id", "sort_order"=>"desc"}, {program_id: program.id}, true, ["id"]).returns([Elasticsearch::Model::HashWrapper.new(id: 1)])
    current_user_is :moderated_admin
    get :index, params: { format: 'csv'}
    assert_redirected_to(mentor_requests_path(list: 'active'))
    assert_equal "Requests for mentoring are being exported to CSV. You will receive an email soon with the CSV report", flash[:notice]
    assert_equal 'active', assigns(:list_field)
  end

  def test_correct_order_as_params_new_preferred
    rahim = users(:rahim)
    ram = users(:ram)
    robert = users(:robert)
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    current_user_is :rahim
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    self.stubs(:dual_request_mode?).returns(false)
    get :new, params: { mentor_user_ids: [ram.id, robert.id]}
    assert_response :success
    assert_false assigns[:is_dual_request_mode]
    assert_equal [ram, robert], assigns(:mentor_users)
  end

  def test_bulk_csv_export_for_approver
    current_user_is :f_admin
    mentor_request = create_mentor_request(:student => users(:rahim), :program => programs(:albers))
    mentor_request1 = create_mentor_request(:student => users(:f_student), :program => programs(:albers))

    get :export, params: { :mentor_request_ids => "#{mentor_request.id},#{mentor_request1.id}", :format => 'csv'}
    assert_response :success
  end

  def test_pdf_export
    program = programs(:moderated_program)
    # There's at least 1 mentor request to export
    assert_not_empty program.mentor_requests.active.to_a

    MentorRequest.expects(:get_filtered_mentor_requests).with( { "format" => "pdf", "controller" => "mentor_requests", "action" => "index", "root" => nil, "sort_field" => "id", "sort_order" => "desc" }, {program_id: program.id}, true, ["id"]).returns([Elasticsearch::Model::HashWrapper.new(id: 1)])
    current_user_is :moderated_admin
    get :index, params: { format: 'pdf' }
    assert_redirected_to mentor_requests_path(list: 'active')
    assert_equal "Requests for mentoring are being exported to PDF. You will receive an email soon with the PDF report", flash[:notice]
    assert_equal 'active', assigns(:list_field)
  end

  def test_should_get_new_mentor_request_form_for_student
    current_user_is :f_student

    assert users(:f_student).is_student?
    self.stubs(:dual_request_mode?).returns(false)
    get :new, params: { :mentor_id => users(:f_mentor).id}
    assert_response :success
    assert_false assigns[:is_dual_request_mode]
    assert_template 'new'

    assert_select 'html' do
      assert_select 'div#title_box' do
        assert_select '.lead', "Request #{users(:f_mentor).name} to be my mentor"
      end
      assert_select "input[type=hidden][name=?][value='#{users(:f_mentor).id}']", 'mentor_request[receiver_id]'
      assert_select "div.favorite_mentors", 0
    end
    assert_tab @controller._Mentors
  end

  def test_new_mentor_request_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_student

    assert users(:f_student).is_student?
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_raise Authorization::PermissionDenied do
      get :new, params: { :mentor_id => users(:f_mentor).id}
    end
  end

  def test_create_mentor_request_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_student

    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_raise Authorization::PermissionDenied do
      post :create, params: { :mentor_request => {
        :receiver_id => users(:f_mentor).id,
        :message => 'Hi mentor'
      }}
    end
  end

  def test_index_mentor_request_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_mentor

    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_raise Authorization::PermissionDenied do
      get :index
    end
  end

  def test_should_redirect_if_limit_reached_for_new_connections
    current_user_is :f_student
    programs(:albers).update_attribute(:max_connections_for_mentee, 1)
    create_group(:student => users(:f_student))
    assert users(:f_student).reload.connection_limit_as_mentee_reached?

    get :new, params: { :mentor_id => users(:f_mentor_student).id}
    assert_redirected_to root_path
    assert_equal "You cannot send any more requests as you have reached the #{programs(:albers).term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase} limit", flash[:error]
  end

  def test_should_redirect_if_limit_reached_for_new_pending_requests
    current_user_is :f_student
    programs(:albers).update_attribute(:max_pending_requests_for_mentee, 1)
    create_mentor_request(:student => users(:f_student))
    assert users(:f_student).reload.pending_request_limit_reached_for_mentee?

    get :new, params: { :mentor_id => users(:f_mentor_student).id}
    assert_redirected_to root_path
    assert_match /You cannot send any more requests as you have reached the pending requests limit/, flash[:error]
  end

  def test_update_limit_only_increase_allowed
    mentor_request = create_mentor_request(status: AbstractRequest::Status::NOT_ANSWERED)
    current_user_is mentor_request.mentor
    user = mentor_request.mentor
    mentor_request.program.update_attributes!(connection_limit_permission: Program::ConnectionLimit::ONLY_INCREASE)
    user.update_attributes(max_connections_limit: 400)
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::REJECTED, rejection_type: AbstractRequest::Rejection_type::BUSY }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal flash[:notice], "Thank you for your response. #{mentor_request.student.name} has been notified."
    user.reload
    assert_equal 400, user.max_connections_limit
    mentor_request.reload
    assert_equal AbstractRequest::Rejection_type::BUSY, mentor_request.rejection_type
  end

  def test_no_impact_on_connection_limit_only_increase
    mentor_request = create_mentor_request(status: AbstractRequest::Status::NOT_ANSWERED)
    current_user_is mentor_request.mentor
    user = mentor_request.mentor
    mentor_request.program.update_attributes!(connection_limit_permission: Program::ConnectionLimit::ONLY_INCREASE)
    user.update_attributes(max_connections_limit: 3)
    array_of_size_5 = [1, 2, 3, 4, 5]
    User.any_instance.stubs(:students).with(:active).returns(array_of_size_5)
    Program.any_instance.stubs(:default_max_connections_limit).returns(3)
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::REJECTED, rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal flash[:notice], "Thank you for your response. #{mentor_request.student.name} has been notified."
    user.reload
    assert_equal 3, user.max_connections_limit
    mentor_request.reload
    assert_equal AbstractRequest::Status::REJECTED, mentor_request.rejection_type
  end

  def test_no_impact_on_connection_limit_only_decrease
    mentor_request = create_mentor_request(status: AbstractRequest::Status::NOT_ANSWERED)
    current_user_is mentor_request.mentor
    user = mentor_request.mentor
    mentor_request.program.update_attributes!(connection_limit_permission: Program::ConnectionLimit::ONLY_DECREASE)
    user.update_attributes(max_connections_limit: 3)
    array_of_size_5 = [1, 2, 3, 4, 5]
    User.any_instance.stubs(:students).with(:active).returns(array_of_size_5)
    Program.any_instance.stubs(:default_max_connections_limit).returns(3)
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::REJECTED, rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal flash[:notice], "Thank you for your response. #{mentor_request.student.name} has been notified."
    user.reload
    assert_equal 3, user.max_connections_limit
    mentor_request.reload
    assert_equal AbstractRequest::Status::REJECTED, mentor_request.rejection_type
  end

  def test_no_impact_on_connection_limit_both
    mentor_request = create_mentor_request(status: AbstractRequest::Status::NOT_ANSWERED)
    current_user_is mentor_request.mentor
    user = mentor_request.mentor
    mentor_request.program.update_attributes!(connection_limit_permission: Program::ConnectionLimit::BOTH)
    user.update_attributes(max_connections_limit: 3)
    array_of_size_5 = [1, 2, 3, 4, 5]
    User.any_instance.stubs(:students).with(:active).returns(array_of_size_5)
    Program.any_instance.stubs(:default_max_connections_limit).returns(3)
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::REJECTED, rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal flash[:notice], "Thank you for your response. #{mentor_request.student.name} has been notified."
    user.reload
    assert_equal 3, user.max_connections_limit
    mentor_request.reload
    assert_equal AbstractRequest::Status::REJECTED, mentor_request.rejection_type
  end

  def test_reject_for_limit_permission_both_and_connections_greater_than_program_limit
    #ongoing connections greater than program limit and less than user limit
    mentor_request = create_mentor_request(status: AbstractRequest::Status::NOT_ANSWERED)
    current_user_is mentor_request.mentor
    user = mentor_request.mentor
    mentor_request.program.update_attributes!(connection_limit_permission: Program::ConnectionLimit::BOTH)
    user.update_attributes(max_connections_limit: 7)
    array_of_size_5 = [1, 2, 3, 4, 5]
    User.any_instance.stubs(:students).with(:active).returns(array_of_size_5)
    Program.any_instance.stubs(:default_max_connections_limit).returns(4)
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::REJECTED, rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal "Thank you for your response. #{mentor_request.student.name} has been notified. Your mentoring connections limit is updated to make sure you don't receive any new requests. You can always update your limit under your <a href=\"/p/albers/members/3/edit?focus_settings_tab=true&amp;scroll_to=user_max_connections_limit\">profile settings</a>.", flash[:notice]
    user.reload
    assert_equal 5, user.max_connections_limit
    mentor_request.reload
    assert_equal AbstractRequest::Status::REJECTED, mentor_request.rejection_type
  end

  def test_reject_for_limit_permission_only_increase_and_connections_greater_than_program_limit
    #ongoing connections greater than program limit and less than user limit only increase allowed
    mentor_request = create_mentor_request(status: AbstractRequest::Status::NOT_ANSWERED)
    current_user_is mentor_request.mentor
    user = mentor_request.mentor
    mentor_request.program.update_attributes!(connection_limit_permission: Program::ConnectionLimit::ONLY_INCREASE)
    user.update_attributes(max_connections_limit: 7)
    array_of_size_5 = [1, 2, 3, 4, 5]
    User.any_instance.stubs(:students).with(:active).returns(array_of_size_5)
    Program.any_instance.stubs(:default_max_connections_limit).returns(4)
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::REJECTED, rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal "Thank you for your response. #{mentor_request.student.name} has been notified. Your mentoring connections limit is updated to make sure you don't receive any new requests. You can always update your limit under your <a href=\"/p/albers/members/3/edit?focus_settings_tab=true&amp;scroll_to=user_max_connections_limit\">profile settings</a>.", flash[:notice]
    user.reload
    assert_equal 5, user.max_connections_limit
    mentor_request.reload
    assert_equal AbstractRequest::Status::REJECTED, mentor_request.rejection_type
  end

  def test_reject_for_limit_permission_only_decrease_and_connections_greater_than_program_limit
    #ongoing connections greater than program limit and less than user limit only decrease allowed
    mentor_request = create_mentor_request(status: AbstractRequest::Status::NOT_ANSWERED)
    current_user_is mentor_request.mentor
    user = mentor_request.mentor
    mentor_request.program.update_attributes!(connection_limit_permission: Program::ConnectionLimit::ONLY_DECREASE)
    user.update_attributes(max_connections_limit: 7)
    array_of_size_5 = [1, 2, 3, 4, 5]
    User.any_instance.stubs(:students).with(:active).returns(array_of_size_5)
    Program.any_instance.stubs(:default_max_connections_limit).returns(4)
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::REJECTED, rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal "Thank you for your response. #{mentor_request.student.name} has been notified. Your mentoring connections limit is updated to make sure you don't receive any new requests. You can always update your limit under your <a href=\"/p/albers/members/3/edit?focus_settings_tab=true&amp;scroll_to=user_max_connections_limit\">profile settings</a>.", flash[:notice]
    user.reload
    assert_equal 5, user.max_connections_limit
    mentor_request.reload
    assert_equal AbstractRequest::Status::REJECTED, mentor_request.rejection_type
  end

  def test_reject_for_limit_permission_both_and_connections_less_than_program_limit
    #ongoing connections less than program
    mentor_request = create_mentor_request(status: AbstractRequest::Status::NOT_ANSWERED)
    current_user_is mentor_request.mentor
    user = mentor_request.mentor
    mentor_request.program.update_attributes!(connection_limit_permission: Program::ConnectionLimit::BOTH)
    user.update_attributes(max_connections_limit: 6)
    array_of_size_3 = [1, 2, 3]
    User.any_instance.stubs(:students).with(:active).returns(array_of_size_3)
    Program.any_instance.stubs(:default_max_connections_limit).returns(4)
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::REJECTED, rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal "Thank you for your response. #{mentor_request.student.name} has been notified. Your mentoring connections limit is updated to make sure you don't receive any new requests. You can always update your limit under your <a href=\"/p/albers/members/3/edit?focus_settings_tab=true&amp;scroll_to=user_max_connections_limit\">profile settings</a>.", flash[:notice]
    user.reload
    assert_equal 3, user.max_connections_limit
    mentor_request.reload
    assert_equal AbstractRequest::Status::REJECTED, mentor_request.rejection_type
  end

  def test_reject_for_limit_permission_only_increase_and_connections_less_than_program_limit
    #ongoing connections less than program and only incease allowed
    mentor_request = create_mentor_request(status: AbstractRequest::Status::NOT_ANSWERED)
    current_user_is mentor_request.mentor
    user = mentor_request.mentor
    mentor_request.program.update_attributes!(connection_limit_permission: Program::ConnectionLimit::ONLY_INCREASE)
    user.update_attributes(max_connections_limit: 6)
    array_of_size_3 = [1, 2, 3]
    User.any_instance.stubs(:students).with(:active).returns(array_of_size_3)
    Program.any_instance.stubs(:default_max_connections_limit).returns(4)
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::REJECTED, rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal flash[:notice], "Thank you for your response. #{mentor_request.student.name} has been notified."
    user.reload
    assert_equal 4, user.max_connections_limit
    mentor_request.reload
    assert_equal AbstractRequest::Status::REJECTED, mentor_request.rejection_type
  end

  def test_reject_for_limit_permission_only_decrease_and_connections_less_than_program_limit
    #ongoing connections less than program and only decrease allowed
    mentor_request = create_mentor_request(status: AbstractRequest::Status::NOT_ANSWERED)
    current_user_is mentor_request.mentor
    user = mentor_request.mentor
    mentor_request.program.update_attributes!(connection_limit_permission: Program::ConnectionLimit::ONLY_DECREASE)
    user.update_attributes(max_connections_limit: 6)
    array_of_size_3 = [1, 2, 3]
    User.any_instance.stubs(:students).with(:active).returns(array_of_size_3)
    Program.any_instance.stubs(:default_max_connections_limit).returns(4)
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::REJECTED, rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal "Thank you for your response. #{mentor_request.student.name} has been notified. Your mentoring connections limit is updated to make sure you don't receive any new requests. You can always update your limit under your <a href=\"/p/albers/members/3/edit?focus_settings_tab=true&amp;scroll_to=user_max_connections_limit\">profile settings</a>.", flash[:notice]
    user.reload
    assert_equal 3, user.max_connections_limit
    mentor_request.reload
    assert_equal AbstractRequest::Status::REJECTED, mentor_request.rejection_type
  end

  def test_update_invalid_id
    current_user_is :f_mentor
    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
    post :update, params: { id: 0, mentor_request: { status: AbstractRequest::Status::ACCEPTED }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_equal "The request you are trying to access does not exist.", flash[:error]
    assert_redirected_to mentor_requests_path
  end

  def test_update_non_active_request
    mentor_request = create_mentor_request(status: AbstractRequest::Status::WITHDRAWN)

    current_user_is mentor_request.mentor
    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
    post :update, params: { id: mentor_request.id, mentor_request: { status: AbstractRequest::Status::ACCEPTED }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert mentor_request.reload.withdrawn?
    assert_equal "The request has already been withdrawn.", flash[:error]
    assert_redirected_to mentor_requests_path
  end

  def test_should_allow_new_request_if_pending_request_is_accepted
    current_user_is :f_mentor
    programs(:albers).update_attribute(:max_pending_requests_for_mentee, 1)
    mentor_request = create_mentor_request(:student => users(:f_student))
    assert users(:f_student).reload.pending_request_limit_reached_for_mentee?

    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).once
    assert_difference 'Group.count' do
      post :update, params: { :id => mentor_request.id,
        :mentor_request => {
        :status => AbstractRequest::Status::ACCEPTED,
        src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
      }}
    end
    assert_false users(:f_student).reload.pending_request_limit_reached_for_mentee?
  end

  def test_should_redirect_if_not_allowed_without_flash
    current_user_is :f_student
    setup_admin_custom_term
    programs(:org_primary).term_for(CustomizedTerm::TermType::PROGRAM_TERM).update_term(term: "Track")
    programs(:albers).update_attribute(:allow_mentoring_requests, false)

    get :new, params: { :mentor_id => users(:f_mentor_student).id}
    assert_redirected_to root_path
    assert_equal "The track super admin does not allow you to send any requests.", flash[:error]
  end

  def test_should_redirect_if_not_allowed_with_flash
    current_user_is :f_student
    programs(:albers).update_attributes(:allow_mentoring_requests_message => "Deadline past", :allow_mentoring_requests => false)

    get :new, params: { :mentor_id => users(:f_mentor_student).id}
    assert_redirected_to root_path
    assert_equal "Deadline past", flash[:error]
  end

  def test_should_get_new_mentor_request_form_for_student_tightly
    current_user_is :moderated_student
    get :new
    assert_response :success
    assert_template 'new'

    assert_select 'html' do
      assert_select 'div#title_box' do
        assert_select '.lead', "Request Mentoring Connection"
      end
    end
    assert_tab @controller._Mentors
  end

  def test_should_not_get_new_mentor_request_form_for_mentor
    current_user_is :f_mentor
    assert users(:f_mentor).is_mentor?

    assert_permission_denied do
      get :new, params: { :mentor_id => users(:f_mentor_student).id}
    end
  end

  def test_should_not_get_new_mentor_request_form_for_mentee_without_permissions
    current_user_is :f_student
    remove_mentor_request_permission_for_students

    assert_permission_denied do
      get :new, params: { :mentor_id => users(:f_mentor).id}
    end
  end

  def test_should_not_get_new_mentor_request_form_for_admin
    current_user_is :f_admin

    assert_permission_denied do
      get :new, params: { :mentor_id => users(:f_mentor).id}
    end
  end

  def test_end_user_cant_access_all_mentor_requests
    current_user_is :f_mentor_student

    assert_permission_denied do
      get :index, params: { :filter => AbstractRequest::Filter::ALL}
    end
  end

  def test_mentor_student_role_user_accessing_mentor_requests
    current_user_is :f_mentor_student

    get :index
    assert_response :success
    assert_template 'index'
    assert_equal AbstractRequest::Filter::BY_ME, assigns(:filter_field)
  end

  def test_create_request_for_oneself
    current_user_is :f_mentor_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    assert_no_difference('MentorRequest.count') do
        post :create, params: { :mentor_request => {:receiver_id => users(:f_mentor_student).id, :message => "Hello"}}
    end
  end

  def test_new_favorites
    current_user_is :moderated_student
    user = users(:moderated_student)
    get :new
    assert_equal_unordered user.get_visible_favorites, assigns(:favorites)
  end

  def test_create_mentor_request_success
    current_user_is :f_student
    users(:f_mentor).received_mentor_requests.active.destroy_all
    src = EngagementIndex::Src::SendRequestOrOffers::QUICK_CONNECT_BOX
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_REQUEST, {:context_place => src}).once
    @controller.expects(:finished_chronus_ab_test).times(2)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    Program.any_instance.stubs(:dual_request_mode?).returns(true)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    UserPreferenceService.any_instance.stubs(:find_available_favorite_users).returns([users(:f_mentor), users(:f_admin)])

    assert_difference 'MentorRequest.count' do
      post :create, params: { mentor_request: {
        receiver_id: users(:f_mentor).id,
        message: 'Hi mentor', src: src,
        allowed_request_type_change: AbstractRequest::AllowedRequestTypeChange::MENTOR_REQUEST_TO_MEETING_REQUEST
      }}
    end

    mentor_request = MentorRequest.last
    assert_redirected_to member_path(members(:f_mentor), :mentor_request_sent => 1, favorite_user_ids: [users(:f_mentor).id, users(:f_admin).id])
    assert_equal "Your request for a mentoring connection has been successfully sent to #{users(:f_mentor).name}. You will be notified once the mentor accepts your request.", flash[:notice]
    assert_equal "See more mentors &raquo;", flash[:view_item][:label]
    assert_equal programs(:albers), mentor_request.program
    assert_equal users(:f_student), mentor_request.student
    assert_equal users(:f_mentor), mentor_request.mentor
    assert mentor_request.allow_request_type_change_from_mentor_to_meeting?
    assert_equal 'Hi mentor', mentor_request.message
  end

  def test_create_mentor_request_success_should_not_show_see_mentors_in_flash
    current_user_is :f_student
    programs(:albers).update_attribute(:max_pending_requests_for_mentee, 1)
    users(:f_mentor).received_mentor_requests.active.destroy_all
    src = EngagementIndex::Src::SendRequestOrOffers::HOVERCARD
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_REQUEST, {:context_place => src}).once
    @controller.expects(:finished_chronus_ab_test).times(2)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    Program.any_instance.stubs(:dual_request_mode?).returns(false)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(false)

    assert_difference 'MentorRequest.count' do
      post :create, params: { mentor_request: {
        receiver_id: users(:f_mentor).id,
        message: 'Hi mentor', src: src,
        allowed_request_type_change: AbstractRequest::AllowedRequestTypeChange::MENTOR_REQUEST_TO_MEETING_REQUEST
      }}
    end
    mentor_request = MentorRequest.last
    assert_redirected_to member_path(members(:f_mentor), :mentor_request_sent => 1)
    assert_equal "Your request for a mentoring connection has been successfully sent to #{users(:f_mentor).name}. You will be notified once the mentor accepts your request.", flash[:notice]
    assert_false assigns[:is_dual_request_mode]
    assert_nil flash[:view_item]
    assert_equal programs(:albers), mentor_request.program
    assert_equal users(:f_student), mentor_request.student
    assert_equal users(:f_mentor), mentor_request.mentor
    assert_false mentor_request.allow_request_type_change_from_mentor_to_meeting?
    assert_equal 'Hi mentor', mentor_request.message
  end

  def test_should_redirect_if_connections_limit_reached_for_create
    current_user_is :f_student
    programs(:albers).update_attribute(:max_connections_for_mentee, 1)
    create_group(:student => users(:f_student))
    assert users(:f_student).reload.connection_limit_as_mentee_reached?

    src = EngagementIndex::Src::SendRequestOrOffers::HOVERCARD
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_REQUEST, {:context_place => src}).never
    @controller.expects(:finished_chronus_ab_test).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    assert_no_difference 'MentorRequest.count' do
      post :create, params: { :mentor_request => {:receiver_id => users(:f_mentor_student).id, :message => 'Hi', src: src}}
    end
    assert_redirected_to root_path
    assert_equal "You cannot send any more requests as you have reached the mentoring connections limit", flash[:error]
  end

  def test_get_new_with_preference_mode_enabled
    rahim = users(:rahim)
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    expected_recommended_users = mentor_recommendation.recommendation_preferences.collect{|x| x.preferred_user}
    current_user_is :rahim
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    get :new, params: { mentor_user_ids: mentor_recommendation.recommended_users.pluck(:id)}
    assert_response :success
    assert_equal rahim.student_cache_normalized, assigns(:match_array)
    assert_equal expected_recommended_users, assigns(:recommended_users)
  end

  def test_get_new_with_preference_mode_enabled_prefilled_with_preferred_mentors
    rahim = users(:rahim)
    favorite_users = [users(:mentor_1), users(:mentor_2), users(:mentor_3)]
    favorites = favorite_users.collect { |favorite_user| create_favorite(user: rahim, favorite: favorite_user) }

    current_user_is :rahim
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    get :new
    assert_response :success
    assert_equal rahim.student_cache_normalized, assigns(:match_array)
    assert_equal favorite_users, assigns(:mentor_users)
    assert_equal favorites, assigns(:favorites)
  end

  def test_get_new_with_preference_mode_enabled_prefilled_with_mentors_in_paramter
    rahim = users(:rahim)
    favorite_users = [users(:mentor_1), users(:mentor_2), users(:mentor_3)]
    favorites = favorite_users.collect { |favorite_user| create_favorite(user: rahim, favorite: favorite_user) }
    mentors_in_parameters = [users(:mentor_5), users(:mentor_6)]

    current_user_is :rahim
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    get :new, params: { mentor_user_ids: mentors_in_parameters.collect(&:id)}
    assert_response :success
    assert_false assigns[:is_dual_request_mode]
    assert_equal rahim.student_cache_normalized, assigns(:match_array)
    assert_equal mentors_in_parameters, assigns(:mentor_users)
    assert_equal favorites, assigns(:favorites)
  end

  def test_get_new_without_preference_mode_enabled
    rahim = users(:rahim)
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    current_user_is :rahim
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    get :new
    assert_response :success
    assert_nil assigns(:match_array)
    assert_nil assigns(:recommendation_preferences)
  end

  def test_should_redirect_if_pending_requests_limit_reached_for_create
    current_user_is :f_student
    programs(:albers).update_attribute(:max_pending_requests_for_mentee, 1)
    create_mentor_request(:student => users(:f_student))
    assert users(:f_student).reload.pending_request_limit_reached_for_mentee?

    src = EngagementIndex::Src::SendRequestOrOffers::HOVERCARD
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_REQUEST, {:context_place => src}).never
    @controller.expects(:finished_chronus_ab_test).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    assert_no_difference 'MentorRequest.count' do
      post :create, params: { :mentor_request => {:receiver_id => users(:f_mentor_student).id, :message => 'Hi', src: src}}
    end
    assert_redirected_to root_path
    assert_match /You cannot send any more requests as you have reached the pending requests limit/, flash[:error]
  end

  def test_create_mentor_request_success_moderated_groups_with_preference
    make_member_of :moderated_program, :f_student
    make_member_of :moderated_program, :f_mentor_student
    make_member_of :moderated_program, :f_mentor
    current_user_is :f_student
    setup_admin_custom_term
    u1 = UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor), :note => "He is not the best")
    u2 = UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor_student), :note => "The best")
    u3 = UserFavorite.create!(:user => users(:f_student), :favorite => users(:moderated_mentor), :note => "The best")

    src = EngagementIndex::Src::SendRequestOrOffers::USER_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_REQUEST, {:context_place => src}).never
    @controller.expects(:finished_chronus_ab_test).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).once
    assert_difference 'RequestFavorite.count',2 do
      assert_difference 'MentorRequest.count' do
        post :create, params: { :mentor_request => {:message => 'Hi mentor', src: src},
            :preferred_mentor_ids => [users(:f_mentor_student).id.to_s, "", users(:mentor_3).id.to_s],
            :comments => ["Good", "Some text that is going to be missed", "Great"]
        }
      end
    end

    mentor_request = MentorRequest.last
    assert_redirected_to program_root_path
    assert_equal "Your request has been sent to super admin and you will be notified once a mentor is assigned.", flash[:notice]
    assert_equal programs(:moderated_program), mentor_request.program
    assert_equal users(:f_student), mentor_request.student
    assert_equal users(:f_mentor_student), mentor_request.request_favorites[0].favorite
    assert_equal users(:mentor_3), mentor_request.request_favorites[1].favorite
    assert_false mentor_request.allow_request_type_change_from_mentor_to_meeting?
    assert_nil mentor_request.mentor
    assert_equal 'Hi mentor', mentor_request.message
  end

  def test_create_mentor_request_success_moderated_groups_without_preference
    make_member_of :moderated_program, :f_student
    make_member_of :moderated_program, :f_mentor_student
    make_member_of :moderated_program, :f_mentor
    programs(:moderated_program).update_attributes!(:allow_preference_mentor_request => false)
    current_user_is :f_student

    # 2 emails because 2 admin users for the program
    src = EngagementIndex::Src::SendRequestOrOffers::USER_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_REQUEST, {:context_place => src}).never
    @controller.expects(:finished_chronus_ab_test).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).once
    assert_emails 2 do
      assert_difference 'MentorRequest.count' do
        post :create, params: { :mentor_request => {:message => 'Hi mentor', src: src}}
      end
    end

    mentor_request = MentorRequest.last
    assert_redirected_to program_root_path
    assert_equal "Your request has been sent to administrator and you will be notified once a mentor is assigned.", flash[:notice]
    assert_equal programs(:moderated_program), mentor_request.program
    assert_false mentor_request.program.preferred_mentoring_for_mentee_to_admin?
    assert_equal users(:f_student), mentor_request.student
    assert_nil mentor_request.mentor
    assert_equal 'Hi mentor', mentor_request.message
  end

  def test_create_failure_moderated_groups_min_pref_limit
    make_member_of :moderated_program, :f_student
    make_member_of :moderated_program, :f_mentor_student
    make_member_of :moderated_program, :f_mentor
    current_user_is :f_student
    programs(:moderated_program).update_attribute(:min_preferred_mentors, 3)
    u1 = UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor), :note => "He is not the best")
    u2 = UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor_student), :note => "The best")
    u3 = UserFavorite.create!(:user => users(:f_student), :favorite => users(:moderated_mentor), :note => "The best")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    assert_no_difference 'RequestFavorite.count' do
      assert_no_difference 'MentorRequest.count' do
        post :create, params: { :mentor_request => {:message => 'Hi mentor'},
            :preferred_mentor_ids => [users(:f_mentor_student).id.to_s, "", users(:mentor_3).id.to_s],
            :comments => ["Good", "Some text that is going to be missed", "Great"]
        }
      end
    end

    assert_response :success
    assert_template 'new'
    mentor_request = assigns(:mentor_request)
    assert_equal programs(:moderated_program), mentor_request.program
    assert_equal users(:f_student), mentor_request.student
    assert_equal 'Hi mentor', mentor_request.message
  end

  def test_create_failure_moderated_groups_min_pref_limit_no_prefs
    make_member_of :moderated_program, :f_student
    current_user_is :f_student
    programs(:moderated_program).update_attribute(:min_preferred_mentors, 3)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    assert_no_difference 'RequestFavorite.count' do
      assert_no_difference 'MentorRequest.count' do
        post :create, params: { :mentor_request => {:message => 'Hi mentor'},
            :preferred_mentor_ids => ["", ""],
            :comments => ["1", "2"]
        }
      end
    end

    assert_response :success
    assert_template 'new'
    mentor_request = assigns(:mentor_request)
    assert_equal programs(:moderated_program), mentor_request.program
    assert_equal users(:f_student), mentor_request.student
    assert_equal 'Hi mentor', mentor_request.message
  end

  def test_create_mentor_request_failure_should_render_new_form
    current_user_is :f_student

    mentor = users(:f_mentor_ceg)

    # Mentor does not belong to program
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    assert_no_difference 'MentorRequest.count' do
      post :create, params: { :mentor_request => { :receiver_id => mentor.id, :message => 'Hi mentor' }}
    end

    assert_response :success
    assert_template 'new'
    mentor_request = assigns(:mentor_request)
    assert_equal programs(:albers), mentor_request.program
    assert_equal users(:f_student), mentor_request.student
    assert_equal mentor, mentor_request.mentor
    assert_equal 'Hi mentor', mentor_request.message
  end

  def test_create_mentor_request_failure_as_the_limit_for_mentor_is_reached
    current_user_is :f_student

    assert_equal 2, users(:f_mentor).max_connections_limit
    # This limit for the :f_mentor is 2, so creating one more group to make him reach limit
    create_group(:student => users(:f_mentor_student))

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    assert_no_difference 'MentorRequest.count' do
      post :create, params: { :mentor_request => { :receiver_id => users(:f_mentor).id, :message => 'Hi mentor'}}
    end

    assert_redirected_to users_path()
    assert_equal "#{users(:f_mentor).name} is not accepting any requests currently! Please browse through other mentors listed.", flash[:error]
  end

  def test_create_mentor_request_failure_as_the_limit_for_mentor_is_reached_with_pending_request
    current_user_is :f_student

    assert_equal 2, users(:f_mentor).max_connections_limit
    # This limit for the :f_mentor is 2, so creating one more pending mentor request to make him reach limit
    create_mentor_request(:student => users(:f_student), :mentor => users(:f_mentor))

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    assert_no_difference 'MentorRequest.count' do
      post :create, params: { :mentor_request => { :receiver_id => users(:f_mentor).id, :message => 'Hi mentor'}}
    end

    assert_redirected_to users_path()
    assert_equal "#{users(:f_mentor).name} is not accepting any requests currently! Please browse through other mentors listed.", flash[:error]
  end

  def test_list_active_mentor_requests
    current_user_is :f_mentor

    active_requests = programs(:albers).mentor_requests.active.to_mentor(users(:f_mentor)).order(id: 'desc')

    get :index
    assert_response :success
    assert_template 'index'
    assert_select 'html'
    assert_equal 1, assigns(:page)
    # all_requests[0..15] have the request to the mentor in the @current_program.
    # others belong to a different program
    paginated_requests = wp_collection_from_array(active_requests, 1)
    assert_equal paginated_requests, assigns(:mentor_requests)
    assert_nil assigns(:match_results_per_mentor)

    assert_select "a[href=?]", groups_path, :count => 0
  end

  def test_list_accepted_rejected_mentor_requests
    current_user_is :f_mentor

    rejected_requests = programs(:albers).mentor_requests.rejected.to_mentor(users(:f_mentor)).order(id: 'desc')

    get :index, params: { :list => 'rejected'}
    assert_response :success
    assert_template 'index'
    paginated_requests = wp_collection_from_array(rejected_requests, 1)
    assert_equal paginated_requests, assigns(:mentor_requests)
  end

  def test_request_view_for_admin
    current_user_is :f_admin
    view = MentorRequestView::DefaultViews.create_for(programs(:albers))[0]

    get :manage, params: { :view_id => view.id}
    assert_response :success

    assert_equal AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED].to_s, assigns(:action_params)[:list]
    assert_equal_hash({sender: nil, receiver: nil, expiry_date: nil}, assigns(:action_params)[:search_filters])

    assert_equal view.title, assigns(:title)
    assert_equal AbstractRequest::Status::STATUS_TO_SCOPE[AbstractRequest::Status::NOT_ANSWERED].to_s, assigns(:list_field)
    assert assigns(:mentor_request_view)
    assert_equal_hash({:label => "feature.reports.header.program_management_report".translate(program: "Program"), :link => management_report_path}, assigns(:back_link))
    assert_equal assigns(:mentor_requests).size, 10
  end


  def test_request_view_with_alert_id_param
    current_user_is :f_admin
    program = programs(:albers)
    view = MentorRequestView::DefaultViews.create_for(program)[0]
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending Mentoring Request", abstract_view_id: view.id)
    alert_params = {target: 20, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::MentorRequestViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10"}}.to_yaml.gsub(/--- \n/, "")}
    alert = create_alert_for_metric(metric, alert_params)
    search_params = FilterUtils.process_filter_hash_for_alert(view, view.get_params_to_service_format, alert)
    MentorRequest.expects(:get_filtered_mentor_requests).with({"list"=>"pending", "search_filters"=> {}, "view_id"=>"#{view.id}", "alert_id"=>"#{alert.id}", "controller"=>"mentor_requests", "action"=>"manage", "root"=>nil, "filter"=>"all", "sort_field"=>"id", "sort_order"=>"desc"}.merge(search_params), { program_id: programs(:albers).id }, nil, nil).returns(MentorRequest.where(id: [21, 20, 18, 17, 12, 11, 10, 9, 8, 7]).paginate(page: 1, per_page: PER_PAGE))

    get :manage, params: { :view_id => view.id, :alert_id => alert.id}
    assert_response :success
    assert_equal_unordered [:sender.to_s, :receiver.to_s, FilterUtils::MeetingRequestViewFilters::SENT_BETWEEN], assigns(:action_params)[:search_filters].keys
    get :manage, params: { :view_id => view.id}

    assert_response :success
    assert_equal_hash({sender: nil, receiver: nil, expiry_date: nil}, assigns(:action_params)[:search_filters])
 end

  def test_index_with_src
    current_user_is :f_admin
    get :index, params: { :src => ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)
  end

  def test_index_no_src
    current_user_is :f_admin
    get :index
    assert_response :success
    assert_nil assigns(:src_path)
  end

  def test_manage_with_src
    current_user_is :f_admin
    get :manage, params: { :src => ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)
  end

  def test_manage_no_src
    current_user_is :f_admin
    get :manage
    assert_response :success
    assert_nil assigns(:src_path)
  end

  def test_request_view_for_admin_with_filters
    current_user_is :f_admin
    view = MentorRequestView::DefaultViews.create_for(programs(:albers))[0]

    get :manage, params: { :view_id => view.id, :page => 2, :search_filters => {:receiver => "Good unique name"}}
    # MentorRequest.expects(:get_filtered_mentor_requests).with({"list"=>"pending", "search_filters"=>{"receiver"=>"Good unique name"}, "view_id"=>"#{view.id}", "page"=>"2", "controller"=>"mentor_requests", "action"=>"manage", "root"=>nil, "filter"=>"all", "sort_field"=>"id", "sort_order"=>"desc"}, { program_id: programs(:albers).id }, nil, nil).returns(MentorRequest.where(id: [2]).paginate(page: 2, per_page: PER_PAGE))

    assert_response :success
    assert_equal AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED].to_s, assigns(:action_params)[:list]
    assert_equal "2", assigns(:action_params)[:page]
    assert_equal_hash({receiver: "Good unique name", expiry_date: nil}, assigns(:action_params)[:search_filters])

    assert_equal view.title, assigns(:title)
    assert_equal AbstractRequest::Status::STATUS_TO_SCOPE[AbstractRequest::Status::NOT_ANSWERED].to_s, assigns(:list_field)
    assert assigns(:mentor_request_view)
    assert_equal_hash({:label => "feature.reports.header.program_management_report".translate(program: "Program"), :link => management_report_path}, assigns(:back_link))
    assert_equal assigns(:mentor_requests).size, 1
  end

  def test_receiver_filter_for_admin
    current_user_is :f_admin

    MentorRequest.expects(:get_filtered_mentor_requests).with({"search_filters"=>{"receiver"=>"Good unique name"}, "controller"=>"mentor_requests", "action"=>"index", "root"=>nil, "sort_field"=>"id", "sort_order"=>"desc"}, { program_id: programs(:albers).id }, nil, nil).returns(MentorRequest.where(id: [12, 11, 10, 9, 8, 7, 6, 5, 4, 3]).paginate(page: 1, per_page: PER_PAGE))

    get :index, params: { :search_filters => {:receiver => "Good unique name"}}
    assert_response :success
    assert_false assigns(:mentor_request_view)
    assert_template 'index'
    assert_equal assigns(:mentor_requests).size, 10
  end

  def test_sender_filter_for_admin
    current_user_is :f_admin
    MentorRequest.expects(:get_filtered_mentor_requests).with({"search_filters"=>{"sender"=>"example"}, "controller"=>"mentor_requests", "action"=>"index", "root"=>nil, "sort_field"=>"id", "sort_order"=>"desc"}, { program_id: programs(:albers).id }, nil, nil).returns(MentorRequest.where(id: [21, 20, 18, 17, 12, 11, 10, 9, 8, 7]).paginate(page: 1, per_page: PER_PAGE))
    get :index, params: { :search_filters => {:sender => "example"}}
    assert_response :success
    assert_template 'index'
    assert_equal assigns(:mentor_requests).size, 10
  end

  def test_invalid_sender_and_valid_receiver_filter_for_admin
    current_user_is :f_admin
    MentorRequest.expects(:get_filtered_mentor_requests).with({"search_filters"=>{"sender"=>"chronus", "receiver"=>"Good unique name"}, "controller"=>"mentor_requests", "action"=>"index", "root"=>nil, "sort_field"=>"id", "sort_order"=>"desc"}, { program_id: programs(:albers).id }, nil, nil).returns(MentorRequest.where(id: []).paginate(page: 1, per_page: PER_PAGE))

    get :index, params: { :search_filters => {:sender => "chronus", :receiver => "Good unique name"}}
    assert_response :success
    assert_template 'index'
    assert_equal 0, assigns(:mentor_requests).size
  end

  def test_sender_and_receiver_filter_for_admin
    current_user_is :f_admin

    MentorRequest.expects(:get_filtered_mentor_requests).with({"search_filters"=>{"sender"=>"example", "receiver"=>"Good unique name"}, "controller"=>"mentor_requests", "action"=>"index", "root"=>nil, "sort_field"=>"id", "sort_order"=>"desc"}, { program_id: programs(:albers).id }, nil, nil).returns(MentorRequest.where(id: [12, 11, 10, 9, 8, 7, 6, 5, 4, 3]).paginate(page: 1, per_page: PER_PAGE))

    get :index, params: { :search_filters => {:sender => "example", :receiver => "Good unique name"}}
    assert_response :success
    assert_template 'index'
    assert_equal assigns(:mentor_requests).size, 10
  end

  def test_date_filter_with_receiver_and_sender_for_admin
    current_user_is :f_admin

    MentorRequest.expects(:get_filtered_mentor_requests).with({"search_filters"=>{"sender"=>"example", "receiver"=>"Good unique name", "expiry_date"=>"#{30.days.ago.strftime("%m/%d/%Y")} - #{30.days.from_now.strftime("%m/%d/%Y")}"}, "controller"=>"mentor_requests", "action"=>"index", "root"=>nil, "sort_field"=>"id", "sort_order"=>"desc"}, { program_id: programs(:albers).id }, nil, nil).returns(MentorRequest.where(id: [12, 11, 10, 9, 8, 7, 6, 5, 4, 3]).paginate(page: 1, per_page: PER_PAGE))

    get :index, params: { :search_filters => {:sender => "example", :receiver => "Good unique name", :expiry_date => "#{30.days.ago.strftime("%m/%d/%Y")} - #{30.days.from_now.strftime("%m/%d/%Y")}"}}
    assert_response :success
    assert_template 'index'
    assert_equal assigns(:mentor_requests).size, 10
  end

  def test_date_filter_for_admin
    MentorRequest.expects(:get_filtered_mentor_requests).with({"search_filters"=>{"expiry_date"=>"#{30.days.ago.strftime("%m/%d/%Y")} - #{30.days.from_now.strftime("%m/%d/%Y")}"}, "controller"=>"mentor_requests", "action"=>"index", "root"=>nil, "sort_field"=>"id", "sort_order"=>"desc"}, { program_id: programs(:albers).id }, nil, nil).returns(MentorRequest.where(id: [21, 20, 18, 17, 12, 11, 10, 9, 8, 7]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is :f_admin
    get :index, params: { :search_filters => {:expiry_date => "#{30.days.ago.strftime("%m/%d/%Y")} - #{30.days.from_now.strftime("%m/%d/%Y")}"}}
    assert_response :success
    assert_template 'index'
    assert_equal assigns(:mentor_requests).size, 10
  end

  def test_date_filter_for_admin_empty_case
    current_user_is :f_admin
    MentorRequest.expects(:get_filtered_mentor_requests).with({"search_filters"=>{"expiry_date"=>"#{60.days.ago.strftime("%m/%d/%Y")} - #{40.days.ago.strftime("%m/%d/%Y")}"}, "controller"=>"mentor_requests", "action"=>"index", "root"=>nil, "sort_field"=>"id", "sort_order"=>"desc"}, { program_id: programs(:albers).id }, nil, nil).returns(MentorRequest.where(id: []).paginate(page: 1, per_page: PER_PAGE))
    get :index, params: { :search_filters => {:expiry_date => "#{60.days.ago.strftime("%m/%d/%Y")} - #{40.days.ago.strftime("%m/%d/%Y")}"}}
    assert_response :success
    assert_template 'index'
    assert_equal assigns(:mentor_requests).size, 0
  end

  def test_list_all_requests_for_admin
    request_manage_role = create_role(:name => 'req_manager', :program => programs(:moderated_program))
    add_role_permission(request_manage_role, 'manage_mentor_requests')
    req_manager = create_user(:name => 'req_manager', :role_names => ['req_manager'], :program => programs(:moderated_program))

    current_user_is req_manager

    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :rahim)
    all_requests = programs(:moderated_program).mentor_requests

    4.times do |i|
      user = make_member_of(:moderated_program, users("student_#{i}"))
      all_requests << create_mentor_request(:student => user, :program => programs(:moderated_program))
    end

    allow_mentee_withdraw_mentor_request_for_program(programs(:moderated_program), true)

    get :index
    assert_response :success
    assert_template 'index'
    assert_select 'html'
    assert_equal programs(:moderated_program).mentoring_models, assigns[:mentoring_models]
    assert_equal 1, assigns(:page)
    assert_select "a[href=?]", groups_path(:show_new => true)

    # For a moderated program, there should be no rejected requests
    assert_select "div.filter_pane" do
      assert_select 'div.filter_box' do
        assert_select 'label.radio', :text => "Accepted"
        assert_select 'label.radio', :text => "Pending"
        assert_select "label.radio", :text => "Declined"
        assert_select "label.radio", :text => "Withdrawn"
      end
    end
  end

  def test_list_accepted_flash_when_coming_from_email_moderated_program
    request_manage_role = create_role(:name => 'req_manager', :program => programs(:moderated_program))
    add_role_permission(request_manage_role, 'manage_mentor_requests')
    req_manager = create_user(:name => 'req_manager', :role_names => ['req_manager'], :program => programs(:moderated_program))

    current_user_is req_manager

    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :rahim)
    user = make_member_of(:moderated_program, users("student_1"))
    req = create_mentor_request(:student => user, :program => programs(:moderated_program))

    req.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    allow_mentee_withdraw_mentor_request_for_program(programs(:moderated_program), true)

    get :index, params: { :src => 'email', :mentor_request_id => req.id}
    assert_response :success
    assert_equal [programs(:moderated_program).mentor_requests.first], assigns(:match_results_per_mentor).keys
    assert_equal "The request has been accepted", flash[:notice]

    get :index, params: { :src => 'ra', :mentor_request_id => req.id}
    assert_response :success
    assert_equal [programs(:moderated_program).mentor_requests.first], assigns(:match_results_per_mentor).keys
    assert_equal "The request has been accepted", flash[:notice]
  end

  def test_list_rejected_flash_when_coming_from_email_moderated_program
    User.any_instance.expects(:visible_to?).at_least(0).returns(true)
    request_manage_role = create_role(:name => 'req_manager', :program => programs(:moderated_program))
    add_role_permission(request_manage_role, 'manage_mentor_requests')
    req_manager = create_user(:name => 'req_manager', :role_names => ['req_manager'], :program => programs(:moderated_program))

    current_user_is req_manager

    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :rahim)
    user = make_member_of(:moderated_program, users("student_1"))
    req = create_mentor_request(:student => user, :program => programs(:moderated_program))

    req.update_attributes!(:status => AbstractRequest::Status::REJECTED, :rejector => req_manager)
    allow_mentee_withdraw_mentor_request_for_program(programs(:moderated_program), true)

    get :index, params: { :src => 'email', :mentor_request_id => req.id}
    assert_response :success
    assert_equal "The request has been declined", flash[:notice]

    get :index, params: { :src => 'ra', :mentor_request_id => req.id}
    assert_response :success
    assert_equal "The request has been declined", flash[:notice]
  end

  def test_list_withdrawn_flash_when_coming_from_email_moderated_program
    request_manage_role = create_role(:name => 'req_manager', :program => programs(:moderated_program))
    add_role_permission(request_manage_role, 'manage_mentor_requests')
    req_manager = create_user(:name => 'req_manager', :role_names => ['req_manager'], :program => programs(:moderated_program))

    current_user_is req_manager

    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :rahim)
    user = make_member_of(:moderated_program, users("student_1"))
    req = create_mentor_request(:student => user, :program => programs(:moderated_program))

    req.update_attributes!(:status => AbstractRequest::Status::WITHDRAWN)
    allow_mentee_withdraw_mentor_request_for_program(programs(:moderated_program), true)

    get :index, params: { :src => 'email', :mentor_request_id => req.id}
    assert_response :success
    assert_equal "The request has been withdrawn", flash[:notice]

    get :index, params: { :src => 'ra', :mentor_request_id => req.id}
    assert_response :success
    assert_equal "The request has been withdrawn", flash[:notice]
  end

  def test_list_closed_flash_when_coming_from_email_moderated_program
    request_manage_role = create_role(:name => 'req_manager', :program => programs(:moderated_program))
    add_role_permission(request_manage_role, 'manage_mentor_requests')
    req_manager = create_user(:name => 'req_manager', :role_names => ['req_manager'], :program => programs(:moderated_program))

    current_user_is req_manager

    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :rahim)
    user = make_member_of(:moderated_program, users("student_1"))
    req = create_mentor_request(:student => user, :program => programs(:moderated_program))

    req.update_attributes!(:status => AbstractRequest::Status::CLOSED, :closed_at => Time.now)

    get :index, params: { :src => 'email', :mentor_request_id => req.id}
    assert_response :success
    assert_equal "The request has been closed", flash[:notice]

    get :index, params: { :src => 'ra', :mentor_request_id => req.id}
    assert_response :success
    assert_equal "The request has been closed", flash[:notice]
  end

  def test_list_all_rejected_requests_for_admin
    current_user_is :f_admin
    accept_dummy_requests

    get :index, params: { :list => 'rejected'}
    rejected_requests = programs(:albers).mentor_requests.rejected.order(id: 'desc')
    paginated_requests = wp_collection_from_array(rejected_requests, 1)
    assert_equal paginated_requests, assigns(:mentor_requests)
  end

  def test_list_all_rejected_requests_for_admin_with_sorting
    current_user_is :f_admin
    accept_dummy_requests

    get :index, params: { :list => 'rejected', sort_field: 'id', sort_order: 'asc'}
    rejected_requests = programs(:albers).mentor_requests.rejected.order(id: 'asc')
    paginated_requests = wp_collection_from_array(rejected_requests, 1)
    assert_equal paginated_requests, assigns(:mentor_requests)
  end

  def test_list_all_withdrawn_requests_for_admin
    current_user_is :f_admin
    accept_dummy_requests

    get :index, params: { :list => 'withdrawn'}
    withdrawn_requests =  programs(:albers).mentor_requests.withdrawn
    paginated_requests =  wp_collection_from_array(withdrawn_requests, 1)
    assert_equal paginated_requests, assigns(:mentor_requests)
  end

  def test_list_all_closed_requests_for_admin
    current_user_is :f_admin
    accept_dummy_requests

    get :index, params: { :list => 'closed'}
    closed_requests =  programs(:albers).mentor_requests.closed
    paginated_requests =  wp_collection_from_array(closed_requests, 1)
    assert_equal paginated_requests, assigns(:mentor_requests)
  end

  def test_admin_can_view_listing_when_loosely_managed
    current_user_is :f_admin

    get :index
    assert_template 'index'
  end

  def test_mentor_cannot_view_listing_when_tightly_managed
    current_user_is :moderated_mentor
    assert_permission_denied { get :index }
  end

  def test_failed_mentor_request_in_index
    current_user_is :f_mentor

    mentor_request = create_mentor_request(:mentor => users(:f_mentor_student))

    get :index, params: { :failed_mentor_request_id => mentor_request.id}
    assert_equal mentor_request, assigns(:failed_mentor_request)
  end

  def test_only_the_mentor_of_the_request_can_update_request
    current_user_is :f_mentor

    mentor_request = create_mentor_request(:mentor => users(:f_mentor_student))
    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
    assert_permission_denied do
      post :update, params: { :id => mentor_request.id, :mentor_request => {:status => AbstractRequest::Status::ACCEPTED , src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}}
    end
  end

  def test_only_the_student_of_the_request_can_withdraw_request
    current_user_is :f_student
    mentor_request = create_mentor_request(:student => users(:f_mentor_student))
    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
    assert_permission_denied do
      post :update, params: { :id => mentor_request.id, :mentor_request => {:status => AbstractRequest::Status::WITHDRAWN , src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}}
    end
  end

  def test_admin_can_not_update_request_when_loosely_managed
    current_user_is :f_admin

    mentor_request = create_mentor_request
    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
    assert_permission_denied do
      post :update, params: { :id => mentor_request.id, :mentor_request => { :status => AbstractRequest::Status::ACCEPTED , src: EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE}}
    end
  end

  def test_admin_can_update_request_when_tightly_managed
    User.any_instance.expects(:visible_to?).at_least(0).returns(true)
    request_manage_role = create_role(:name => 'req_manager', :program => programs(:moderated_program))
    add_role_permission(request_manage_role, 'manage_mentor_requests')
    req_manager = create_user(:name => 'req_manager', :role_names => ['req_manager'], :program => programs(:moderated_program))

    current_user_is req_manager

    make_member_of(:moderated_program, :f_student)
    mentor_request = MentorRequest.create!(:student => users(:f_student), :message => "Hello how are you?", :program => programs(:moderated_program))

    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
    assert_emails 1 do
      post :update, params: { :id => mentor_request.id, :mentor_request => {:status => AbstractRequest::Status::REJECTED, :response_text => "Hello", src: EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE}}
    end

    assert mentor_request.reload.rejected?
    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal mentor_request.student.email, delivered_email.to[0]
    assert_match(/Request a new mentor - first_name req_manager is unavailable at this time/, delivered_email.subject)
  end

  def test_admin_reject_mentor_request_with_11_requests
    current_user_is :moderated_admin

    all_requests = []

    modify_const(:PER_PAGE, 2) do
      3.times do |i|
        user = make_member_of(:moderated_program, users("student_#{i}"))
        all_requests << create_mentor_request(:student => user, :program => programs(:moderated_program))
      end

      req = all_requests[-1]
      ei_src = EngagementIndex::Src::AcceptMentorRequest::MENTOR_REQUEST_LISTING_PAGE
      @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
      assert_no_difference 'Group.count' do
        post :update, params: { :id => req.id, :mentor_request => {:status => AbstractRequest::Status::REJECTED.to_s, :response_text => "Sorry", src: EngagementIndex::Src::AcceptMentorRequest::MENTOR_REQUEST_LISTING_PAGE}, :page => 2}
      end

      assert_redirected_to mentor_requests_path(:page => 2)
      assert_equal "Thank you for your response. #{req.student.name} has been notified.", flash[:notice]
      assert_equal "Sorry", req.reload.response_text

      req_1 = all_requests[-2]
      ei_src = EngagementIndex::Src::AcceptMentorRequest::MENTOR_REQUEST_LISTING_PAGE
      @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
      assert_no_difference 'Group.count' do
        post :update, params: { :id => req_1.id, :mentor_request => {:status => AbstractRequest::Status::REJECTED.to_s, :response_text => "Sorry", src: EngagementIndex::Src::AcceptMentorRequest::MENTOR_REQUEST_LISTING_PAGE}, :page => 2}
      end

      assert_redirected_to mentor_requests_path(:page => 1)
      assert_equal "Thank you for your response. #{req_1.student.name} has been notified.", flash[:notice]
      assert_equal "Sorry", req_1.reload.response_text
    end
  end


  def test_accept_mentor_request_fail_when_user_opts_only_one_time_mentoring
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)

    mentor_request = create_mentor_request
    users(:f_mentor).update_attributes!(mentoring_mode: User::MentoringMode::ONE_TIME)

    assert_no_difference 'Group.count' do
      post :update, params: { :id => mentor_request.id,
        :mentor_request => {
        :status => AbstractRequest::Status::ACCEPTED,
        src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE }
      }
    end

    assert_redirected_to(mentor_requests_path(page: 1))
    assert_equal "You have opted out of mentoring connection. Please opt in for mentoring connection to accept the request", flash[:error]
  end

  def test_accept_mentor_request
    current_user_is :f_mentor

    mentor_request = create_mentor_request

    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).once
    assert_difference 'Group.count' do
      post :update, params: { :id => mentor_request.id,
        :mentor_request => {
        :status => AbstractRequest::Status::ACCEPTED,
        src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
      }}
    end

    group = Group.last
    assert_redirected_to group_path(group, src: EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST)
  end

  def test_accept_mentor_request_adds_to_existing_connection
    allow_one_to_many_mentoring_for_program(programs(:albers))
    current_user_is :f_mentor

    mentor_request = create_mentor_request

    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).once
    assert_no_difference 'Group.count' do
      assert_difference "Connection::MenteeMembership.count" do
        post :update, params: { :id => mentor_request.id,
          :mentor_request => {
          :status => AbstractRequest::Status::ACCEPTED,
          :group_id => groups(:mygroup),
          src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
        }}
      end
    end

    assert_redirected_to group_path(groups(:mygroup), src: EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST)
  end

  def test_reject_mentor_request
    current_user_is :f_mentor

    mentor_request = create_mentor_request

    # Intentionally sending the status as a string, which is close to real world
    # usage.
    ei_src = EngagementIndex::Src::AcceptMentorRequest::MENTOR_REQUEST_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
    assert_no_difference 'Group.count' do
      post :update, params: { :id => mentor_request.id,
        :mentor_request => {
        :status => AbstractRequest::Status::REJECTED.to_s,
        :response_text => "Sorry",
        src: EngagementIndex::Src::AcceptMentorRequest::MENTOR_REQUEST_LISTING_PAGE
      }}
    end
    assert_redirected_to mentor_requests_path(:page => 1)
    assert_equal "Thank you for your response. #{mentor_request.student.name} has been notified.", flash[:notice]
    assert_equal "Sorry", MentorRequest.last.response_text
  end

  def test_reject_mentor_request_from_user_profile_page
    session[:last_visit_url] = '/'
    current_user_is :f_mentor
    mentor_request = create_mentor_request
    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
    assert_no_difference 'Group.count' do
      post :update, params: { :id => mentor_request.id,
        :mentor_request => {
        :status => AbstractRequest::Status::REJECTED.to_s,
        :response_text => "Sorry",
        :src => EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
      }}
    end
    assert_redirected_to '/'
    assert_equal "Thank you for your response. #{mentor_request.student.name} has been notified.", flash[:notice]
    assert_equal "Sorry", MentorRequest.last.response_text
  end

  def test_reject_mentor_request_from_user_listing_page
    session[:last_visit_url] = '/'
    current_user_is :f_mentor
    mentor_request = create_mentor_request
    ei_src = EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, {:context_place => ei_src}).never
    assert_no_difference 'Group.count' do
      post :update, params: { :id => mentor_request.id,
        :mentor_request => {
        :status => AbstractRequest::Status::REJECTED.to_s,
        :response_text => "Sorry",
        :src => EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE
      }}
    end
    assert_redirected_to '/'
    assert_equal "Thank you for your response. #{mentor_request.student.name} has been notified.", flash[:notice]
    assert_equal "Sorry", MentorRequest.last.response_text
  end

  def test_close_mentor_request
    Timecop.freeze(Time.now) do
      mentor_requests = []
      mentor_requests << create_mentor_request
      mentor_requests << create_mentor_request(mentor: users(:mentor_0), student: users(:student_0), status: AbstractRequest::Status::ACCEPTED)
      mentor_requests << create_mentor_request(mentor: users(:mentor_1), student: users(:student_1), status: AbstractRequest::Status::REJECTED)
      mentor_requests << create_mentor_request(mentor: users(:mentor_2), student: users(:student_2), status: AbstractRequest::Status::WITHDRAWN)
      closed_mentor_request = create_mentor_request(mentor: users(:mentor_3), student: users(:student_3))
      closed_mentor_request.close_request!
      mentor_requests << closed_mentor_request

      admin = users(:f_admin)
      current_user_is admin
      assert_emails 1 do
        post :update_bulk_actions, params: { bulk_actions: { request_type: AbstractRequest::Status::CLOSED, mentor_request_ids: mentor_requests.collect(&:id).join(" ") },
          mentor_request: { response_text: "Sorry" }, sender: true
        }
      end

      assert_redirected_to mentor_requests_path
      assert_equal "The selected request has been closed.", flash[:notice]
      recently_closed_mentor_request = mentor_requests[0].reload
      assert_equal "Sorry", recently_closed_mentor_request.response_text
      assert_equal AbstractRequest::Status::CLOSED, mentor_requests[0].status
      assert_equal AbstractRequest::Status::ACCEPTED, mentor_requests[1].reload.status
      assert_equal AbstractRequest::Status::REJECTED, mentor_requests[2].reload.status
      assert_equal AbstractRequest::Status::WITHDRAWN, mentor_requests[3].reload.status
      assert_equal AbstractRequest::Status::CLOSED, mentor_requests[4].reload.status
      assert_equal admin, recently_closed_mentor_request.closed_by
      assert_equal Time.now.utc.to_s, recently_closed_mentor_request.closed_at.utc.to_s
    end
  end

  def test_close_mentor_request_only_by_admin
    current_user_is :f_mentor

    mentor_request = create_mentor_request

    assert_permission_denied  do
      post :update_bulk_actions, xhr: true, params: { :bulk_actions => {:request_type => AbstractRequest::Status::CLOSED, :mentor_request_ids => [mentor_request.id]}, :mentor_request => {:response_text => "Sorry"}, :sender => true}
    end
  end

  def test_mentor_requests_listing_for_admin_only
    make_member_of :moderated_program, :f_student
    request_manage_role = create_role(:name => 'req_manager', :program => programs(:moderated_program))
    add_role_permission(request_manage_role, 'manage_mentor_requests')
    programs(:moderated_program).reload
    req_manager = create_user(:name => 'req_manager', :role_names => ['req_manager'], :program => programs(:moderated_program))

    current_user_is req_manager

    get :index
    assert_response :success

    assert_equal assigns(:mentor_requests).count, 1
  end

  def test_mentor_requests_listing_for_admin_mentor_viewing_all
    current_user_is :f_admin
    users(:f_admin).add_role(RoleConstants::MENTOR_NAME)
    assert users(:f_admin).is_mentor?

    create_mentor_request(:mentor => users(:f_admin))

    assert_equal 21, programs(:albers).mentor_requests.count

    get :index, params: { :filter => AbstractRequest::Filter::ALL}
    assert_response :success

    assert_equal 10, assigns(:mentor_requests).size
  end

  def test_mentor_student_matches_for_admin
    current_program_is :moderated_program
    current_user_is :moderated_admin

    get :index, params: { :filter => AbstractRequest::Filter::ALL}
    assert_response :success
  end

  def test_mentor_student_matches_for_student
    current_user_is :moderated_student
    student = users(:f_student)
    MentorRequest.any_instance.stubs(:student).returns(student)
    student.expects(:student_cache_normalized)

    get :index, params: { filter: AbstractRequest::Filter::BY_ME}
    assert_response :success
  end

  def test_should_not_create_duplicate_request_to_the_same_mentor
    p = programs(:albers)
    mentor_term = p.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term
    mentor_term.term = "Advisor"
    mentor_term.term_downcase = "advisor"
    mentor_term.save!

    current_user_is :f_student
    mentor = users(:f_mentor)
    mentor.received_mentor_requests.active.destroy_all
    mentor.update_attribute(:max_connections_limit, 5)
    create_mentor_request(:student => users(:f_student),:mentor => users(:f_mentor),:program => programs(:albers))

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REQUEST_ADMIN_MATCH).never
    assert_no_difference('MentorRequest.count') do
      post :create, params: { :mentor_request => {
        :receiver_id => users(:f_mentor).id,
        :message => "Hello"
      }}
    end

    assert_redirected_to(member_path(members(:f_mentor)))
    assert_equal("You have already sent a request to this advisor.", flash[:error])
  end

  def test_select_all_ids_permission_denied
    current_user_is :moderated_mentor
    assert_permission_denied { get :select_all_ids }
  end

  def test_select_all_ids_no_filter_params
    current_user_is :f_admin
    active_requests = programs(:albers).mentor_requests.active

    get :select_all_ids
    assert_response :success
    assert_equal 'active', assigns(:list_field)
    assert_nil assigns(:start_time)
    assert_nil assigns(:end_time)
    assert_equal 'all', assigns(:filter_field)
    assert_equal true, assigns(:is_request_manager_view_of_all_requests)
    assert_equal [], assigns(:my_filters)
    assert_equal assigns(:filter_params), {:filter=>nil, :list=>nil, :search_filters=>nil}
    assert assigns(:mentor_requests)
    assert_equal_unordered active_requests.collect(&:id).map(&:to_s), JSON.parse(response.body)["mentor_request_ids"]
    assert_equal_unordered active_requests.collect(&:sender_id), JSON.parse(response.body)["sender_ids"]
    assert_equal_unordered active_requests.collect(&:receiver_id), JSON.parse(response.body)["receiver_ids"]
  end

  def test_select_all_ids_with_filter_params
    MentorRequest.expects(:get_filtered_mentor_requests).with({"search_filters"=>{"receiver"=>"Good unique name"}, "controller"=>"mentor_requests", "action"=>"select_all_ids", "root"=>nil, "sort_field"=>"id", "sort_order"=>"desc"}, { program_id: programs(:albers).id }, true, ["id", "sender_id", "receiver_id"]).returns([Elasticsearch::Model::HashWrapper.new(id: 12, receiver_id: 3, sender_id: 20), Elasticsearch::Model::HashWrapper.new(id: 11, receiver_id: 3, sender_id: 19), Elasticsearch::Model::HashWrapper.new(id: 10, receiver_id: 3, sender_id: 18), Elasticsearch::Model::HashWrapper.new(id: 9, receiver_id: 3, sender_id: 17), Elasticsearch::Model::HashWrapper.new(id: 8, receiver_id: 3, sender_id: 16), Elasticsearch::Model::HashWrapper.new(id: 7, receiver_id: 3,sender_id: 15), Elasticsearch::Model::HashWrapper.new(id: 6, receiver_id: 3, sender_id: 14),Elasticsearch::Model::HashWrapper.new(id: 5, receiver_id: 3, sender_id: 13), Elasticsearch::Model::HashWrapper.new(id: 4, receiver_id: 3, sender_id: 12), Elasticsearch::Model::HashWrapper.new(id: 3, receiver_id: 3, sender_id: 11), Elasticsearch::Model::HashWrapper.new(id: 2, receiver_id: 3,sender_id: 10)])

    current_user_is :f_admin
    active_requests = programs(:albers).mentor_requests.active.to_mentor(users(:f_mentor))
    get :select_all_ids, params: { :search_filters => {:receiver => "Good unique name"}}
    assert_response :success
    assert_equal 'active', assigns(:list_field)
    assert_nil assigns(:start_time)
    assert_nil assigns(:end_time)
    assert_equal 'all', assigns(:filter_field)
    assert_equal true, assigns(:is_request_manager_view_of_all_requests)
    assert_equal [{:label=>"Receiver", :reset_suffix=>"receiver"}], assigns(:my_filters)
    expected_hash = {:filter=>nil, :list=>nil, :search_filters=>{"receiver"=>"Good unique name"}}
    assert assigns(:filter_params)
    assert assigns(:mentor_requests)
    assert_equal_unordered active_requests.pluck(:id).map(&:to_s), JSON.parse(response.body)["mentor_request_ids"]
    assert_equal_unordered active_requests.pluck(:sender_id), JSON.parse(response.body)["sender_ids"]
    assert_equal_unordered active_requests.pluck(:receiver_id), JSON.parse(response.body)["receiver_ids"]
  end

  def test_select_all_ids_no_manager
    current_user_is :f_mentor
    get :select_all_ids
    assert_nil assigns(:mentor_requests)
    assert_equal_unordered [], JSON.parse(response.body)["mentor_request_ids"]
    assert_equal_unordered [], JSON.parse(response.body)["sender_ids"]
    assert_equal_unordered [], JSON.parse(response.body)["receiver_ids"]
  end

  def test_mentor_requests_view_title
    current_user_is :f_admin
    program = programs(:albers)

    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_CONNECTION_REQUESTS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending mentoring requests", abstract_view_id: view.id)

    get :manage, params: { :metric_id => metric.id}
    assert_response :success

    assert_not_nil assigns(:metric)
    assert_page_title(metric.title)
  end

  def test_manage_permission_denied
    current_user_is :f_mentor

    assert_permission_denied do
      get :manage
    end
  end

  def test_manage_success
    current_user_is :f_admin
    active_requests = programs(:albers).mentor_requests.active.order(id: 'desc')
    pending = active_requests.count
    assert_equal 15, pending
    paginated_requests = wp_collection_from_array(active_requests, 1)

    received = programs(:albers).mentor_requests.count
    assert_equal 20, received

    accepted = programs(:albers).mentor_requests.accepted.count
    assert_equal 0, accepted

    other = received - (pending+accepted)

    get :manage
    assert_response :success

    assert_nil assigns(:metric)
    assert_nil assigns(:src_path)
    assert_nil assigns(:export_format)
    assert_nil assigns(:mentor_request_view)
    assert_equal programs(:albers).mentoring_models, assigns[:mentoring_models]   
    assert_equal 1, assigns(:page)
    assert_equal "feature.mentor_request.header.mentor_requests_v1".translate(:Mentoring => _Mentoring), assigns(:title)
    assert_equal paginated_requests, assigns(:mentor_requests)
    assert_nil assigns(:match_results_per_mentor)
    assert_equal "id", assigns(:action_params)[:sort_field]
    assert_equal "desc", assigns(:action_params)[:sort_order]
    assert_nil assigns(:action_params)[:search_filters][:expiry_date]
    assert_equal_hash({received: received, pending: pending, accepted: accepted, other: other, percentage: nil, prev_periods_count: 0}, assigns(:tiles_data))
  end

  def test_manage_filters
    current_user_is :f_admin
    get :manage, params: { date_range: "#{30.days.ago.strftime("%m/%d/%Y")} - #{30.days.from_now.strftime("%m/%d/%Y")}"}
    assert_response :success
    assert_equal 10, assigns(:mentor_requests).size

    get :manage, params: { search_filters: {sender: "example", receiver: "Good unique name"}, date_range: "#{30.days.ago.strftime("%m/%d/%Y")} - #{30.days.from_now.strftime("%m/%d/%Y")}"}
    assert_response :success
    assert_equal 10, assigns(:mentor_requests).size

    get :manage, xhr: true, params: { date_range: "#{60.days.ago.strftime("%m/%d/%Y")} - #{40.days.ago.strftime("%m/%d/%Y")}"}
    assert_response :success
    assert_equal 0, assigns(:mentor_requests).size
  end

  def test_manage_match_results_per_mentor
    request_manage_role = create_role(:name => 'req_manager', :program => programs(:moderated_program))
    add_role_permission(request_manage_role, 'manage_mentor_requests')
    req_manager = create_user(:name => 'req_manager', :role_names => ['req_manager'], :program => programs(:moderated_program))
    current_user_is req_manager

    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :rahim)
    user = make_member_of(:moderated_program, users("student_1"))
    req = create_mentor_request(:student => user, :program => programs(:moderated_program))

    req.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    allow_mentee_withdraw_mentor_request_for_program(programs(:moderated_program), true)

    get :manage
    assert_response :success
    assert_equal [programs(:moderated_program).mentor_requests.first], assigns(:match_results_per_mentor).keys
  end

  def test_manage_tiles_data
    current_user_is :f_admin

    get :manage
    assert_response :success
    assert_equal_hash({received: 20, pending: 15, accepted: 0, other: 5, percentage: nil, prev_periods_count: 0}, assigns(:tiles_data))

    get :manage, params: { date_range: "#{5.days.ago.strftime("%m/%d/%Y")} - #{5.days.from_now.strftime("%m/%d/%Y")}"}
    assert_response :success
    assert_equal_hash({received: 20, pending: 15, accepted: 0, other: 5, percentage: 100, prev_periods_count: 0}, assigns(:tiles_data))

    get :manage, params: { date_range: "#{5.days.from_now.strftime("%m/%d/%Y")} - #{15.days.from_now.strftime("%m/%d/%Y")}"}
    assert_response :success
    assert_equal_hash({received: 0, pending: 0, accepted: 0, other: 0, percentage: -100, prev_periods_count: 20}, assigns(:tiles_data))
  end

  def test_manage_export
    current_user_is :f_admin

    assert_emails 1 do
      get :manage, xhr: true, params: { export: "pdf"}
    end
    assert_response :success
    assert_equal :pdf, assigns(:export_format)
    assert_equal_unordered programs(:albers).mentor_requests.active.pluck(:id), assigns(:mentor_requests_ids).collect(&:to_i)
  end

  def test_instruction_with_tags
    current_user_is :moderated_student
    instruction = programs(:moderated_program).mentor_request_instruction
    instruction.update_attribute(:content, "Test <em>italic</em><u>underline</u><strong>Bold</strong>")

    get :new
    assert_response :success
    assert_match "Test <em>italic</em><u>underline</u><strong>Bold</strong>",response.body
    assert_select "div.ckeditor_generated"
  end

  private

  def accept_dummy_requests
    mentor = users(:f_mentor)
    mentor.update_attribute :max_connections_limit, 4
    assert_equal 4, mentor.max_connections_limit

    accepted_requests = []

    # Accept or decline some of the requests.
    (3...6).each do |i|
      mentor_request = mentor_requests("mentor_request_#{i}")
      mentor_request.mark_accepted!
      accepted_requests << mentor_request
    end

    return accepted_requests
  end

  def _Mentoring
    "Mentoring"
  end

  def _mentoring
    "mentoring"
  end

  def _Mentors
    "Mentors"
  end

  def _Mentor
    "Mentor"
  end
end