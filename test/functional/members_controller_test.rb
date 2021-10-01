require_relative './../test_helper.rb'

class MembersControllerTest < ActionController::TestCase

  def test_auth_denied_when_there_is_no_permission_to_view_mentor_profile
    current_user_is :f_student
    fetch_role(:albers, :student).remove_permission('view_mentors')
    assert_permission_denied do
      get :show, params: { :id => members(:f_mentor).id}
    end
  end

  def test_auth_denied_when_there_is_no_permission_to_view_mentee_profile
    current_user_is :f_student
    fetch_role(:albers, :student).remove_permission('view_students')
    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:f_student))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:student_3).id}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    assert_permission_denied do
      get :show, params: { :id => members(:student_3).id}
    end
  end

  def test_active_record_action_not_found
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, context_place: nil, context_object: 0).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    current_user_is :f_mentor_student
    Rails.application.config.consider_all_requests_local = false
    assert_record_not_found do
      get :show, params: { id: 0}
      assert_status 404
      assert_template "#{Rails.root}/public/404.html"
    end
    Rails.application.config.consider_all_requests_local = true
  end

  def test_mentor_profile_should_not_render_favorite_mentor_for_self_when_mentor_student_tightly
    make_member_of(:moderated_program, :f_mentor_student)
    current_user_is :f_mentor_student
    programs(:moderated_program).enable_feature(FeatureName::CALENDAR)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    get :show, params: { :id => members(:f_mentor_student).id}

    assert_select "div.profile_status_box"
    assert_select "a", text: "Add to preferred mentors", count: 0
  end

  def test_can_view_dormant_member_for_standalone_program
    current_member_is :no_subdomain_admin
    member = members(:dormant_member)
    assert programs(:org_no_subdomain).standalone?
    assert member.dormant?
    assert_false member.users.any?
    get :show, params: { :id => member.id}
    assert_response :success
  end

  def test_view_profile_of_dormant_member_for_standalone_program
    current_member_is :no_subdomain_admin
    member = members(:dormant_member)
    User.any_instance.stubs(:can_see_match_details?).returns(true)
    User.any_instance.stubs(:is_student?).returns(true)
    get :show, params: { :id => member.id }
    assert_response :success
  end

  def test_can_view_dormant_member_at_organization_level
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    member = members(:f_mentor)
    member.update_attribute(:state, Member::Status::DORMANT)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => member.id}
    assert_response :success
    assert_match UserPromotedToAdminNotification.mailer_attributes[:uid], response.body
  end

  def test_view_other_student_profile
    current_user_is :rahim
    user = users(:f_student)
    question_1 = create_qa_question
    create_qa_question
    create_qa_answer(:qa_question => question_1)
    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_student).id}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => user.member.id}
    assert_response :success
    assert_false assigns(:show_meetings)
    assert_false assigns(:show_articles)
    assert_false assigns(:show_connect)
    assert assigns(:show_answers)
    assert_false assigns(:show_connections)
    assert_template 'show'
    assert_no_select "div.profile_status_box"

    student_more_info_section = programs(:org_primary).sections.find_by(title: "More Information")
    programs(:albers).reload
    assert_select "div#mentor_profile" do
      assert_select "div#program_role_info" do
        assert_select "div.ibox", :count => 4

        assert_select "div.ibox:nth-of-type(1)" do
          assert_select "div.ibox-title", :text => /Basic Information/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => 1
          end
        end
        assert_select "div.ibox:nth-of-type(2)" do
          assert_select "div.ibox-title", :text => /Work and Education/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => 2
          end
        end
        assert_select "div.ibox:nth-of-type(3)" do
          assert_select "div.ibox-title", :text => /Mentoring Profile/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => sections(:sections_3).profile_questions.size - 3 #Exclude 2 mentor questions of the section that will not be shown
          end
        end
        assert_select "div.ibox:nth-of-type(4)" do
          assert_select "div.ibox-title", :text => /More Information Students/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => student_more_info_section.profile_questions.size - 2#Exclude 2 mentor questions of the section that will not be shown
          end
        end
      end
    end

  end

  def test_non_only_admin_track_profile_view
    viewed_by = users(:f_student)
    current_user_is viewed_by
    user = users(:f_mentor)
    assert_difference "ProfileView.count", 1 do
      get :show, params: { id: user.id}
    end
    assert_equal user, assigns(:profile_user)
    profile_view = ProfileView.last
    assert_equal viewed_by, profile_view.viewed_by
    assert_equal user, profile_view.user
  end

  def test_only_admin_dont_track_profile_view
    viewed_by = users(:f_admin)
    current_user_is viewed_by
    user = users(:f_mentor)
    assert_no_difference "ProfileView.count" do
      get :show, params: { id: user.id}
    end
  end

  def test_mentor_can_see_respond_to_request_in_student_profile
    mentor = users(:f_mentor)
    program = mentor.program
    mentor_request = create_mentor_request(student: users(:rahim), mentor: mentor, message: 'good')
    program.update_attributes(allow_one_to_many_mentoring: true)

    current_user_is mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { id: users(:rahim)}
    assert_match(/Accept/, response.body)
    assert_select "a", text: "Accept"
    assert_select "a", text: "Decline"
    profile_user = assigns(:profile_user)
    assert profile_user
    assert_false (Group.involving(profile_user, users(:f_mentor)).published.first || Group.involving(users(:f_mentor), profile_user).published.first)
    assert users(:f_mentor).is_mentor?
    assert profile_user.is_student?
    assert assigns(:current_program).matching_by_mentee_alone?
    assert_equal mentor_request, users(:f_mentor).pending_mentor_request_of?(profile_user)
  end

  def test_edit_member_not_part_of_program
    current_user_is :no_subdomain_admin
    current_program_is :no_subdomain

    @controller.instance_variable_set(:@profile_member, members(:dormant_member))
    @controller.expects(:fetch_profile_member).once
    assert_record_not_found do
      get :edit, params: { id: members(:dormant_member).id}
    end
  end

  def test_admin_and_mentor_can_not_see_respond_to_request_in_student_profile_edit
    current_user_is :ram
    m1 = create_mentor_request(:student => users(:rahim),
      :mentor => users(:ram), :message => 'good')
    programs(:albers).update_attributes(allow_one_to_many_mentoring: true)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never
    get :edit, params: { :id => users(:rahim)}
    assert_no_match(/Respond\ to\ request/, response.body)
    assert_select "a", text: "Accept", count: 0
    assert_select "a", text: "Decline", count: 0
    profile_user = assigns(:profile_user)
    assert profile_user

    assert_false (Group.involving(profile_user, users(:f_mentor)).published.first || Group.involving(users(:f_mentor), profile_user).published.first)
    assert assigns(:current_program).matching_by_mentee_alone?
    assert_equal m1, users(:ram).pending_mentor_request_of?(profile_user)
  end

  def test_view_suspended_member_profile
    current_member_is :anna_univ_admin
    member = members(:inactive_user)
    create_meeting_request(:mentor => users(:inactive_user), :student => users(:psg_student1), :status => AbstractRequest::Status::NOT_ANSWERED)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { id: member.id}
    assert_response :success
    assert_equal "#{member.name}'s membership has been suspended and their access has been revoked from all the programs they were part of.", flash[:error]
  end

  def test_view_suspended_member_profile_in_program_level
    current_user_is :psg_admin
    member = members(:inactive_user)
    create_meeting_request(:mentor => users(:inactive_user), :student => users(:psg_student1), :status => AbstractRequest::Status::NOT_ANSWERED)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { id: member.id}
    assert_response :success
    assert_match "#{member.name}'s membership has been suspended and their access has been revoked from all the programs they were part of.", flash[:error]
    assert_match /Please .*click here.* to reactivate the user's profile in #{member.organization.name}./, flash[:error]
  end

  def test_view_suspended_member_profile_in_program_level_by_program_admin
    current_user_is :ram
    member = members(:f_student)
    member.suspend!(members(:f_admin), "Suspension Reason")
    create_meeting_request(:mentor => users(:ram), :student => users(:f_student), :status => AbstractRequest::Status::NOT_ANSWERED)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_student).id}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { id: member.id}
    assert_response :success
    assert_match "#{member.name}'s membership has been suspended and their access has been revoked from all the programs they were part of.", flash[:error]
    assert_no_match(/Please .*click here.* to reactivate the user's profile in #{member.organization.name}./, flash[:error])
  end

  def test_user_with_pending_profile_should_update_last_seen_at
    current_user_is users(:pending_user)
    @controller.expects(:update_last_seen_at)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => members(:pending_user).id}
  end

  def test_view_self_student_profile
    org = programs(:org_primary)
    org.enable_feature(FeatureName::SKYPE_INTERACTION)
    org.enable_feature(FeatureName::CALENDAR)
    current_user_is :f_student
    create_mentor_offer(:student => users(:f_student), :mentor => users(:f_mentor))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => users(:f_student).id}
    assert_response :success
    assert_template 'show'
    assert_equal users(:f_student), assigns(:profile_user)
    assert_false assigns(:show_connect)
    assert_select "a[href=?]", edit_member_path(members(:f_student), ei_src: EngagementIndex::Src::EditProfile::PROFILE_ACTION_BUTTON)
    assert_select "div.profile_status_box"
    assert_tab TabConstants::HOME

    assert assigns(:show_meetings)
    assert_not_nil assigns(:pdf_name)
    assert_false assigns(:show_articles)
    assert assigns(:show_answers)
    assert_false assigns(:show_connections)
  end

  def test_viewing_student_self_profile_on_questions_change_should_render_profile_update_prompt
    current_user_is :f_student
    ProfileQuestion.skip_timestamping do
      3.times { create_student_question(:created_at => 2.days.ago, :updated_at => 2.days.ago) }
    end

    ProfileAnswer.skip_timestamping do
      ProfileAnswer.create(:ref_obj => members(:f_student), :profile_question => ProfileQuestion.last, :answer_text => "and", :created_at => 1.day.ago, :updated_at => 1.day.ago)
    end
    # Create a dumy question to trigger profile update prompt
    create_student_question
    create_mentor_offer(:mentor => users(:ram), :student => users(:f_student))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_student).id}).never
    get :show, params: { :id => members(:f_student).id}
    assert_response :success
    assert_template 'show'
    assert_equal users(:f_student), assigns(:profile_user)
    # The questions are recen(t. So, there should be a profile update prompt
    assert_no_select "div#profile_update"
  end

  def test_viewing_student_self_profile_on_questions_change_wont_render_new_profile_quesiton_prompt
    current_user_is :f_student
    create_student_question(:required => 1)
    programs(:albers).reload
    users(:f_student).reload
    create_mentor_offer(:mentor => users(:ram), :student => users(:f_student))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_student).id}).never
    get :show, params: { :id => members(:f_student).id}
    assert_redirected_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
  end

  def test_viewing_mentor_self_profile_on_questions_change_should_not_render_profile_update_prompt
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    current_user_is :f_mentor
    ProfileQuestion.skip_timestamping do
      3.times { create_mentor_question(:created_at => 2.days.ago, :updated_at => 2.days.ago) }
    end
    ProfileAnswer.skip_timestamping do
      ProfileAnswer.create(:ref_obj => members(:f_mentor), :profile_question => ProfileQuestion.last, :answer_text => "and", :created_at => 1.day.ago, :updated_at => 1.day.ago)
    end
    # Create a dumy question to trigger profile update prompt
    create_mentor_question

    create_meeting_request(:mentor => users(:f_mentor), :student => users(:f_student), :status => AbstractRequest::Status::NOT_ANSWERED)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_mentor).id}).never
    get :show, params: { id: members(:f_mentor).id, favorite_user_ids: [1,3] }
    assert_response :success
    assert_template 'show_mentor'
    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_false assigns(:show_favorite_ignore_links)
    assert_equal ["1", "3"], assigns(:favorite_user_ids)
    # The questions are recent. So, there should be a profile update prompt
    assert_no_select "div#profile_update"
  end

  def test_viewing_mentor_self_profile_on_questions_change_should_not_render_profile_update_prompt_name_changed
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :f_mentor
    create_mentor_question(:required => 1)
    programs(:albers).reload
    users(:f_mentor).reload
    create_meeting_request(:mentor => users(:f_mentor), :student => users(:f_student), :status => AbstractRequest::Status::NOT_ANSWERED)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_mentor).id}).never

    get :show, params: { :id => members(:f_mentor).id}
    assert_redirected_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
  end

  def test_admin_viewing_an_unpublished_profile
    current_user_is :f_admin

    ProfileQuestion.skip_timestamping do
      3.times { create_mentor_question(:created_at => 2.days.ago, :updated_at => 2.days.ago) }
    end
    ProfileAnswer.skip_timestamping do
      ProfileAnswer.create(:ref_obj => members(:pending_user), :profile_question => ProfileQuestion.last, :answer_text => "and", :created_at => 1.day.ago, :updated_at => 1.day.ago)
    end
    # Create a dumy question to trigger profile update prompt
    create_mentor_question
    create_meeting_request(:mentor => users(:pending_user), :student => users(:f_student), :status => AbstractRequest::Status::NOT_ANSWERED)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:pending_user).id}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:pending_user).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_false assigns(:show_favorite_ignore_links)
    assert_equal users(:pending_user), assigns(:profile_user)
    assert_equal "The member has not yet published their profile", flash[:error]
    assert_nil assigns(:favorite_user_ids)
  end

  def test_student_viewing_an_unpublished_profile
    current_user_is :f_student

    create_mentor_offer(:mentor => users(:pending_user), :student => users(:f_student))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:pending_user).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:pending_user).id}
    assert_response :success
  end

  def test_admin_should_be_able_to_view_of_student_profile_and_should_not_see_profile_update_prompt
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    current_user_is :f_admin
    3.times { create_student_question }

    create_mentor_offer(:mentor => users(:pending_user), :student => users(:f_student))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_student).id}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_student).id}
    assert_response :success
    assert_template 'show'
    assert_equal users(:f_student), assigns(:profile_user)

    assert_select 'div#sidebarRight' do
      assert_select 'div#admin_actions'
    end

    # There should be no profile update prompt
    assert_select "div.completion_stats", 0
    assert_false assigns(:show_meetings)
    assert_false assigns(:show_articles)
    assert assigns(:show_answers)
    assert assigns(:show_connections)
    assert_false assigns(:show_tags)
    assert_false assigns(:show_favorite_ignore_links)
  end

  def test_non_student_view_of_mentor_profile_who_has_not_requested_yet
    current_user_is :rahim

    # rahim is not a student of the mentor
    assert !users(:f_mentor).students.include?(users(:rahim))

    # No requests yet from rahim to f_mentor
    assert users(:f_mentor).received_mentor_requests.from_student(users(:rahim)).empty?

    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_mentor).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert !assigns(:show_email)
    assert_no_select "Request Mentoring Connection"
    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_tab @controller._Mentors
  end

  def test_non_student_view_of_mentor_profile_who_has_not_requested_yet_with_higher_max_connection_limit
    current_user_is :rahim
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)

    # rahim is not a student of the mentor
    assert !users(:f_mentor).students.include?(users(:rahim))

    # No requests yet from rahim to f_mentor
    assert users(:f_mentor).received_mentor_requests.from_student(users(:rahim)).empty?
    users(:f_mentor).update_attribute(:max_connections_limit, 15)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_mentor).id}).once

    get :show, params: { :id => members(:f_mentor).id, src: EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE}
    assert_response :success
    assert_template 'show_mentor'
    assert !assigns(:show_email)
    assert assigns(:show_favorite_ignore_links)
    assert_equal_hash({users(:ram).id=>abstract_preferences(:favorite_2).id}, assigns(:favorite_preferences_hash))
    assert_equal_hash({users(:robert).id=>abstract_preferences(:ignore_2).id}, assigns(:ignore_preferences_hash))
    assert_select "a[data-url=\"/p/albers/mentor_requests/new.js?mentor_id=3&src=#{EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE}\"]", :text => "Request Mentoring Connection"
    assert_select "a[href=\"javascript:void(0)\"]", :text => "Request Mentoring Connection"
    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_tab @controller._Mentors
  end

  def test_non_student_view_of_mentor_profile_whose_request_is_pending
    current_user_is :rahim
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.update_attribute(:mentor_offer_needs_acceptance, true)

    # rahim is not a student of the mentor
    assert !users(:f_mentor).students.include?(users(:rahim))

    mentor_request = create_mentor_request(:student => users(:rahim),:mentor => users(:f_mentor))
    mentor_offer = create_mentor_offer(:student => users(:rahim),:mentor => users(:f_mentor))

    # rahim has already requested f_mentor for mentorship.
    assert_equal [mentor_request],
      users(:f_mentor).reload.received_mentor_requests.from_student(users(:rahim))

    assert_equal AbstractRequest::Status::NOT_ANSWERED, mentor_request.status
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_mentor).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert !assigns(:show_email)

    # Pending request disabled button
    assert_select "a", :text => "View your pending request"
    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_tab @controller._Mentors
  end

  def test_student_view_of_mentor_profile
    time = Time.now
    Time.stubs(:now).returns(time)
    current_user_is :rahim
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)

    group = create_group(:students => [users(:rahim)], :mentor => users(:f_mentor), :program => programs(:albers))

    User.any_instance.stubs(:is_capacity_reached_for_current_and_next_month?).returns([false, ""])
    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_mentor).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id, src: EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE}
    assert_response :success
    back_link = {"label"=>"groups", "link"=>"/"}
    assert_nil assigns[:back_link]
    assert_template 'show_mentor'
    assert assigns(:show_connect)
    assert_select "a[href=?]", group_path(group), text: "Go to #{group.name}"

    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_select "div#left_pane" do
      assert_select "a[href=\"/p/albers/messages/new?receiver_id=3&src=#{EngagementIndex::Src::MessageUsers::USER_PROFILE_PAGE}\"]", :text => "Send Message"
      assert_select "a[href=\"/p/albers/groups/#{group.id}\"]", :text => "Go to #{group.name}"
      assert_select "a[data-click=\"Meetings.renderMiniPopup('/p/albers/meetings/mini_popup?member_id=3&src=#{EngagementIndex::Src::MessageUsers::USER_PROFILE_PAGE}')\"]", :text => /Request Meeting/
    end

    mentor_more_info_section = programs(:org_primary).sections.find_by(title: "More Information")

    assert_select "div#mentor_profile" do
      assert_select "div#program_role_info" do
        # FIXME education and experience + basic profile + mentor profile +  more information
        assert_select "div.ibox", :count => 4

        assert_select "div.ibox:nth-of-type(1)" do
          assert_select "div.ibox-title", :text => /Basic Information/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => 4 # Name, Email, Phone, Location
          end
        end
        assert_select "div.ibox:nth-of-type(2)" do
          assert_select "div.ibox-title", :text => /Work and Education/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => 10
          end
        end
        assert_select "div.ibox:nth-of-type(3)" do
          assert_select "div.ibox-title", :text => /Mentoring Profile/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => sections(:sections_3).profile_questions.size - 2
          end
        end
        assert_select "div.ibox:nth-of-type(4)" do
          assert_select "div.ibox-title", :text => /More Information/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => mentor_more_info_section.profile_questions.size
          end
        end
      end
    end
    assert_tab @controller._Mentors
    assert_false assigns(:show_meetings)
    assert assigns(:show_articles)
    assert assigns(:show_answers)
    assert_false assigns(:show_connections)
  end

  def test_student_view_of_mentor_profile_from_mentor_request_new_page
    current_user_is :rahim
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    group = create_group(:students => [users(:rahim)], :mentor => users(:f_mentor), :program => programs(:albers))
    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: nil, context_object: users(:f_mentor).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id, :src => MentorRecommendation::Source::NEW_PAGE}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal "request mentoring connection", assigns(:back_link)[:label]
    assert_equal new_mentor_request_path, assigns(:back_link)[:link]
  end

  def test_student_view_of_mentor_profile_from_campaign_email_recommendations
    current_user_is :rahim
    
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, context_place: EngagementIndex::Src::VisitMentorsProfile::CAMPAIGN_WIDGET_RECOMMENDATIONS, context_object: users(:f_mentor).id).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { id: members(:f_mentor).id, src: EngagementIndex::Src::VisitMentorsProfile::CAMPAIGN_WIDGET_RECOMMENDATIONS, open_connect_popup: AbstractRequest::MEETING_REQUEST }
    assert_response :success
    assert_equal AbstractRequest::MEETING_REQUEST, assigns(:open_connect_popup)
  end

  def test_student_view_of_mentor_profile_from_home_page_recommendations
    current_user_is :rahim
    
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, context_place: EngagementIndex::Src::VisitMentorsProfile::HOME_PAGE_RECOMMENDATIONS, context_object: users(:f_mentor).id).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id, :src => "quick_connect_box"}
    assert_response :success
  end

  def test_student_view_of_mentor_profile_from_mentor_listing_page
    current_user_is :rahim
    
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, context_place: EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE, context_object: users(:f_mentor).id).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id, :src => EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE}
    assert_response :success
  end

  def test_student_view_of_mentor_profile_with_email_phone_hidden
    org = programs(:org_primary)
    org.enable_feature(FeatureName::SKYPE_INTERACTION)

    current_user_is :rahim
    group = create_group(:students => [users(:rahim)], :mentor => users(:f_mentor), :program => programs(:albers))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_select "div#left_pane" do
      assert_select "div.ibox:first-of-type" do
        assert "div.ibox-content" do
          assert_select "h4", :count => 4 # email, skpe, location, phone
        end
      end
    end
  end

  def test_mentor_view_of_student_profile
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)

    group = create_group(:students => [users(:rahim)], :mentor => users(:f_mentor), :program => programs(:albers))
    programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).select{|q| q.profile_question.question_text=="Gender"}[0].update_attribute(:private, 24)

    session[:last_visit_url] = "/test_url"
    create_meeting_request(:mentor => users(:f_mentor), :student => users(:rahim), status: MeetingRequest::Status::NOT_ANSWERED)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => members(:rahim).id}
    back_link = {:link=>"/test_url"}
    assert_equal back_link, assigns[:back_link]
    assert_response :success
    assert_template 'show'
    assert assigns(:show_connect)
    assert_select "div#left_pane" do
      assert_select "a[href=\"/p/albers/groups/#{group.id}\"]", :text => /Go to #{group.name}/
      assert_no_select "a[onclick=\"Meetings.renderMiniPopup('/p/albers/meetings/mini_popup?member_id=#{members(:rahim).id}'); return false;\"]"
    end

    student_more_info_section = programs(:org_primary).sections.find_by(title: "More Information")
    programs(:albers).reload
    assert_select "div#mentor_profile" do
      assert_select "div#program_role_info" do

        assert_select "div.ibox:nth-of-type(1)" do
          assert_select "div.ibox-title", :text => /Basic Information/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => 4 # Name, Email, Phone, Location
          end
        end

        assert_select "div.ibox:nth-of-type(2)" do
          assert_select "div.ibox-title", :text => /Work and Education/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => 2
          end
        end

        assert_select "div.ibox:nth-of-type(3)" do
          assert_select "div.ibox-title", :text => /Mentoring Profile/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => sections(:sections_3).profile_questions.size - 4 # one is private + 3 is  mentor questions
          end
        end

        assert_select "div.ibox:nth-of-type(4)" do
          assert_select "div.ibox-title", :text => /More Information Students/
          assert_select "div.ibox-content" do
            assert_select "h4", student_more_info_section.profile_questions.size - 2
          end
        end

      end
    end

  end

  def test_student_view_of_mentor_profile_calendar_feature_enabled
    time = Time.now
    Time.stubs(:now).returns(time)

    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    current_user_is :rahim

    group = create_group(:students => [users(:rahim)], :mentor => users(:f_mentor), :program => programs(:albers))

    User.any_instance.stubs(:is_capacity_reached_for_current_and_next_month?).returns([false, ""])
    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id, src: EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE}
    assert_response :success
    assert_template 'show_mentor'
    assert_select "a[href=?]", group_path(group), text: "Go to #{group.name}"

    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_select "div#left_pane" do
      assert_select "a[href=\"/p/albers/messages/new?receiver_id=#{members(:f_mentor).id}&src=#{EngagementIndex::Src::MessageUsers::USER_PROFILE_PAGE}\"]", :text => "Send Message"
      assert_select "a[data-click=\"Meetings.renderMiniPopup('/p/albers/meetings/mini_popup?member_id=#{members(:f_mentor).id}&src=#{EngagementIndex::Src::MessageUsers::USER_PROFILE_PAGE}')\"]", :text => "Request Meeting"
      assert_select "a[href=\"/p/albers/groups/#{group.id}\"]", text: "Go to #{group.name}"
    end
    assert_tab @controller._Mentors
  end

  def test_mentor_student_view_of_student_profile
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :f_mentor_student
    create_meeting_request(:mentor => users(:f_mentor_student), :student => users(:f_student), status: MeetingRequest::Status::NOT_ANSWERED)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => members(:f_student).id}
    assert_response :success
    assert_template 'show'
    assert assigns(:show_connect)
    assert_select "div#left_pane" do
      assert_no_select "a[data-click=\"Meetings.renderMiniPopup('/p/albers/meetings/mini_popup?member_id=#{members(:f_student).id}')\"]"
    end
  end

  def test_mentor_student_view_of_mentor_profile
    time = Time.now
    Time.stubs(:now).returns(time)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :f_mentor_student

    User.any_instance.stubs(:is_capacity_reached_for_current_and_next_month?).returns([false, ""])
    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:f_mentor_student))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id, src: EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE}
    assert_response :success
    assert_template 'show_mentor'
    assert assigns(:show_connect)
    assert_select "div#left_pane" do
      assert_select "a[data-click=\"Meetings.renderMiniPopup('/p/albers/meetings/mini_popup?member_id=#{members(:f_mentor).id}&src=#{EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE}')\"]", :text => /Request Meeting/
    end
  end


  def test_connected_student_view_of_mentor_profile_on_a_program_which_does_not_allow_unconnected_mentee_to_contact_mentor
    current_user_is :rahim

    create_group(:students => [users(:rahim)], :mentor => users(:f_mentor), :program => programs(:albers))
    p = programs(:albers)
    p.update_attribute(:allow_user_to_send_message_outside_mentoring_area, false)

    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_select "div#left_pane" do
      assert_select "a", :text => "Send Message", :href => new_message_path(:receiver_id => users(:f_mentor).member.id)
    end
  end

  def test_student_view_of_mentor_profile_on_a_program_which_does_not_allow_unconnected_mentee_to_contact_mentor
    current_user_is :rahim

    p = programs(:albers)
    p.update_attribute(:allow_user_to_send_message_outside_mentoring_area, false)

    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_select "div#left_pane" do
      assert_select "a[href=\"/p/albers/messages/new?receiver_id=#{members(:f_mentor).id}\"]", :text => "Send message", :count => 0
    end
  end

  def test_student_view_of_student_profile_on_a_program_which_does_not_allow_mentee_to_contact_other_mentee
    current_user_is :rahim

    p = programs(:albers)
    p.update_attribute(:allow_user_to_send_message_outside_mentoring_area, false)

    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_student).id}
    assert_response :success
    assert_equal users(:f_student), assigns(:profile_user)
    assert_select "div#left_pane" do
      assert_select "a.send_message", :text => "Send Message", :count => 0
    end
  end

  def test_view_self_mentor_profile
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)

    # Insert 2 custom fields for the program
    programs(:org_primary).profile_questions << create_question(:role_names => [RoleConstants::MENTOR_NAME])
    programs(:org_primary).profile_questions << create_question(:role_names => [RoleConstants::MENTOR_NAME])

    create_meeting_request(:mentor => users(:f_mentor), :student => users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_false assigns(:show_connect)

    #add 1 for the email question
    question_count = programs(:albers).reload.profile_questions_for(RoleConstants::MENTOR_NAME, {default: false, skype: true}).size + 1
    assert_select 'div#mentor_profile' do
      assert_select 'h4.m-t-sm.m-b-xs', question_count
      assert_select 'div.subheader', question_count
    end

    assert_tab TabConstants::HOME

    assert assigns(:show_meetings)
    assert assigns(:show_articles)
    assert assigns(:show_answers)
    assert_false assigns(:show_connections)
  end

  def test_admin_view_of_mentor_profile
    current_user_is :f_admin
    create_mentor_offer(:mentor => users(:f_mentor), :student => users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_select 'div#sidebarRight' do
      assert_select 'div#admin_actions'
    end
    assert_select "div.ibox:nth-of-type(2)" do
      assert_select "div.ibox-title", :text => /Basic Information/
      assert_select "div.ibox-content" do
        assert_select "h4", :text => "Email"
      end
    end
    assert_tab @controller._Mentors
    assert_false assigns(:show_meetings)
    assert assigns(:show_articles)
    assert assigns(:show_answers)
    assert assigns(:show_connections)
  end

  def test_admin_view_for_mentoring_role
    teacher_role = create_role(name: "teacher", for_mentoring: true, program: programs(:albers))
    user = create_user(role_names: [teacher_role.name])
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => user.member.id}
    assert_response :success
    assert_template 'show'

    assert assigns(:show_connections)
  end

  def test_show_skype_on_profile_page
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never
    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_select 'div#sidebarRight' do
      assert_select 'div#admin_actions'
    end

    assert_select "div#mentor_profile" do
      assert_select "div#program_role_info" do
        # FIXME education and experience + basic profile + mentor profile +  more information
        assert_select "div.ibox", :count => 5
        assert_select "div.ibox:nth-of-type(2)" do
          assert_select "div.ibox-title", :text => /Basic Information/
          assert_select "div.ibox-content" do
          assert_select "h4", :count => 4 # Email, Skype ID, Phone and Location
            assert_select "h4", :text => "Email"
            assert_select "h4", :text => "Location"
            assert_select "h4", :text => "Phone"
            assert_select "h4", :text => "Skype ID"
            assert_select "i.text-muted:last-child", :text => "Not Specified"
          end
        end
      end
    end
  end

  def test_show_never_logged_in_on_profile_page
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never
    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_select "div.pull-left.col-xs-6 div.no-padding div.m-b-xs", :text => "Never logged in"
  end

  def test_should_not_show_skype_on_profile_page_when_feature_disabled
    current_program_is :albers
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION, false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never
    @controller.expects(:fetch_profile_member)
    @controller.expects(:fetch_profile_user).returns(users(:f_mentor))
    @controller.instance_variable_set(:@profile_member, members(:f_mentor))
    @controller.instance_variable_set(:@profile_user, users(:f_mentor))

    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal users(:f_mentor), assigns(:profile_user)
    assert_select 'div#sidebarRight' do
      assert_select 'div#admin_actions'
    end
    assert_no_select "div#skype_id"
  end

  # Admin Panel
  def test_actions_in_admin_panel_admin_views_mentor_profile
    admin = users(:f_admin)
    p = programs(:albers)
    current_user_is admin
    p.organization.enable_feature(FeatureName::WORK_ON_BEHALF)
    assert p.organization.has_feature?(FeatureName::WORK_ON_BEHALF)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never

    get :show, params: { :id => members(:f_mentor).id}
    profile_user = assigns(:profile_user)
    assert_equal users(:f_mentor), profile_user
    assert admin != profile_user
    admin_term = "Administrator"
    assert_select 'html' do
      assert_select 'div#sidebarRight' do
        assert_select 'div#admin_actions' do
          assert_select 'h5', :text => "#{admin_term} Actions"
          assert_select 'ul' do
            assert_select 'li.admin_panel_action', :count => 7
          end
        end
      end
    end

    # Edit Profile
    assert admin.can_update_profiles?
    assert_select 'a#side_edit_profile_link', :text => /Edit .* profile/
    # Work on Behalf
    assert admin.can_work_on_behalf?
    assert_select 'a', :text => "Work on Behalf"
    # Add Role
    assert admin.can_manage_user_states?
    assert profile_user.is_mentor?
    assert_select "a#change_roles_link", :text => "Change Roles"
    # Suspend
    assert_select "a#suspend_link_#{profile_user.id}", :text => "Deactivate Membership"
    # Remove
    assert_select "a#remove_link_#{profile_user.id}", :text => /Remove/
  end

  def test_actions_in_admin_panel_admin_views_self_profile
    admin = users(:f_admin)
    p = programs(:albers)
    current_user_is admin
    p.organization.enable_feature(FeatureName::WORK_ON_BEHALF)
    assert p.organization.has_feature?(FeatureName::WORK_ON_BEHALF)
    admin_term = "Administrator"
    get :show, params: { :id => admin.member.id}
    profile_user = assigns(:profile_user)
    assert_equal admin, profile_user

    assert_select 'html' do
      assert_select 'div#sidebarRight' do
        assert_select 'div#admin_actions' do
          assert_select 'h5', :text => "#{admin_term} Actions"
          assert_select 'ul' do
            assert_select 'li.admin_panel_action', :count => 2
          end
        end
      end
    end

    # Edit Profile
    assert admin.can_update_profiles?
    assert_select 'a#side_edit_profile_link', :text => /Edit .* profile/

    # Work on Behalf
    assert admin.can_work_on_behalf?
    assert_select 'a.wob_link', :text => "Work on Behalf", :count => 0
    # Add Role
    assert admin.can_manage_user_states?
    assert_select "a#change_roles_link", :text => "Change Roles"
    # Suspend
    assert_select "a#suspend_link_#{profile_user.id}", :text => "Suspend", :count => 0
    # Remove
    assert_select "a#remove_link_#{profile_user.id}", :text => /Remove/, :count => 0
  end

  def test_dont_show_actions_in_admin_panel_to_non_admin
    mentor = users(:f_mentor)
    current_user_is mentor
    programs(:org_primary).enable_feature(FeatureName::WORK_ON_BEHALF)
    assert programs(:albers).organization.has_feature?(FeatureName::WORK_ON_BEHALF)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    create_mentor_request(:mentor => users(:f_mentor), :student => users(:f_mentor_student), status: MeetingRequest::Status::NOT_ANSWERED)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never
    get :show, params: { :id => members(:f_mentor_student).id}
    profile_user = assigns(:profile_user)
    assert_equal users(:f_mentor_student), profile_user
    assert !mentor.is_admin?
    assert !mentor.can_update_profiles?
    assert !mentor.can_work_on_behalf?
    assert !mentor.can_manage_user_states?

    assert_select 'html' do
      assert_select 'div#left_pane' do
        assert_no_select 'fieldset.admin_panel'
      end
    end
  end

  def test_is_user_profile_pending_for_mentor
    create_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"], :required => 1)
    programs(:albers).reload
    m1 =  users(:pending_user)
    current_user_is m1
    assert_equal User::Status::PENDING, m1.state
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id}
    assert_redirected_to edit_member_path(m1.member, :first_visit => true, :landing_directly => true, ei_src: EngagementIndex::Src::EditProfile::PROFILE_PENDING)
  end

  def test_is_user_profile_pending_for_student
    q1 = create_question(:program => programs(:albers), :role_names => [RoleConstants::STUDENT_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"], :required => true)
    programs(:albers).reload
    s1 = create_user(:role_names => [RoleConstants::STUDENT_NAME], :program => programs(:albers))
    current_user_is s1
    assert_equal User::Status::PENDING, s1.state
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_student).id}
    assert_redirected_to edit_member_path(s1.member, :first_visit => true,:landing_directly => true, ei_src: EngagementIndex::Src::EditProfile::PROFILE_PENDING)
  end

  def test_should_not_render_request_mentor_action_in_moderated_program_when_connected
    make_member_of(:moderated_program, :f_student)
    current_user_is :f_student

    # Connect the student and the mentor.
    create_group(:student => users(:f_student), :mentor => users(:moderated_mentor), :program => programs(:moderated_program))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:moderated_mentor).id}).once

    # Student views mentor profile
    get :show, params: { :id => members(:moderated_mentor).id}
    assert_response :success
    assert_select 'a', :text => /Request this.*/, :count => 0
  end

  def test_should_render_articles_tab_for_admin
    current_user_is :f_student

    assert_equal([articles(:economy), articles(:india)], users(:f_admin).articles)
    get :show, params: { :id => members(:f_admin).id, :tab => 'articles'}
    assert_response :success
    assert_select 'div#articles' do
      assert_select 'h4' do
        assert_select 'a', :text => articles(:economy).title
      end
      assert_select 'h4' do
        assert_select 'a', :text => articles(:india).title
      end
    end
  end

  def test_should_show_current_experience
    current_user_is :f_mentor
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_experience_q)
    member.experiences.all.collect(&:destroy)
    assert_equal(0, member.reload.experiences.size)
    e1 = create_experience(user, question, :start_year => 1999, :end_year => 2003)
    e2 = create_experience(user, question, :start_year => 2004, :end_year => nil,  :current_job => true)
    e3 = create_experience(user, question, :start_year => nil, :end_year => nil, :company => "Earth", :job_title => 'Man')
    e4 = create_experience(user, question, :start_year => nil, :end_year => nil,  :current_job => true, :company => "Universe", :job_title => 'Soul')
    e5 = create_experience(user, question, :start_year => 1986, :end_year => nil, :company => "Home", :job_title => 'Son')
    assert_equal(5, member.reload.experiences.size)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => users(:f_mentor).id}

    [e1, e2, e3, e4, e5].each do |exp|
      assert_select '.company', :text => exp.company
    end

    assert_select "a", :href => member_url(members(:f_mentor), :tab => "articles")
  end

  def test_should_show_articles_by_mentor
    prog = programs(:albers)
    mentor = users(:f_mentor)
    current_program_is prog
    current_user_is mentor
    assert mentor.articles.drafts.any?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => mentor.member.id, :tab => 'articles'}
    assert_not_nil assigns(:drafts)
    assert_response :success
    assert_select 'div#articles' do
      assert_select 'h4' do
        assert_select 'a', :text => articles(:kangaroo).title
      end
    end

    assert_select 'div#articles' do
      assert_select "span.label.label-warning", :count => mentor.articles.drafts.size
    end
  end

  def test_should_show_draft_articles_by_mentor_even_if_published_articles_are_empty
    prog = programs(:albers)
    mentor = users(:f_mentor)
    current_program_is prog
    current_user_is mentor
    mentor.articles.published.destroy_all
    mentor.reload

    assert(mentor.articles.published.empty?)
    assert(mentor.articles.drafts.any?)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => mentor.member.id, :tab => 'articles'}
    assert_not_nil assigns(:drafts)
    assert_response :success

    assert_select 'div#articles' do
      assert_select "span.label.label-warning", :count => mentor.articles.drafts.size
    end
  end

  def test_should_show_not_show_articles_tab_mentor_for_a_mentor_with_no_articles_even_if_there_are_drafts
    prog = programs(:albers)
    mentor = members(:mentor_5)
    create_article_draft(:author => mentor, :program => prog, :type => ArticleContent::Type::TEXT)
    assert_equal(0, mentor.articles.published.size)
    assert_equal(1, mentor.articles.drafts.size)

    current_program_is prog
    current_user_is users(:f_admin)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => mentor.id, :tab => 'articles'}
    assert_response :success
    assert_no_select "div#articles"
  end


  #-----------------------------------------------------------------------------
  # PROFILE FOR ORGANIZATION VIEW
  #-----------------------------------------------------------------------------

  def test_member_view_other_student_profile
    current_member_is :rahim

    user = users(:f_student)
    question_1 = create_qa_question
    create_qa_question
    create_qa_answer(:qa_question => question_1)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => user.member.id}
    assert_response :success
    assert_template 'show'
    assert_no_select "div.profile_status_box"
  end

  # No inactive message in profile view.
  def test_member_view_inactive_users_profile
    current_member_is :f_mentor

    student = users(:f_student)
    student.delete!
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_student).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_nil flash[:error]
  end

  def test_member_view_self_student_profile
    current_member_is :f_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => members(:f_student).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal members(:f_student), assigns(:profile_member)
    assert_nil assigns(:profile_user)
    assert_nil assigns(:pdf_name)
    assert_no_select "a.edit_profile"
    assert_no_select "div.profile_status_box"
    assert_tab TabConstants::HOME
  end

  def test_member_viewing_student_self_profile_on_questions_change_should_not_render_profile_update_prompt
    current_member_is :f_student

    ProfileQuestion.skip_timestamping do
      3.times { create_student_question(:created_at => 2.days.ago, :updated_at => 2.days.ago) }
    end

    ProfileAnswer.skip_timestamping do
      ProfileAnswer.create(:ref_obj => members(:f_student), :profile_question => ProfileQuestion.last, :answer_text => "and", :created_at => 1.day.ago, :updated_at => 1.day.ago)
    end
    # Create a dumy question to trigger profile update prompt
    create_student_question
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => members(:f_student).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal members(:f_student), assigns(:profile_member)
    assert_nil assigns(:profile_user)
    assert_no_select "div#profile_update"
  end

  def test_member_viewing_student_self_profile_on_questions_change_should_not_render_new_profile_quesiton_prompt
    current_member_is :f_student
    create_student_question(:required => 1)
    programs(:albers).reload
    users(:f_student).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => members(:f_student).id}
    assert_response :success
    assert_no_select "div#profile_update"
  end

  def test_member_viewing_mentor_self_profile_on_questions_change_should_not_render_profile_update_prompt
    current_member_is :f_mentor
    ProfileQuestion.skip_timestamping do
      3.times { create_mentor_question(:created_at => 2.days.ago, :updated_at => 2.days.ago) }
    end
    ProfileAnswer.skip_timestamping do
      ProfileAnswer.create(:profile_question => ProfileQuestion.last, :answer_text => "and", :created_at => 1.day.ago, :updated_at => 1.day.ago)
    end
    # Create a dumy question to trigger profile update prompt
    create_mentor_question
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal members(:f_mentor), assigns(:profile_member)
    assert_no_select "div#profile_update"
  end

  def test_member_viewing_mentor_self_profile_on_required_questions_change_should_not_render_profile_update_prompt
    current_member_is :f_mentor
    create_mentor_question(:required => true)
    programs(:albers).reload
    members(:f_mentor).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_no_select "div#profile_update"
  end

  def test_member_admin_should_be_able_to_view_of_student_profile_and_should_not_see_profile_update_prompt
    current_member_is :f_admin
    3.times { create_student_question }
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_student).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal members(:f_student), assigns(:profile_member)
    assert_select 'div#sidebarRight' do
      assert_select 'div#admin_actions', :count => 1
    end
    # There should be no profile update prompt
    assert_select "div#profile_update", :count => 0
  end

  def test_member_view_self_mentor_profile
    current_member_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_false assigns(:show_email)
    assert_select 'div#mentor_profile' do
      assert_select 'div#program_role_info' do
        assert_no_select 'label'
        assert_no_select 'div.answer'
      end
    end

    assert_tab TabConstants::HOME
  end

  def test_member_admin_view_of_mentor_profile
    org = programs(:org_primary)
    org.enable_feature(FeatureName::SKYPE_INTERACTION)

    current_member_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal members(:f_mentor), assigns(:profile_member)
    assert_select 'div#sidebarRight' do
      assert_select 'div#admin_actions', :count => 1
    end
  end

  def test_member_admin_view_of_mentor_profile_for_program
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never

    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_equal members(:f_mentor), assigns(:profile_member)
    mentor_more_info_section = programs(:org_primary).sections.find_by(title: "More Information")

    assert_select "div#mentor_profile:nth-of-type(1)" do
      assert_select "div#program_role_info" do
        # FIXME education and experience + basic profile + mentor profile +  more information
        assert_select "div.ibox", :count => 5
        assert_select "div.ibox:nth-of-type(1)" do
            assert_select "div.ibox-title", :text => /Activity Overview/
        end
        assert_select "div.ibox:nth-of-type(2)" do
          assert_select "div.ibox-title", :text => /Basic Information/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => 4
          end
        end
        assert_select "div.ibox:nth-of-type(3)" do
          assert_select "div.ibox-title", :text => /Work and Education/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => 10
          end
        end
        assert_select "div.ibox:nth-of-type(4)" do
          assert_select "div.ibox-title", :text => /Mentoring Profile/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => sections(:sections_3).profile_questions.size - 2
          end
        end
        assert_select "div.ibox:nth-of-type(5)" do
          assert_select "div.ibox-title", :text => /More Information/
          assert_select "div.ibox-content" do
            assert_select "h4", :count => mentor_more_info_section.profile_questions.size
          end
        end
      end
    end
  end

  def test_member_should_not_show_skype_on_profile_page_when_feature_disabled
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION, false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'show_mentor'
    assert_false assigns(:show_email)
    assert_equal members(:f_mentor), assigns(:profile_member)
    assert_select 'div#sidebarRight' do
      assert_select 'div#admin_actions', :count => 1
    end
    assert_select "div#skype_id", :count => 0
  end

  # Admin Panel
  def test_member_actions_in_admin_panel_admin_views_mentor_profile
    admin = members(:f_admin)
    p = programs(:albers)
    current_member_is admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id}
    profile_member = assigns(:profile_member)
    assert_equal members(:f_mentor), profile_member
    assert admin != profile_member

    assert_select 'html' do
      assert_select 'div#left_pane' do
        assert_select 'fieldset.admin_panel', :count => 0
      end
    end

    # Edit Profile
    assert admin.can_update_profiles?
    assert_select 'a', :text => "Edit Profile"
    # Work on Behalf
    assert admin.can_work_on_behalf?
    assert_select 'a.wob_link', :text => "Work on Behalf", :count => 0
    # Add Role
    assert admin.can_manage_user_states?
    assert profile_member.is_mentor?
    assert_select "a", :text => "Change Roles", :count => 0
    # Suspend
    assert_select "a", :text => "Suspend", :count => 0
    # Remove
    assert_select "a", :text => "Remove", :count => 0
  end

  def test_member_actions_in_admin_panel_admin_views_self_profile
    admin = users(:f_admin)
    p = programs(:albers)
    current_member_is admin.member
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => admin.member.id}
    assert_equal admin.member, assigns(:profile_member)

    assert_select 'html' do
      assert_select 'div#left_pane' do
        assert_select 'fieldset.admin_panel', :count => 0
      end
    end
    # Edit Profile not available at organization level
    assert admin.can_update_profiles?
    assert_no_select 'div#admin_actions'
    # Work on Behalf
    assert admin.can_work_on_behalf?
    assert_select 'a.wob_link', :text => "Work on Behalf", :count => 0
    # Add Role
    assert admin.can_manage_user_states?
    assert_select "a", :text => "Add Role", :count => 0
    # Suspend
    assert_select "a", :text => "Suspend", :count => 0
    # Remove
    assert_select "a", :text => "Remove", :count => 0
  end

  def test_member_dont_show_actions_in_admin_panel_to_non_admin
    mentor = users(:f_mentor)
    current_member_is mentor.member
    programs(:org_primary).enable_feature(FeatureName::WORK_ON_BEHALF)
    assert programs(:albers).organization.has_feature?(FeatureName::WORK_ON_BEHALF)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor_student).id}
    assert_equal members(:f_mentor_student), assigns(:profile_member)
    assert !mentor.is_admin?
    assert !mentor.can_update_profiles?
    assert !mentor.can_work_on_behalf?
    assert !mentor.can_manage_user_states?

    assert_select 'html' do
      assert_select 'div#left_pane' do
        assert_select 'fieldset.admin_panel', :count => 0
      end
    end
  end

  def test_member_should_show_current_experience
    current_user_is :f_mentor
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_experience_q)
    member.experiences.all.collect(&:destroy)
    assert_equal(0, member.reload.experiences.size)
    e1 = create_experience(user, question, :start_year => 1999, :end_year => 2003)
    e2 = create_experience(user, question, :start_year => 2004, :end_year => nil,  :current_job => true)
    e3 = create_experience(user, question, :start_year => nil, :end_year => nil, :company => "Earth", :job_title => 'Man')
    e4 = create_experience(user, question, :start_year => nil, :end_year => nil,  :current_job => true, :company => "Universe", :job_title => 'Soul')
    e5 = create_experience(user, question, :start_year => 1986, :end_year => nil, :company => "Home", :job_title => 'Son')
    assert_equal(5, member.reload.experiences.size)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => members(:f_mentor).id}

    [e1, e2, e3, e4, e5].each do |exp|
      assert_select '.company', :text => exp.company
    end

    assert_select "a", :href => member_url(members(:f_mentor), :tab => "articles")
  end

  def test_article_tab_is_redirected_to_profile_at_org
    current_member_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id, :tab => MembersController::ShowTabs::ARTICLES}
    assert_false assigns(:show_articles)
    assert_equal MembersController::ShowTabs::PROFILE, assigns(:profile_tab)
  end

  #-----------------------------------------------------------------------------
  # AUTOCOMPLETE
  #-----------------------------------------------------------------------------
  
  def test_member_autocomplete_name_or_email_loggedout
    member = guess_member(:anna_univ_admin)
    current_organization_is member.organization
    get :auto_complete_for_name_or_email, xhr: true, params: { :search => "min", :format => :json, :for_autocomplete => true}
    assert_response :unauthorized
  end

  def test_member_autocomplete_name
    current_member_is :anna_univ_admin
    assert_equal 2, members(:anna_univ_mentor).users.size

    get :auto_complete_for_name, xhr: true, params: { :search => "mental", :format => :json, :for_autocomplete => true}
    assert_response :success

    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["mental mentor <mentor@psg.com>"], JSON.parse(@response.body)
    # Should not return duplicate members.
    assert_equal [members(:anna_univ_mentor)], assigns(:members).to_a
  end

  def test_to_check_search_query_is_escaped
    current_member_is :anna_univ_admin
    assert_nothing_raised do
      get :auto_complete_for_name, xhr: true, params: { :search => "mental/", :format => :json, :for_autocomplete => true}
    end
    assert_response :success
    assert_equal [], assigns(:members).to_a
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [], JSON.parse(@response.body)
  end

  def test_member_autocomplete_should_not_result_other_program_members
    current_member_is :f_admin

    get :auto_complete_for_name, xhr: true, params: { :search => "Rajesh Vijay", :format => :json, :for_autocomplete => true}
    assert_response :success
    assert_equal [], assigns(:members).to_a
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [], JSON.parse(@response.body)
  end

  def test_autocomplete_user_name_for_mentors_drafts
    current_member_is :anna_univ_admin

    get :auto_complete_for_name, xhr: true, params: { :search => "Draft Mentor", :format => :json, :for_autocomplete => true}
    assert_response :success
    assert assigns(:members).to_a.empty?
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [], JSON.parse(@response.body)
  end

  def test_autocomplete_user_name_for_suspended_mentors
    current_user_is users(:psg_admin)

    get :auto_complete_for_name, xhr: true, params: { :search => "inactive", :show_all_members => "true", :format => :json, :for_autocomplete => true}
    assert_response :success
    assert_equal_unordered [members(:inactive_user)], assigns(:members).to_a
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["inactive mentor <inactivementor@albers.com>"], JSON.parse(@response.body)

    get :auto_complete_for_name, xhr: true, params: { :search => "inactive", :format => :json, :for_autocomplete => true}
    assert_response :success
    assert_blank assigns(:members)
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [], JSON.parse(@response.body)
  end

  def test_member_autocomplete_dormant
    current_user_is :no_subdomain_admin

    get :auto_complete_for_name, xhr: true, params: { :search => "Dor", :format => :json, :for_autocomplete => true}
    assert_response :success
    assert_equal Member::Status::DORMANT, members(:dormant_member).state

    # Should not return duplicate members.
    assert_equal [members(:dormant_member)], assigns(:members).to_a
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["Dormant Member <dormant@example.com>"], JSON.parse(@response.body)
  end

  def test_member_autocomplete_for_filters
    current_member_is :f_admin

    get :auto_complete_for_name, xhr: true, params: { "filter"=>{"filters"=>{"0"=>{"field"=>"first_name", "operator"=>"startswith", "value"=>"pen"}}}, :format => :json}
    assert_equal_unordered [{"first_name"=> members(:pending_user).first_name}], JSON.parse(response.body)

    get :auto_complete_for_name, xhr: true, params: { "filter"=>{"filters"=>{"0"=>{"field"=>"last_name", "operator"=>"startswith", "value"=>"use"}}}, :format => :json}
    assert_equal_unordered [{"last_name"=> members(:pending_user).last_name}], [JSON.parse(response.body).first]

    get :auto_complete_for_name, xhr: true, params: { "filter"=>{"filters"=>{"0"=>{"field"=>"email", "operator"=>"startswith", "value"=>"pend"}}}, :format => :json}
    assert_equal_unordered [{"email"=> members(:pending_user).email}], JSON.parse(response.body)
    # Should not include other org members
    get :auto_complete_for_name, xhr: true, params: { "filter"=>{"filters"=>{"0"=>{"field"=>"last_name", "operator"=>"startswith", "value"=>"Vija"}}}, :format => :json}
    assert JSON.parse(response.body).blank?

    get :auto_complete_for_name, xhr: true, params: { "filter"=>{"filters"=>{"0"=>{"field"=>"password", "operator"=>"startswith", "value"=>"pend"}}}, :format => :json}
    assert JSON.parse(response.body).blank?
  end

  def test_member_autocomplete_for_adminmessage
    member = members(:anna_univ_admin)
    current_member_is member
    assert_equal 2, member.users.size

    get :auto_complete_for_name, xhr: true, params: { :search => member.name(name_only: true), :format => :json, :admin_message => true}
    assert_response :success

    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [{"label"=>"CEG Admin", "name" => "CEG Admin", "object_id"=>member.id}], JSON.parse(@response.body)
    # Should not return duplicate members.
    assert_equal [member], assigns(:members).to_a
  end

  ##############################################################################
  # MEMBER EDIT
  ##############################################################################

  def test_member_allow_edit_any_profile_for_admin_and_owner
    current_member_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    get :edit, params: { :id => members(:f_mentor)}
    assert_redirected_to programs_list_path
  end

  def test_member_allow_admin_to_edit_profile_only_of_those_belonging_to_the_program
    # CEG admin trying to edit profile of Albers user.
    ceg_admin = members(:anna_univ_admin)
    current_member_is ceg_admin
    albers_member = members(:mentor_2)
    assert_not_equal members(:anna_univ_admin).organization, albers_member.organization
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    get :edit, params: { :id => albers_member.id}
    assert_redirected_to programs_list_path
  end

  def test_member_should_allow_edit_only_for_owner_and_admin
    current_member_is :rahim
    assert_false members(:rahim).admin?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    assert_permission_denied do
      get :edit, params: { :id => members(:mentor_2)}
    end
  end

  def test_edit_self_profile
    current_member_is :rahim
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:rahim)}
    assert_response :success
    assert_select 'html'
    assert assigns(:unanswered_questions).present?
  end

  def test_member_accessing_a_guarded_page_without_login_back_marks_the_page
    current_organization_is :org_primary
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    get :edit, params: { :id => members(:f_mentor)}
    assert_redirected_to new_session_path
  end

  def test_member_should_show_current_experience_in_edit
    current_user_is :f_mentor
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_experience_q)
    member.experiences.all.collect(&:destroy)
    e1 = create_experience(user, question, :start_year => 1999, :end_year => 2003)
    e1.profile_answer.profile_question.role_questions[0].update_attribute(:required, true)
    e2 = create_experience(user, question, :start_year => 2004, :end_year => nil,  :current_job => true)
    e3 = create_experience(user, question, :start_year => nil, :end_year => nil, :company => "Earth", :job_title => 'Man')
    e4 = create_experience(user, question, :start_year => nil, :end_year => nil,  :current_job => true, :company => "Universe", :job_title => 'Soul')
    e5 = create_experience(user, question, :start_year => 1986, :end_year => nil, :company => "Home", :job_title => 'Son')
    assert_equal(5, member.reload.experiences.size)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: 'something').once

    get :edit, params: { :id => members(:f_mentor).id, :prof_c => true, :ei_src => 'something'}

    assert_select "#experience_#{e1.id}"
    assert_match /cjs_required/, response.body
    assert_select "#experience_#{e2.id}"
    assert_select "#experience_#{e3.id}"
    assert_select "#experience_#{e4.id}"
    assert_select "#experience_#{e5.id}"
  end

  ##############################################################################
  # MEMBER PROFILE EDIT
  ##############################################################################

  def test_member_admin_to_admin_mentor_after_role_update
    current_member_is :f_admin
    users(:f_admin).add_role(RoleConstants::MENTOR_NAME)
    create_mentor_question
    programs(:org_primary).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    get :edit, params: { :id => members(:f_admin), :first_visit => true}
    assert_redirected_to programs_list_path
  end

  def test_member_admin_to_admin_student_after_role_update
    current_member_is :f_admin
    users(:f_admin).add_role(RoleConstants::STUDENT_NAME)
    create_student_question
    programs(:org_primary).reload
    users(:f_admin).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    get :edit, params: { :id => members(:f_admin), :first_visit => true}
    assert_redirected_to programs_list_path
  end

  def test_edit_for_first_time_visit_for_pending_mentor_with_complete_profile
    current_user_is users(:pending_user)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:pending_user).id, :landing_directly => true, :first_visit => true}
    assert_response :success
    assert_template 'edit_first_visit'
    assert_equal "Your profile is not yet published. Please review and publish the profile.", flash[:warning]
  end

  def test_edit_for_first_time_visit_for_pending_mentor_with_incomplete_profile
    user = users(:pending_user)
    current_user_is user
    create_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"], :required => 1)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).times(3)

    get :edit, params: { :id => members(:pending_user).id, :landing_directly => true, :first_visit => true}
    assert_response :success
    assert_template 'edit_first_visit'
    assert_equal "Your mentor profile is incomplete. Please fill all the required fields and publish your profile.", flash[:warning]


    user.add_role(RoleConstants::STUDENT_NAME)
    user.reload

    create_question(:program => programs(:albers), :role_names => [RoleConstants::STUDENT_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["P", "Q", "R", "S"], :required => 1)
    programs(:albers).reload
    get :edit, params: { :id => members(:pending_user).id, :landing_directly => true, :first_visit => true}
    assert_response :success
    assert_template 'edit_first_visit'
    assert_equal "Your mentor and student profile is incomplete. Please fill all the required fields and publish your profile.", flash[:warning]

    user.add_role(RoleConstants::ADMIN_NAME)
    user.reload
    create_question(:program => programs(:albers), :role_names => [RoleConstants::ADMIN_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["L", "M", "N"], :required => 1)
    programs(:albers).reload

    get :edit, params: { :id => members(:pending_user).id, :landing_directly => true, :first_visit => true}
    assert_response :success
    assert_template 'edit_first_visit'
    assert_equal "Your mentor and student profile is incomplete. Please fill all the required fields and publish your profile.", flash[:warning]
  end

  def test_edit_for_first_time_visit_redirected_when_empty_program_questions
    user = users(:pending_user)
    current_user_is user
    
    @program_questions_for_user = programs(:albers).profile_questions_for(user.role_names, {:default => false, :skype => programs(:albers).organization.skype_enabled?, user: user, pq_translation_include: true})
    answered_profile_questions = user.member.answered_profile_questions
    @controller.stubs(:handle_answered_and_conditional_questions).with(user.member, @program_questions_for_user, answered_profile_questions).returns([])
    get :edit, params: { :id => members(:pending_user).id, :landing_directly => true, :first_visit => 'mentor'}
    assert_redirected_to edit_member_path(:id => user.member_id, :first_visit => 'mentor',
      :section => MembersController::EditSection::MENTORING_SETTINGS, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_answer_mandatory_qs
    user = users(:ram)
    program = programs(:albers)
    current_user_is user

    mentor_q1 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Abc", "Def"], :role_names => [RoleConstants::MENTOR_NAME], :required => true, question_text: "mentor q1")
    
    get :answer_mandatory_qs, xhr: true, params: { id: members(:ram).id}
    assert assigns(:is_self_view)
    assert_equal_unordered assigns(:pending_profile_questions), [mentor_q1]
    assert_equal assigns(:grouped_role_questions),program.role_questions_for(user.role_names, user: user).role_profile_questions.group_by(&:profile_question_id)

    admin_q1 = create_question(:program => programs(:albers), :role_names => [RoleConstants::ADMIN_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["L", "M", "N"], :required => 1, question_text: "admin q1")
    programs(:albers).reload

    get :answer_mandatory_qs, xhr: true, params: { id: members(:ram).id}
    assert_equal_unordered assigns(:pending_profile_questions), [mentor_q1, admin_q1]
    assert_equal assigns(:grouped_role_questions),program.role_questions_for(user.role_names, user: user).role_profile_questions.group_by(&:profile_question_id)

    conditional_question = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Stand", "Walk", "Run"], :role_names => [RoleConstants::MENTOR_NAME], :required => true)
    q1 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :role_names => [RoleConstants::MENTOR_NAME], conditional_question_id: conditional_question.id, conditional_match_text: "Stand", question_text: "q1")
    q2 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :role_names => [RoleConstants::MENTOR_NAME], conditional_question_id: conditional_question.id, conditional_match_text: "Run", question_text: "q2")
    q2.update_attributes!(section: programs(:org_primary).sections.second)
    q3 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :role_names => [RoleConstants::STUDENT_NAME], conditional_question_id: conditional_question.id, conditional_match_text: "Stand", question_text: "q3")
    q4 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :role_names => [RoleConstants::MENTOR_NAME], conditional_question_id: conditional_question.id, conditional_match_text: "", question_text: "q4")

    programs(:albers).reload
    get :answer_mandatory_qs, xhr: true, params: { id: members(:ram).id}
    assert_equal_unordered [mentor_q1, admin_q1, conditional_question, q1, q4], assigns(:pending_profile_questions)
    assert_equal assigns(:grouped_role_questions),program.role_questions_for(user.role_names, user: user).role_profile_questions.group_by(&:profile_question_id)
  end

  def test_member_should_update_the_mentee_profile_for_first_visit_and_redirect_to_answers_page
    current_user_is :f_student
    create_student_question
    programs(:org_primary).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', :member => {:first_name => "New Name", :last_name => "student"}}
    assert_redirected_to edit_member_path(:first_visit => 'mentee', :section => MembersController::EditSection::PROFILE, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_equal('New Name student', assigns(:profile_member).name)
  end

  def test_member_should_update_the_mentee_profile_for_first_visit_and_delete_answer_for_which_condition_failed
    current_user_is :f_student
    member = members(:f_student)
    conditional_question = setup_conditional_question_to_test(member, ["no match", "will not match"], "will not match")
    assert member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', :member => {:first_name => "New Name", :last_name => "student"}, :profile_answers => { conditional_question.id => "no match" }}
    assert_false member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    assert_redirected_to edit_member_path(:first_visit => 'mentee', :section => MembersController::EditSection::PROFILE, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_member_should_update_the_mentee_profile_for_first_visit_and_not_delete_answer_for_which_condition_succeeded
    current_user_is :f_student
    member = members(:f_student)
    conditional_question = setup_conditional_question_to_test(member, ["match"], "match")

    assert member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', :member => {:first_name => "New Name", :last_name => "student"}, :profile_answers => { conditional_question.id => "match" }}
    assert member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    assert_redirected_to edit_member_path(:first_visit => 'mentee', :section => MembersController::EditSection::PROFILE, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_general_profile_update_and_delete_answer_for_which_condition_failed
    current_user_is :f_student
    member = members(:f_student)
    conditional_question = setup_conditional_question_to_test(member, ["will never match", "no match"], "will never match")

    assert member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, xhr: true, params: { :id => members(:f_student), :member => {:first_name => "New Name", :last_name => "student"}, :profile_answers => { conditional_question.id => "no match" }}
    assert_false member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    assert assigns(:successfully_updated)
    assert_response :success
  end

  def test_general_profile_update_and_not_delete_answer_for_which_condition_passed
    current_user_is :f_student
    member = members(:f_student)
    conditional_question = setup_conditional_question_to_test(member, ["match"], "match")

    assert member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, xhr: true, params: { :id => members(:f_student), :member => {:first_name => "New Name", :last_name => "student"}, :profile_answers => { conditional_question.id => "match" }}
    assert member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    assert_response :success
  end

  def test_edu_exp_profile_update_and_not_delete_answer_for_which_condition_succeeded
    current_user_is :f_student
    member = members(:f_student)
    conditional_question = setup_conditional_question_to_test(member, ["match"], "match")
    assert member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, xhr: true, params: { :id => member, :role => "student",
        :profile_answers => {conditional_question.id => "match"}, :section_id => conditional_question.section.id
      }
    assert member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    assert_response :success
  end

  def test_edu_exp_profile_update_and_delete_answer_for_which_condition_failed
    current_user_is :f_student
    member = members(:f_student)
    conditional_question = setup_conditional_question_to_test(member, ["will never match", "match"], "will never match")
    assert member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, xhr: true, params: { :id => member, :role => "student",
        :profile_answers => {
        conditional_question.id => "match"}, :section_id => conditional_question.section.id
      }
    assert_false member.reload.profile_answers.collect(&:answer_text).include?("Conditional answer")
    assert assigns(:successfully_updated)
    assert_response :success
  end

  def test_general_profile_update_should_not_affect_education_experience_and_publication
    current_user_is :f_mentor
    assert members(:f_mentor).educations.any?
    assert members(:f_mentor).experiences.any?
    assert members(:f_mentor).publications.any?

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, xhr: true, params: { :id => members(:f_mentor), :member => {:first_name => "New Name", :last_name => "student"}}
    assert assigns(:successfully_updated)
    assert_response :success
    assert_equal('New Name student', assigns(:profile_member).name)
    assert members(:f_mentor).reload.educations.any?
    assert members(:f_mentor).reload.experiences.any?
    assert members(:f_mentor).reload.publications.any?
  end

  def test_edu_exp_profile_update_should_update_edu_exp_nil_dates
    current_user_is :mentor_5
    assert members(:mentor_5).educations.empty?
    assert members(:mentor_5).experiences.empty?
    assert members(:mentor_5).publications.empty?

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    assert_difference 'members(:mentor_5).experiences.reload.count' do
      post :update_answers, xhr: true, params: { :id => members(:mentor_5), :role => "mentor",
        :profile_answers => {
        profile_questions(:multi_experience_q).id.to_s => {
          :new_experience_attributes => [{"1" => {:start_year => nil, :end_year => nil, :company => "Earth", :job_title => 'Man', :current_job => false}}]
          }}, :section_id => profile_questions(:multi_experience_q).section.id
        }
    end

    assert_response :success
    exp = Experience.last
    assert_equal 'Earth', exp.company
    assert_equal 'Man', exp.job_title
    assert members(:mentor_5).reload.educations.empty?
    assert members(:mentor_5).reload.publications.empty?
    assert_equal [exp], members(:mentor_5).reload.experiences
  end

  def test_edu_exp_profile_update_should_update_current_job_current_job_with_nil_dates
    current_user_is :mentor_5
    assert members(:mentor_5).educations.empty?
    assert members(:mentor_5).experiences.empty?
    assert members(:mentor_5).publications.empty?

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    assert_difference 'members(:mentor_5).experiences.reload.count' do
      post :update_answers, xhr: true, params: { :id => users(:mentor_5), :role => "mentor",
        :profile_answers => {
        profile_questions(:multi_experience_q).id.to_s => {
          :new_experience_attributes => [{"1" => {:start_year => nil, :end_year => nil, :current_job => true, :company => "Earth", :job_title => 'Man'}}]
        }},  :section_id => profile_questions(:multi_experience_q).section.id
      }
    end

    assert_response :success
    exp = Experience.last
    assert_equal 'Earth', exp.company
    assert_equal 'Man', exp.job_title
    assert members(:mentor_5).reload.educations.empty?
    assert members(:mentor_5).reload.publications.empty?
    assert_equal [exp], members(:mentor_5).reload.experiences
  end

  def test_edu_exp_profile_update_should_add_and_remove_edu_exp_and_publication_and_manager
    current_user_is :mentor_5
    user = users(:mentor_5)
    edu_question = profile_questions(:multi_education_q)
    exp_question = profile_questions(:multi_experience_q)
    publication_question = profile_questions(:multi_publication_q)
    manager_question = profile_questions(:manager_q)
    edu1 = create_education(
      user, edu_question, :school_name => 'St.Marys', :degree => '12th', :major => "CS", :graduation_year => 2002)

    edu2 = create_education(
      user, edu_question, :school_name => 'CEG', :degree => 'B.E.', :major => "CSE", :graduation_year => 2006)

    exp1 = create_experience(
      user, exp_question, :start_year => nil, :end_year => nil, :current_job => true, :company => "D.E.Shaw", :job_title => 'Member')

    exp2 = create_experience(
      user, exp_question, :start_year => 2002, :end_year => 2004, :current_job => false, :company => "Universe", :job_title => 'Soul')

    pub1 = create_publication(
      user, publication_question, :title => 'Pub1', :publisher => 'Publisher1 ltd.', :day => 1, :month => 1, :year => 2009, :url => "http://public1.url", :authors => "Author1", :description => 'First very useful publication')

    pub2 = create_publication(
      user, publication_question, :title => 'Pub2', :publisher => 'Publisher2 ltd.', :day => 2, :month => 1, :year => 2009, :url => "http://public2.url", :authors => "Author2", :description => 'Second very useful publication')

    assert_equal [edu2, edu1], members(:mentor_5).educations.reload
    assert_equal_unordered [exp1, exp2], members(:mentor_5).experiences.reload
    assert_equal_unordered [pub1, pub2], members(:mentor_5).publications.reload

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    assert_no_difference 'members(:mentor_5).experiences.reload.count' do
      assert_difference 'members(:mentor_5).educations.reload.count' do
        assert_difference 'members(:mentor_5).publications.reload.count' do
          assert_difference 'Manager.count' do
            post :update_answers, xhr: true, params: { :id => members(:mentor_5), :role => "mentor",
              :profile_answers => {
              exp_question.id.to_s => {
                "new_experience_attributes" =>[{"1" => {:start_year => nil, :end_year => nil, :current_job => true, :company => "Chronus", :job_title => 'Member'}}],
                "existing_experience_attributes" => {
                  exp1.id.to_s => {:start_year => nil, :end_year => nil, :current_job => true, :company => "D.E.Shaw", :job_title => 'Member'}
                } },
              edu_question.id.to_s => {
                "new_education_attributes" =>[{"1" => {:school_name => 'Annai velankani', :degree => 'LKG', :major => "nothing", :graduation_year => 1988}}],
                "existing_education_attributes" => {
                  edu1.id.to_s => {:school_name => 'St.Marys', :degree => '12th', :major => "CS", :graduation_year => 2002},
                  edu2.id.to_s => {:school_name => 'CEG', :degree => 'B.E.', :major => "CSE", :graduation_year => 2006}
                } },
              publication_question.id.to_s => {
                "new_publication_attributes" =>[{"1" => {:title => "New publication", :day => 11, :month => 10, :year => 2010, :publisher => 'New Publisher', :url => 'http://new_publication.url', :description => 'New Very useful publication'}}],
                "existing_publication_attributes" => {
                  pub1.id.to_s => {:title => 'Pub1', :publisher => 'Publisher1 ltd.', :day => 1, :month => 1, :year => 2009, :url => "http://public1.url", :authors => "Author1", :description => 'First very useful publication'},
                  pub2.id.to_s => {:title => 'Pub2', :publisher => 'Publisher2 ltd.', :day => 2, :month => 1, :year => 2009, :url => "http://public2.url", :authors => "Author2", :description => 'Second very useful publication'}
                } },
              manager_question.id.to_s => {
                "new_manager_attributes" =>[{:first_name => "Name", :last_name => 'Last', :email => 'email@example.com'}],
              }
            }, :section_id => edu_question.section.id}
          end
        end
      end
    end
  end

  def test_remove_all_experiences
    current_user_is :f_mentor
    ed = members(:f_mentor).educations.first
    assert_equal 3, members( :f_mentor).experiences.count
    assert_equal 3, members( :f_mentor).educations.count
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { :id => members(:f_mentor), :role => "mentor", :profile_answers => {
      profile_questions(:multi_education_q).id.to_s => {
        :existing_education_attributes => {
          ed.id.to_s => {:school_name => ed.school_name, :degree => ed.degree, :major => ed.major, :graduation_year => ed.graduation_year}},
        :hidden => ""},
      profile_questions(:multi_experience_q).id.to_s => {:hidden => ""},
      profile_questions(:experience_q).id.to_s => {:hidden => ""},
      profile_questions(:education_q).id.to_s => {:hidden => ""}
      }, :section_id => profile_questions(:multi_education_q).section.id}
    assert_equal 0, members( :f_mentor).reload.experiences.count
    assert_equal 1, members( :f_mentor).reload.educations.count
  end

  def test_remove_all_educations
    current_user_is :f_mentor
    exp = members(:f_mentor).experiences.first
    assert_equal 3, members( :f_mentor).experiences.count
    assert_equal 3, members( :f_mentor).educations.count
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { :id => members(:f_mentor), :role => "mentor", :profile_answers => {
      profile_questions(:multi_experience_q).id.to_s => {
        :existing_experience_attributes => {exp.id.to_s => {:start_year => exp.start_year, :end_year => exp.end_year, :current_job => exp.current_job, :company => exp.company, :job_title => exp.job_title}},
        :hidden => ""},
      profile_questions(:multi_education_q).id.to_s => {:hidden => ""},
      profile_questions(:experience_q).id.to_s => {:hidden => ""},
      profile_questions(:education_q).id.to_s => {:hidden => ""}
      }, :section_id => profile_questions(:multi_experience_q).section.id}

    assert_equal 1, members( :f_mentor).reload.experiences.count
    assert_equal 0, members( :f_mentor).reload.educations.count
  end

  def test_remove_all_publications
    current_user_is :f_mentor
    pub = members(:f_mentor).publications.first
    assert_equal 3, members( :f_mentor).experiences.count
    assert_equal 3, members( :f_mentor).educations.count
    assert_equal 3, members( :f_mentor).publications.count
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { :id => members(:f_mentor), :role => "mentor", :profile_answers => {
      profile_questions(:multi_publication_q).id.to_s => {
        :existing_publication_attributes => {pub.id.to_s => {:title => pub.title, :publisher => pub.publisher, :year => pub.year, :month => pub.month, :day => pub.day, :url => pub.url, :authors => pub.authors, :description => pub.description}},
        :hidden => ""},
      profile_questions(:multi_publication_q).id.to_s => {:hidden => ""},
      profile_questions(:experience_q).id.to_s => {:hidden => ""},
      profile_questions(:education_q).id.to_s => {:hidden => ""},
      profile_questions(:publication_q).id.to_s => {:hidden => ""}
      }, :section_id => profile_questions(:multi_experience_q).section.id}

    assert_equal 2, members( :f_mentor).reload.experiences.count
    assert_equal 2, members( :f_mentor).reload.educations.count
    assert_equal 0, members( :f_mentor).reload.publications.count
  end

  def test_remove_all_experiences_and_educations_and_publications
    current_user_is :f_mentor
    assert_equal 3, members( :f_mentor).experiences.count
    assert_equal 3, members( :f_mentor).educations.count
    assert_equal 3, members( :f_mentor).publications.count
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { :id => members(:f_mentor), :role => "mentor", :profile_answers => {
      profile_questions(:multi_experience_q).id.to_s => {:hidden => ""},
      profile_questions(:multi_education_q).id.to_s => {:hidden => ""},
      profile_questions(:multi_publication_q).id.to_s => {:hidden => ""},
      profile_questions(:experience_q).id.to_s => {:hidden => ""},
      profile_questions(:publication_q).id.to_s => {:hidden => ""},
      profile_questions(:education_q).id.to_s => {:hidden => ""}
    }, :section_id => profile_questions(:multi_experience_q).section.id}
    assert_equal 0, members( :f_mentor).reload.experiences.count
    assert_equal 0, members( :f_mentor).reload.educations.count
    assert_equal 0, members( :f_mentor).reload.publications.count
  end

  def test_profile_completion_permission_enabled
    current_user_is :f_student
    assert programs(:org_primary).profile_completion_alert_enabled?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    get :show, params: { :id => members(:f_student).id}
    assert_select "div.profile_status_box" do
      assert_select ".completion_stats", :text => /Your profile is/
    end
  end

  def test_profile_completion_permission_disabled
    current_user_is :f_student
    programs(:org_primary).enable_feature(FeatureName::PROFILE_COMPLETION_ALERT, false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    get :show, params: { :id => members(:f_student).id}
    assert_no_select "div.profile_status_box"
  end

  def test_member_should_get_first_visit_custom_profile_fields
    current_member_is :student_11
    create_student_question
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :section => MembersController::EditSection::PROFILE, :id => members(:student_11), :first_visit => 'mentee'}
    assert_response :success
    assert_template 'edit_first_visit'

    assert_select 'form.form-horizontal' do
      assert_select 'input[type=hidden][name=first_visit][value=mentee]'
    end
  end

  ##############################################################################
  # MEMBER UPDATE
  ##############################################################################

  def test_member_should_not_delete_user_education_experience_and_pbulication
    current_user_is :f_mentor
    user = users(:f_mentor)
    member = user.member

    # User has educations and experiences
    assert member.educations.any?
    assert member.experiences.any?
    assert member.publications.any?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, xhr: true, params: { :id => members(:f_mentor).id,
      :member => {:last_name => "Myname"}
    }

    user.reload
    assert !member.educations.empty?
    assert !member.experiences.empty?
    assert !member.publications.empty?
  end

  def test_member_update_requires_login
    current_organization_is :org_primary

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, params: { :id => members(:rahim), :member => {:last_name => "my new name"}}
    assert_redirected_to new_session_path
  end

  def test_member_admin_should_be_able_to_update_student_profile
    current_user_is :f_admin

    assert members(:rahim).is_student?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    assert_no_emails do
      post :update, xhr: true, params: { :id => members(:rahim), :member => {:first_name => "my new", :last_name => "name"}}
    end

    assert_response :success
    assert_equal members(:rahim), assigns(:profile_member)
    members(:rahim).reload

    assert_equal "my new name", members(:rahim).name
    assert assigns(:unanswered_questions).present?
  end

  def test_member_admin_should_be_able_to_update_student_profile_with_email
    current_user_is :f_admin

    assert members(:rahim).is_student?
    old_email = members(:rahim).email
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    assert_emails 1 do
      post :update, xhr: true, params: { :id => members(:rahim), :member => {:email => "new_email@gmail.com"}}
    end

    assert_response :success
    assert_equal members(:rahim), assigns(:profile_member)
    members(:rahim).reload
    assert_equal "new_email@gmail.com", members(:rahim).email
    assert_equal members(:f_admin), assigns(:profile_member).email_changer

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal old_email, delivered_email.to[0]
  end

  def test_member_admin_should_be_able_to_update_mentor_profile
    current_user_is :f_admin

    assert members(:f_mentor).is_mentor?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, xhr: true, params: { :id => members(:f_mentor), :member => {:first_name => "new Mentor", :last_name => "name"}}

    assert_response :success
    assert_equal members(:f_mentor), assigns(:profile_member)
    members(:f_mentor).reload

    assert_equal "new Mentor name", members(:f_mentor).name
  end

  def test_member_should_update_the_student_profile_for_first_visit_and_redirect_to_answers_page_if_there_are_questions
    current_user_is :f_mentor
    programs(:org_primary).profile_questions << create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :program => programs(:albers))

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, params: { :id => members(:f_mentor), :first_visit => 'mentor', :member => {:first_name => "New", :last_name => "Name" }}

    assert_redirected_to edit_member_path(
      members(:f_mentor),
      :section => MembersController::EditSection::PROFILE,
      :first_visit => 'mentor', ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)

    assert_equal('New Name', assigns(:profile_member).name)
  end

  ##############################################################################
  # MEMBER PROFILE UPDATE
  ##############################################################################

  def test_member_profile_completion_refetches_answers
    current_user_is :f_mentor
    q = create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::TEXT)
    q.section = programs(:org_primary).sections.last
    q.save!
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update_answers, xhr: true, params: { :id => users(:f_mentor).id, :profile_answers => { q.id => "Test" }, :section_id => q.section.id, :prof_c => "true"}
    assert_response :success
    assert assigns(:is_profile_completion)
    assert assigns(:unanswered_questions).present?
  end

  def test_member_basic_info_profile_completion_refetches_answers
    current_user_is :f_mentor
    q = create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::TEXT)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => users(:f_mentor).id, :profile_answers => { q.id => "Test" }, :section_id => q.section.id, :prof_c => "true"}
    assert_response :success
    assert assigns(:is_profile_completion)
  end

  def test_redirected_to_program_root_path_when_user_tries_to_skip_required_fields_while_editing_profile
    current_user_is :f_mentor

    q = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true)

    programs(:albers).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { id: users(:f_mentor).id, profile_answers: { q.id => [""] }, section_id: q.section.id, prof_c: 'true'}
    assert_redirected_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
  end

  def test_member_should_raise_a_flash_when_user_tries_to_skip_required_fields_while_editing_profile_in_first_visit_and_is_redirected_to_edit_first_time_experience
    current_user_is :f_mentor
    q = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true)

    programs(:albers).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { :id => users(:f_mentor).id, :profile_answers => { q.id => [""] }, :first_visit => true}
    assert_equal "Required fields cannot be blank", flash[:error]
    assert_redirected_to edit_member_path(users(:f_mentor), :first_visit => true,
      :section => MembersController::EditSection::PROFILE, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_member_admin_tries_to_skip_required_fields_while_editing_end_user_profile_success
    current_user_is :f_admin

    q = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    programs(:albers).reload
    post :update_answers, params: { id: users(:f_mentor).id, profile_answers: { q.id => [""] }, section_id: q.section.id, prof_c: 'true'}
    assert_nil flash[:error]
  end

  def test_member_admin_tries_to_skip_required_fields_while_editing_end_user_profile_in_first_visit_success
    current_user_is :f_admin
    q = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    programs(:albers).reload
    post :update_answers, params: { :id => users(:f_mentor).id, :profile_answers => { q.id => [""] }, :first_visit => true}
    assert_nil flash[:error]
  end

  def test_member_change_pending_to_active_for_all_users_once_the_profile_is_complete
    q1 = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true,
      :program => programs(:albers))

    programs(:albers).reload
    current_user_is users(:mentor_3)

    # The new required question is not answered yet.
    assert users(:f_mentor).profile_incomplete_roles.any?
    assert users(:mentor_3).profile_incomplete_roles.any?

    users(:f_mentor).update_attribute :state, User::Status::PENDING
    users(:mentor_3).update_attribute :state, User::Status::PENDING

    assert_equal User::Status::PENDING, users(:f_mentor).reload.state
    assert_equal User::Status::PENDING, users(:mentor_3).reload.state

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).once
    post :update_answers, params: { :id => members(:mentor_3).id, :profile_answers => { q1.id => "A" }, :first_visit => true}
    assert_equal User::Status::PENDING, users(:f_mentor).reload.state
    assert_equal User::Status::ACTIVE, users(:mentor_3).reload.state
  end

  def test_program_questions_for_user_first_visit
    section = sections(:section_albers)
    q1 = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true,
      :program => programs(:albers),
      section: section)

    programs(:albers).reload
    current_user_is users(:mentor_3)

    program_questions_for_user =  programs(:albers).profile_questions_for(users(:mentor_3).role_names, {:default => false, :skype => programs(:albers).organization.skype_enabled?, user: users(:mentor_3), pq_translation_include: true})
    @controller.stubs(:handle_answered_and_conditional_questions).with(members(:mentor_3), program_questions_for_user, members(:mentor_3).answered_profile_questions).returns([q1])

    get :edit, params: { :id =>  members(:mentor_3).id, :first_visit => 'true'}
    assert_equal [q1], assigns(:program_questions_for_user)
  end

  def test_member_posting_update_to_mentor_custom_fields_should_update_create_non_existent_answers_and_update_existing_answers
    current_user_is :f_mentor
    DelayedEsDocument.expects(:delayed_update_es_document).with(User, users(:f_mentor).id).never
    DelayedEsDocument.expects(:delayed_update_es_document).with(User, users(:f_mentor_nwen_student).id).never
    programs(:org_primary).profile_questions.destroy_all
    ProfileAnswer.destroy_all
    questions = []
    2.times { questions << create_question(:role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers)) }
    questions << create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :program => programs(:albers))

    questions << create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::MULTI_CHOICE,
      :question_choices => ["A", "B", "C", "D", "E", "F", "G"],
      :program => programs(:albers))

    ProfileAnswer.create!(:ref_obj => members(:f_mentor), :profile_question => questions[0], :answer_text => "Old answer")
    ProfileAnswer.create!(:ref_obj => members(:f_mentor), :profile_question => questions[2], :answer_value => "B")

    # 2 questions already have answers
    assert_equal('Old answer', users(:f_mentor).answer_for(questions[0]).answer_text)
    assert_equal('B', users(:f_mentor).answer_for(questions[2]).answer_value)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    DelayedEsDocument.expects(:delayed_update_es_document).with(User, users(:f_mentor).id).times(2)
    DelayedEsDocument.expects(:delayed_update_es_document).with(Member, members(:f_mentor).id).once
    # 2 new answers should be created, the rest 2 are updated.
    assert_difference 'ProfileAnswer.count', 2 do
      post :update, xhr: true, params: { :id => users(:f_mentor).id, :profile_answers => {
        questions[0].id => "Answer 1",
        questions[1].id => "Answer 2",
        questions[2].id => "A",
        questions[3].id => [ 'C', 'E', 'G' ]
      }, :section_id => questions[0].section.id}
    end

    answers = members(:f_mentor).reload.profile_answers
    assert_equal(4, answers.size)
    assert_equal('Answer 1', users(:f_mentor).answer_for(questions[0]).answer_text)
    assert_equal('Answer 2', users(:f_mentor).answer_for(questions[1]).answer_text)
    assert_equal('A', users(:f_mentor).answer_for(questions[2]).answer_value)
    assert_equal(["C", "E", "G"], users(:f_mentor).answer_for(questions[3]).answer_value)
  end

  def test_should_remove_not_required_file_type_question
    current_user_is :f_mentor
    programs(:org_primary).profile_questions.destroy_all
    ProfileAnswer.destroy_all
    questions = []
    2.times { questions << create_question(:role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers)) }
    questions <<  create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :required => false)

    answer = ProfileAnswer.create!(:ref_obj => members(:f_mentor), :profile_question => questions[2], :answer_value => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    assert_equal(answer, users(:f_mentor).answer_for(questions[2]))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => users(:f_mentor).id, :profile_answers => {
      questions[0].id => "Answer 1"
    }, :persisted_files => { questions[2].id => "0" }, :section_id => questions[0].section.id}

    assert_equal('Answer 1', users(:f_mentor).answer_for(questions[0]).answer_text)
    assert_nil(users(:f_mentor).answer_for(questions[2]))
  end

  def test_should_not_remove_required_file_type_question
    current_user_is :f_mentor
    programs(:org_primary).profile_questions.destroy_all
    ProfileAnswer.destroy_all
    questions = []
    2.times { questions << create_question(:role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers)) }
    questions <<  create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :required => true)

    answer = ProfileAnswer.create!(:ref_obj => members(:f_mentor), :profile_question => questions[2], :answer_value => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    assert_equal(answer, users(:f_mentor).answer_for(questions[2]))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => users(:f_mentor).id, :profile_answers => {
      questions[0].id => "Answer 1"
    }, :persisted_files => { questions[2].id => "0" }, :section_id => questions[0].section.id}

    assert_equal('Answer 1', users(:f_mentor).answer_for(questions[0]).answer_text)
    assert_equal(answer, users(:f_mentor).answer_for(questions[2]))
  end

  def test_should_not_remove_not_editable_question
    current_user_is :f_mentor
    programs(:org_primary).profile_questions.destroy_all
    ProfileAnswer.destroy_all
    questions = []
    2.times { questions << create_question(:role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers)) }
    questions <<  create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :required => false)

    answer = ProfileAnswer.create!(:ref_obj => members(:f_mentor), :profile_question => questions[2], :answer_value => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    assert_equal(answer, users(:f_mentor).answer_for(questions[2]))
    ProfileQuestion.any_instance.stubs(:editable_by?).returns(false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => users(:f_mentor).id, :persisted_files => { questions[2].id => "0" }, :section_id => questions[0].section.id}

    assert_equal(answer, users(:f_mentor).answer_for(questions[2]))
  end

  def test_should_not_remove_question_if_it_is_updated
    current_user_is :f_mentor
    programs(:org_primary).profile_questions.destroy_all
    ProfileAnswer.destroy_all
    questions = []
    2.times { questions << create_question(:role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers)) }
    questions <<  create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :required => false)

    answer = ProfileAnswer.create!(:ref_obj => members(:f_mentor), :profile_question => questions[2], :answer_value => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    assert_equal(answer, users(:f_mentor).answer_for(questions[2]))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => users(:f_mentor).id, :profile_answers => {
      questions[2].id => "test_pic.png"
    }, :persisted_files => { questions[2].id => "0" }, :section_id => questions[0].section.id}

    assert_not_equal(answer.answer_value, users(:f_mentor).answer_for(questions[2]).answer_value)
    assert_equal(answer.id, users(:f_mentor).answer_for(questions[2]).id)
    assert_equal "Required fields cannot be blank", flash[:error]
  end

  def test_should_remove_only_unchecked_file_question
    current_user_is :f_mentor
    programs(:org_primary).profile_questions.destroy_all
    ProfileAnswer.destroy_all
    questions = []
    2.times { questions << create_question(:role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers), :required => false) }
    questions <<  create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :required => false)

    answer = ProfileAnswer.create!(:ref_obj => members(:f_mentor), :profile_question => questions[2], :answer_value => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    assert_equal(answer, users(:f_mentor).answer_for(questions[2]))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => users(:f_mentor).id, :profile_answers => {
      questions[0].id => "Answer 1"
    }, :persisted_files => { questions[2].id => "0", questions[0].id => "1" }, :section_id => questions[0].section.id}

    assert_equal('Answer 1', users(:f_mentor).answer_for(questions[0]).answer_text)
    assert_nil(users(:f_mentor).answer_for(questions[2]))
  end

  def test_member_should_redirect_to_next_section_and_not_set_any_flash_on_first_visit_answers_update
    current_user_is :mentor_5
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update_answers, params: { id: members(:mentor_5).id, section: MembersController::EditSection::PROFILE, first_visit: 'mentor', profile_answers: {
      profile_questions(:string_q).id => "First Answer",
      profile_questions(:single_choice_q).id => "opt_2",
      profile_questions(:multi_choice_q).id => "Walk"
    }}

    assert_redirected_to edit_member_path(id: members(:mentor_5).id, first_visit: 'mentor',
      section: MembersController::EditSection::PROFILE, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_nil flash[:notice]
    user = users(:mentor_5).reload
    member = user.member
    assert_equal(3, member.profile_answers.size)
    assert_equal('First Answer', user.answer_for(profile_questions(:string_q)).answer_text)
    assert_equal('opt_2', user.answer_for(profile_questions(:single_choice_q)).answer_value)
    assert_equal(['Walk'], user.answer_for(profile_questions(:multi_choice_q)).answer_value)
  end

  def test_member_should_redirect_to_next_section
    current_user_is :mentor_5
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update_answers, params: { :id => members(:mentor_5), section: MembersController::EditSection::PROFILE, :first_visit => 'mentor', :profile_answers => {
      profile_questions(:string_q).id => "First Answer"}}
    assert_redirected_to edit_member_path(:id => members(:mentor_5).id, :first_visit => 'mentor',
      :section => MembersController::EditSection::PROFILE, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_nil flash[:notice]
    user = users(:mentor_5).reload
    member = user.member
    assert_equal(1, member.profile_answers.size)
    assert_equal('First Answer', user.answer_for(profile_questions(:string_q)).answer_text)
  end

  def test_member_should_redirect_to_edit_page_mentoring_settings_section_after_the_last_section
    current_user_is :mentor_5
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update_answers, params: { :id => members(:mentor_5), :first_visit => 'mentor', :profile_answers => {
      profile_questions(:string_q).id => "First Answer"}, :last_section => "true"}

    assert_redirected_to edit_member_path(:id => members(:mentor_5).id, :first_visit => 'mentor',
      :section => MembersController::EditSection::MENTORING_SETTINGS, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_get_mentor_edit_during_first_visit_mentoring_settings_section
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :section => MembersController::EditSection::MENTORING_SETTINGS, :id => members(:f_mentor), :first_visit => 1}
    assert_response :success
    assert_template 'edit_first_visit'
    assert assigns(:is_first_visit)
    assert_select 'html' do
      assert_select 'div#title_box' do
        assert_select '.lead', "Complete Your  Profile"
      end

      assert_select "input[type=?][value='Save & Proceed »']", 'submit'
      assert_select "input#max_connections_limit[value='#{users(:f_mentor).max_connections_limit}']"
    end

    assert_equal MembersController::EditSection::MENTORING_SETTINGS, assigns(:section)
  end

  def test_member_should_redirect_to_program_root_path_after_the_mentoring_section
    current_user_is :mentor_5
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    put :update, params: {
      id: members(:mentor_5),
      first_visit: :mentor,
      last_section: true,
      section: MembersController::EditSection::MENTORING_SETTINGS,
      user: {user_settings: {max_meeting_slots: 6}},
      member: {will_set_availability_slots: false, availability_not_set_message: "monday-friday"}
    }

    assert assigns(:is_first_visit)
    assert assigns(:profile_member)
    assert_not_nil assigns(:profile_user)
    user_setting = UserSetting.find_by(user_id: assigns(:profile_user).id)
    assert_not_nil user_setting
    assert_equal 6, user_setting.max_meeting_slots
    assert_redirected_to program_root_path(from_first_visit: 'mentor')
  end

  def test_member_should_redirect_to_mentoring_section_after_calendar_sync_v2_settings
    Program.any_instance.stubs(:calendar_sync_v2_enabled?).returns(true)
    current_user_is :mentor_5
    member = members(:mentor_5)

    put :update, params: {
      id: member.id,
      first_visit: :mentor,
      last_section: true,
      section: MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS
    }

    assert assigns(:is_first_visit)
    assert_redirected_to edit_member_path(id: member.id, ei_src: "fir", first_visit: "mentor", section: MembersController::EditSection::MENTORING_SETTINGS)
  end

  def test_mentee_should_redirect_to_program_root_path_after_the_mentoring_section
    current_user_is :f_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    put :update, params: {
      id: members(:f_student),
      first_visit: :student,
      last_section: true,
      section: MembersController::EditSection::MENTORING_SETTINGS,
      member: {availability_not_set_message: "monday-friday"}
    }

    assert assigns(:is_first_visit)
    assert_redirected_to program_root_path(from_first_visit: 'student')
  end

  def test_mentee_should_redirect_to_program_root_path_after_calendar_sync_v2_success
    Program.any_instance.expects(:calendar_sync_v2_enabled?).returns(true)
    Member.any_instance.stubs(:synced_external_calendar?).returns(true)
    current_user_is :f_student

    put :update, params: {
      id: members(:f_student),
      first_visit: :student,
      last_section: true,
      section: MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS
    }

    assert assigns(:is_first_visit)
    assert_redirected_to program_root_path(from_first_visit: 'student')
  end

  def test_mentor_student_changing_email_question_and_common_profile_question
    user = users(:f_mentor_student)
    current_user_is user
    student_phone = programs(:albers).sections_for(["student"]).first.profile_questions.last
    student_phone.update_attribute(:question_text, "Student Phone")
    mentor_phone = programs(:albers).sections_for(["mentor"]).first.profile_questions.last
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    assert_difference 'ProfileAnswer.count', 1 do
      post :update, xhr: true, params: { :id => members(:f_mentor_student), :profile_answers => {student_phone.id => "1234", mentor_phone.id => "345"},
        :section_id => student_phone.section.id
      }
    end
    user.reload
    assert_equal user.answer_for(student_phone).answer_text, "345"
    assert_equal user.answer_for(mentor_phone).answer_text, "345"
  end

  def test_mentor_member_should_be_redirected_to_edit_page_when_section_has_file_upload
    current_user_is :f_mentor

    q = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true)

    programs(:albers).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { id: users(:f_mentor).id, profile_answers: { q.id => [""] }, section_id: q.section.id, file_present: true}
    assert_redirected_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
  end

  def test_mentor_member_should_be_redirected_to_program_root_path_when_section_has_file_upload_and_user_is_completing_his_profile
    current_user_is :f_mentor

    q = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true)

    programs(:albers).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { prof_c: "true", id: users(:f_mentor).id, profile_answers: { q.id => [""] }, section_id: q.section.id, file_present: true}
    assert_redirected_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
  end

  def test_mentee_member_should_be_redirected_to_edit_page_when_section_has_file_upload
    current_user_is :f_student

    q = create_question(
      :role_names => [RoleConstants::STUDENT_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true)

    programs(:albers).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { id: users(:f_student).id, profile_answers: { q.id => [""] }, section_id: q.section.id, file_present: true}
    assert_redirected_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
  end

  def test_mentee_member_should_be_redirected_to_complete_page_when_section_has_file_upload_and_user_is_completing_his_profile
    current_user_is :f_mentor

    q = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true)

    programs(:albers).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { prof_c: "true", id: users(:f_mentor).id, profile_answers: { q.id => [""] }, section_id: q.section.id, file_present: true}
    assert_redirected_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
  end

  def test_file_attachment_unsupported
    current_user_is :f_mentor
    q = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true)

    programs(:albers).reload
    post :upload_answer_file, xhr: true, params: { id: users(:f_mentor).id, question_id: q.id, profile_answers: { q.id.to_s => fixture_file_upload(File.join('files', 'test_php.php'), 'application/x-php') }, section_id: q.section.id, file_present: true}
    assert assigns(:file_uploader).errors.present?
  end

  def test_file_attachment_unsupported_octet_stream
    current_user_is :f_mentor
    q = create_question(
      :role_names => [RoleConstants::MENTOR_NAME],
      :question_type => ProfileQuestion::Type::FILE,
      :question_choices => ["A", "B", "C", "E", "F"],
      :required => true)

    programs(:albers).reload
    post :upload_answer_file, xhr: true, params: { id: users(:f_mentor).id, question_id: q.id, profile_answers: { q.id.to_s => fixture_file_upload(File.join('files', 'test_php.php'), 'application/octet-stream') }, section_id: q.section.id, file_present: true}
    assert assigns(:file_uploader).errors.present?
  end

  #
  #  ##############################################################################
  #  # USER EDIT
  #  #############################################################################

  def test_show_skype_on_profile_edit_page
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'edit'
    assert_select "div#mentor_profile" do
      # FIXME education and experience + basic profile + mentor profile(4) +  settings(1-3) + notifications(1-2)
      assert_select "div.ibox", :count => 8
      assert_select "div.tabs-container-edit-profile" do
      assert_select "div.ibox:nth-of-type(1)" do
        assert_select "div.ibox-title", :text => /Basic Information/
        assert_select "input#profile_answers_#{programs(:org_primary).profile_questions.skype_question.first.id}"
      end
    end
    end
  end

  def test_should_not_show_skype_on_profile_edit_page_when_feature_disabled
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION, false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'edit'
    assert_select "div#mentor_profile" do
      # FIXME education and experience + basic profile + mentor profile(4) +  settings(1-3) + notifications(1-2)
      assert_select "div.ibox", :count => 8
      assert_select "div.tabs-container-edit-profile" do
      assert_select "div.ibox:nth-of-type(1)" do
        assert_select "div.ibox-title", :text => /Basic Information/
        assert_no_select "input#profile_answers_#{programs(:org_primary).profile_questions.skype_question.first.id}"
      end
    end
    end
  end


  def test_should_check_if_right_subsections_are_rendered_for_settings_and_notification
    member = members(:f_admin)
    current_user_is :f_admin
    get :edit, params: { :id => members(:f_admin).id}
    assert_response :success

    assert_select "div#notifications_tab" do
      assert_select "div.ibox" , :count => 2
    end


    assert_select "div#settings_tab" do
      assert_select "div.ibox" , :count => 1
    end

    current_user_is :f_mentor
    User.any_instance.stubs(:is_mentor?).returns(false)
    get :edit, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_select "div#settings_tab" do
      assert_select "div.ibox" , :count => 1
      assert_select "div.ibox#settings_section_general" , :count => 1
      assert_select "div.ibox#settings_section_ongoing" , :count => 0
      assert_select "div.ibox#settings_section_onetime" , :count => 0
    end

    Program.any_instance.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    get :edit, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_select "div#settings_tab" do
      assert_select "div.ibox" , :count => 1
      assert_select "div.ibox#settings_section_general" , :count => 1
      assert_select "div.ibox#settings_section_ongoing" , :count => 0
      assert_select "div.ibox#settings_section_onetime" , :count => 0
    end

    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    User.any_instance.stubs(:is_mentor?).returns(true)
    get :edit, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_select "div#settings_tab" do
      assert_select "div.ibox" , :count => 2
      assert_select "div.ibox#settings_section_general" , :count => 1
      assert_select "div.ibox#settings_section_ongoing" , :count => 0
      assert_select "div.ibox#settings_section_onetime" , :count => 1
    end

    User.any_instance.stubs(:is_mentor?).returns(true)
    Program.any_instance.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(true)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    get :edit, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_select "div#settings_tab" do
      assert_select "div.ibox" , :count => 3
      assert_select "div.ibox#settings_section_general" , :count => 1
      assert_select "div.ibox#settings_section_ongoing" , :count => 1
      assert_select "div.ibox#settings_section_onetime" , :count => 1
    end

    User.any_instance.stubs(:is_mentor?).returns(true)
    Program.any_instance.stubs(:calendar_sync_v2_enabled?).returns(true)
    get :edit, params: { :id => members(:f_mentor).id }
    assert_response :success
    assert_select "div#settings_tab" do
      assert_select "div.ibox" , :count => 4
      assert_select "div.ibox#settings_section_general" , :count => 1
      assert_select "div.ibox#settings_section_ongoing" , :count => 1
      assert_select "div.ibox#settings_section_onetime" , :count => 1
      assert_select "div.ibox#calendar_sync_v2_settings" , :count => 1
    end

    User.any_instance.stubs(:is_mentor?).returns(true)
    Program.any_instance.stubs(:calendar_sync_v2_enabled?).returns(true)
    Program.any_instance.stubs(:organization_wide_calendar_access_enabled?).returns(true)
    get :edit, params: { id: members(:f_mentor).id }
    assert_response :success
    assert_select "div#settings_tab" do
      assert_select "div.ibox" , :count => 3
      assert_select "div.ibox#settings_section_general" , :count => 1
      assert_select "div.ibox#settings_section_ongoing" , :count => 1
      assert_select "div.ibox#settings_section_onetime" , :count => 1
    end
  end

  def test_user_notification_permission_denied
    current_user_is :f_student
    user = users(:f_admin)
    assert_no_difference "UserNotificationSetting.count" do
      assert_permission_denied do
        patch :update_notifications, xhr: true, params: { id: user.id , "setting_name" => UserNotificationSetting::SettingNames::END_USER_COMMUNICATION,"value" =>  "false" }
      end
    end
  end

  def test_should_check_user_notification_values_updated_correctly
    current_user_is :f_admin
    user = users(:f_admin)
    patch :update_notifications, xhr: true, params: { :id => user.id, "setting_name" => UserNotificationSetting::SettingNames::END_USER_COMMUNICATION, "value" =>  "false" }
    patch :update_notifications, xhr: true, params: { :id => user.id, "setting_name" => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT, "value" =>  "false"}
    patch :update_notifications, xhr: true, params: { :id => user.id, "setting_name" => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT, "value" =>  "true"}
    patch :update_notifications, xhr: true, params: { :id => user.id, "setting_name" => UserNotificationSetting::SettingNames::DIGEST_AND_ALERTS, "value" =>  "false"}
    assert_equal UserNotificationSetting.find_by(:notification_setting_name => UserNotificationSetting::SettingNames::END_USER_COMMUNICATION,:user_id =>user.id).disabled, true
    assert_equal UserNotificationSetting.find_by(:notification_setting_name => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT,:user_id =>user.id).disabled, false
    assert_equal UserNotificationSetting.find_by(:notification_setting_name => UserNotificationSetting::SettingNames::DIGEST_AND_ALERTS,:user_id =>user.id).disabled, true
  end

  def test_should_check_if_user_function_for_notification_value_gives_correct_answer
    current_user_is :f_admin
    user = users(:f_admin)
    patch :update_notifications, xhr: true, params: { :id => user.id, "setting_name" => UserNotificationSetting::SettingNames::END_USER_COMMUNICATION, "value" =>  "false" }
    patch :update_notifications, xhr: true, params: { :id => user.id, "setting_name" => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT, "value" =>  "false"}
    patch :update_notifications, xhr: true, params: { :id => user.id, "setting_name" => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT, "value" =>  "true"}
    patch :update_notifications, xhr: true, params: { :id => user.id, "setting_name" => UserNotificationSetting::SettingNames::DIGEST_AND_ALERTS, "value" =>  "false"}
    assert_equal user.is_notification_disabled_for?(UserNotificationSetting::SettingNames::END_USER_COMMUNICATION), true
    assert_equal user.is_notification_disabled_for?(UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT), false
    assert_equal user.is_notification_disabled_for?(UserNotificationSetting::SettingNames::DIGEST_AND_ALERTS), true
  end

  def test_should_assign_profile_roles_on_editing_user_settings_correctly
    current_user_is :f_admin
    mentor_1 = users(:mentor_2)
    user = users(:mentor_2) 
    assert_not_equal users(:mentor_2) , assigns(:profile_user)
    assert_nil assigns(:profile_user)
    get :edit, params: { :id => members(:mentor_2).id}
    assert_response :success
    assert_not_nil assigns(:profile_user)
    assert_equal users(:mentor_2) , assigns(:profile_user)
    put :update_settings, xhr: true, params: { :id => user.id,:member => {:will_set_availability_slots => false, :availability_not_set_message => "Please contact me directly"}}
    assert_equal users(:mentor_2) , assigns(:profile_user)
    assert_not_nil :profile_user
  end


  def test_should_not_show_email_as_editable_on_profile_edit_page_when_marked_as_admin_only_editable
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).twice

    get :edit, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'edit'
    assert_select "div#mentor_profile" do
      assert_select "div.tabs-container-edit-profile" do
      assert_select "div.ibox:nth-of-type(1)" do
        assert_select "div.ibox-title", :text => /Basic Information/
        assert_select "input#member_email"
      end
    end
    end

    programs(:org_primary).profile_questions_with_email_and_name.email_question.first.role_questions.each do |rq|
      rq.update_attributes!(:admin_only_editable => true)
    end

    get :edit, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'edit'
    assert_select "div#mentor_profile" do
      assert_select "div.tabs-container-edit-profile" do
      assert_select "div.ibox:nth-of-type(1)" do
        assert_select "div.ibox-title", :text => /Basic Information/
        assert_select "input#member_email[type=hidden]"
      end
    end
    end

  end

  def test_should_not_show_name_as_editable_on_profile_edit_page_when_marked_as_admin_only_editable
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).twice

    get :edit, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'edit'
    assert_select "div#mentor_profile" do
      assert_select "div.tabs-container-edit-profile" do
      assert_select "div.ibox:nth-of-type(1)" do
        assert_select "div.ibox-title", :text => /Basic Information/
        assert_select "input#member_first_name"
        assert_select "input#member_last_name"
      end
    end
    end

    programs(:org_primary).profile_questions_with_email_and_name.name_question.first.role_questions.each do |rq|
      rq.update_attributes!(:admin_only_editable => true)
    end

    get :edit, params: { :id => members(:f_mentor).id}
    assert_response :success
    assert_template 'edit'
    assert_select "div#mentor_profile" do
      assert_select "div.tabs-container-edit-profile" do
      assert_select "div.ibox:nth-of-type(1)" do
        assert_select "div.ibox-title", :text => /Basic Information/
        assert_select "input#member_first_name[type=hidden]"
        assert_select "input#member_last_name[type=hidden]"
      end
    end
    end

  end

  def test_should_show_current_experience_in_edit
    current_user_is :f_mentor
    user = users(:f_mentor)
    member = user.member
    multi_exp_q = profile_questions(:multi_experience_q)
    exp_q = profile_questions(:experience_q)
    member.experiences.all.collect(&:destroy)
    assert_equal(0, member.reload.experiences.size)
    e1 = create_experience(user, multi_exp_q, :start_year => 1999, :end_year => 2003)
    e2 = create_experience(user, multi_exp_q, :start_year => 2004, :end_year => nil,  :current_job => true)
    e3 = create_experience(user, multi_exp_q, :start_year => nil, :end_year => nil, :company => "Earth", :job_title => 'Man')
    e4 = create_experience(user, multi_exp_q, :start_year => nil, :end_year => nil,  :current_job => true, :company => "Universe", :job_title => 'Soul')
    e5 = create_experience(user, exp_q, :start_year => 1986, :end_year => nil, :company => "Home", :job_title => 'Son')
    assert_equal(5, member.reload.experiences.size)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_mentor).id, :prof_c => true}

    assert_select "div#experience_#{e1.id}" do
      assert_select "select.start_year" do
        assert_select "option[value='1999'][selected=selected]"
      end
      assert_select "select.end_year" do
        assert_select "option[value='2003'][selected=selected]"
      end
    end

    assert_select "div#experience_#{e2.id}" do
      assert_select "select.start_year" do
        assert_select "option[value='2004'][selected=selected]"
      end
      assert_select "select.end_year" do
        assert_select "option[value='']", :text => "Year"
      end
    end

    assert_select "div#experience_#{e3.id}" do
      assert_select "select.start_year" do
        assert_select "option[value='']"
      end
      assert_select "select.end_year" do
        assert_select "option[value='']"
      end
    end

    assert_select "div#experience_#{e4.id}" do
      assert_select "select.start_year" do
        assert_select "option[value='']"
      end
      assert_select "select.end_year" do
        assert_select "option[value='']", :text => "Year"
      end
    end

    assert_select "div#experience_#{e5.id}" do
      assert_select "select.start_year" do
        assert_select "option[value='1986'][selected=selected]"
      end
      assert_select "select.end_year" do
        assert_select "option[value='']"
      end
    end
  end

  def test_should_allow_edit_only_for_owner_and_admin
    current_user_is :rahim

    # rahim is not the admin of the program
    assert !programs(:albers).admin_users.include?(users(:rahim))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    assert_permission_denied do
      # rahim is trying to edit ram's profile. Should result in Authorization error.
      get :edit, params: { :id => members(:ram)}
    end
  end

  def test_get_edit_student_profile
    current_user_is :f_admin

    assert users(:rahim).is_student?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never
    get :edit, params: { :id => members(:rahim)}
    assert_response :success
    assert_template 'edit'
    assert_select 'html'
    assert_equal users(:rahim), assigns(:profile_user)
    assert_equal MembersController::EditSection::GENERAL, assigns(:section)
  end

  def test_get_edit_mentor_profile
    current_user_is :f_admin
    mentor = users(:f_mentor)
    assert mentor.is_mentor_only?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    get :edit, params: { :id => mentor.member.id, :prof_c => true}
    assert_response :success
    assert_template 'edit'
    assert_select 'html'
    assert_equal mentor, assigns(:profile_user)
    assert_select "div#collapsible_section_content_#{sections(:sections_3).id}" do
      assert_select "form.form-horizontal" do
        assert_select ".question", :count => sections(:sections_3).profile_questions.size - 2 #Remove 2 student questions from section
        assert_select 'input[type=?][value=?]', 'submit', "Save"
      end
    end

    assert_select "div#general_profile" do
      assert_select ".question", :count => 3
    end

    assert_equal MembersController::EditSection::GENERAL, assigns(:section)
  end

  def test_get_edit_mentor_and_student_profile
    current_user_is :f_admin
    mentor_student = users(:f_mentor_student)
    assert mentor_student.is_mentor_and_student?
    more_info_section = programs(:org_primary).sections.readonly(false).find_by(title: "More Information")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never
    get :edit, params: { :id => mentor_student.member.id, :prof_c => true}
    assert_response :success
    assert_template 'edit'
    assert_select 'html'
    assert_equal mentor_student, assigns(:profile_user)

    assert_select "div#collapsible_section_content_#{sections(:sections_3).id}" do
      assert_select "form.form-horizontal" do
        assert_select ".question", :count => sections(:sections_3).profile_questions.size
        assert_select 'input[type=?][value=?]', 'submit', "Save"
      end
    end

    assert_select "div#collapsible_section_content_#{sections(:section_albers).id}" do
      assert_select "form.form-horizontal" do
        assert_select ".question", :count => more_info_section.profile_questions.size
        assert_select 'input[type=?][value=?]', 'submit', "Save"
      end
    end

    assert_select "div#general_profile" do
      assert_select ".question", :count => 3 # Email, Location and Phone
    end

    assert_equal MembersController::EditSection::GENERAL, assigns(:section)
  end

  def test_get_edit_mentor_student_profile_should_not_show_role_box
    current_user_is :f_admin
    mentor = users(:f_mentor)
    assert mentor.is_mentor_only?
    mentor.add_role(RoleConstants::STUDENT_NAME)
    assert mentor.is_mentor? && mentor.is_student?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    get :edit, params: { :id => mentor.member.id}
    assert_response :success
    assert_template 'edit'
    assert_select 'html'
    assert_equal mentor, assigns(:profile_user)
    assert_equal MembersController::EditSection::GENERAL, assigns(:section)
  end

  def test_should_get_edit_settings_page_for_mentor
    members(:f_mentor).update_attribute(:time_zone, "Asia/Kolkata")
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    program = programs(:albers)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { :section => MembersController::EditSection::SETTINGS, :id => members(:f_mentor).id}
    assert_template 'edit'
    assert_select "input#user_max_connections_limit[value='#{users(:f_mentor).max_connections_limit}']"
    assert_select "input#user_program_notification_setting_0_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_1_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_2_#{program.id}[type=radio]"
    assert_select "select#user_member_time_zone" do
      assert_select "option[value='Asia/Kolkata'][selected=selected]"
    end
    assert_section_expanded("Settings")
    assert_equal MembersController::EditSection::SETTINGS, assigns(:section)
  end

  def test_should_get_edit_settings_page_for_mentee
    members(:f_student).update_attribute(:time_zone, nil)
    current_user_is :f_student
    program = programs(:albers)
    users(:f_student).update_attribute(:program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { :section => MembersController::EditSection::SETTINGS, :id => members(:f_student).id}

    assert_template 'edit'
    assert_select "input#max_connections_limit[value='#{users(:f_mentor).max_connections_limit}']", :count => 0
    assert_select "input#user_program_notification_setting_0_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_1_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_2_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_3_#{program.id}[type=radio][checked=checked]"
    assert_no_select "input#user_needs_meeting_request_reminder[type=checkbox]"
    assert_select "select#user_member_time_zone" do
      assert_select "option[value=''][selected=selected]"
    end
    assert !assigns(:is_first_visit)
    assert_section_expanded("Settings")
    assert_equal MembersController::EditSection::SETTINGS, assigns(:section)
  end

  def test_should_get_edit_settings_page_for_mentee_when_program_matching_by_mentee_alone
    members(:f_student).update_attribute(:time_zone, nil)
    current_user_is :f_student
    program = programs(:albers)
    users(:f_student).update_attribute(:program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    programs(:org_primary).update_attribute(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_MENTOR)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { :section => MembersController::EditSection::SETTINGS, :id => members(:f_student).id}

    assert_template 'edit'
    assert_select "input#conn_limit[value='#{users(:f_mentor).max_connections_limit}']", :count => 0
    assert_select "input#user_program_notification_setting_0_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_1_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_2_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_3_#{program.id}[type=radio][checked=checked]"
    assert_no_select "input#user_needs_meeting_request_reminder[type=checkbox]"
    assert_select "select#user_member_time_zone" do
      assert_select "option[value=''][selected=selected]"
    end
    assert !assigns(:is_first_visit)
    assert_section_expanded("Settings")
    assert_equal MembersController::EditSection::SETTINGS, assigns(:section)
  end

  def test_should_get_edit_settings_page_for_mentee_when_program_matching_by_admin
    members(:f_student).update_attribute(:time_zone, nil)
    current_user_is :f_student
    program = programs(:albers)
    users(:f_student).update_attribute(:program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    programs(:org_primary).update_attribute(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_ADMIN)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { :section => MembersController::EditSection::SETTINGS, :id => members(:f_student).id}

    assert_template 'edit'
    assert_select "input#conn_limit[value='#{users(:f_mentor).max_connections_limit}']", :count => 0
    assert_select "input#user_program_notification_setting_0_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_1_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_2_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_3_#{program.id}[type=radio][checked=checked]"
    assert_no_select "input#user_needs_meeting_request_reminder[type=checkbox]"
    assert_select "select#user_member_time_zone" do
      assert_select "option[value=''][selected=selected]"
    end
    assert !assigns(:is_first_visit)
    assert_section_expanded("Settings")
    assert_equal MembersController::EditSection::SETTINGS, assigns(:section)
  end

  def test_should_get_edit_settings_page_for_admin
    members(:f_admin).update_attribute(:time_zone, "Asia/Kolkata")
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    program = programs(:albers)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { :section => MembersController::EditSection::SETTINGS, :id => members(:f_admin).id}
    assert_template 'edit'
    assert_select "input#max_connections_limit[value='#{users(:f_mentor).max_connections_limit}']", :count => 0
    assert_select "input#user_program_notification_setting_0_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_1_#{program.id}[type=radio]"
    assert_select "input#user_program_notification_setting_2_#{program.id}[type=radio]"
    assert_no_select "input#user_meeting_request_reminder[type=checkbox]"
    assert_select "select#user_member_time_zone" do
      assert_select "option[value='Asia/Kolkata'][selected=selected]"
    end
    assert_section_expanded("Settings")
    assert_equal MembersController::EditSection::SETTINGS, assigns(:section)
  end

  def test_disallow_edit_profile_for_non_admin_and_non_owner
    current_user_is :f_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    assert_permission_denied do
      get :edit, params: { :id => members(:f_mentor)}
    end
  end

  def test_allow_edit_any_profile_for_admin_and_owner
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    get :edit, params: { :id => members(:f_mentor)}
    assert_response :success
    assert_template 'edit'
  end

  def test_allow_admin_to_edit_profile_only_of_those_belonging_to_the_program
    # CEG admin trying to edit profile of Albers user.
    ceg_admin = create_user(:role_names => [RoleConstants::ADMIN_NAME], :program => programs(:ceg))
    make_member_of(programs(:ceg), ceg_admin)
    assert !programs(:albers).member?(ceg_admin) # Not member of Albers
    assert programs(:ceg).member?(ceg_admin) # member of CEG

    current_user_is ceg_admin
    current_program_is :ceg
    albers_user = users(:f_student)
    assert programs(:albers).member?(albers_user) # member of Albers
    assert !programs(:ceg).member?(albers_user) # not member of CEG
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    assert_record_not_found do
      get :edit, params: { :id => albers_user.id}
    end
  end

  def test_disallow_other_program_admin_to_edit_profile_of_current_user_program
    # CEG admin trying to edit profile of Albers user.
    ceg_admin = create_user(:role_names => [RoleConstants::ADMIN_NAME], :program => programs(:ceg))
    make_member_of(programs(:ceg), ceg_admin)
    assert !programs(:albers).member?(ceg_admin) # Not member of Albers
    assert programs(:ceg).member?(ceg_admin) # member of CEG

    current_member_is ceg_admin.member
    current_program_is :albers
    albers_user = users(:f_student)
    assert programs(:albers).member?(albers_user) # member of Albers
    assert !programs(:ceg).member?(albers_user) # not member of CEG
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    get :edit, params: { :id => albers_user.id}
    assert_redirected_to new_session_path
  end

  def test_allow_update_profile_only_for_admin_and_owner
    current_user_is :f_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    assert_permission_denied do
      post :update, params: { :id => members(:f_mentor), :member => {}}
    end
  end

  def test_should_render_edit_upon_update_failure
    current_user_is :f_student

    member = members(:f_student)

    assert_equal('student example', users(:f_student).name)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, params: { :id => member, :member => {:last_name => "" }}

    assert_redirected_to edit_member_path(member)
    assert_equal('student example', member.reload.name)
  end

  def test_get_student_edit_during_first_visit
    current_user_is :f_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_student), :first_visit => 1}
    assert_response :success
    assert_template 'edit_first_visit'
    assert assigns(:is_first_visit)
    assert_select 'html' do
      assert_select 'div#title_box' do
        assert_select '.lead', "Welcome #{users(:f_student).name}"
        # There should be no back link
        assert_select "a.back_link", 0
      end

      assert_select "input[type=?][value='Save & Proceed »']", 'submit'
      assert_select 'input#max_connections_limit', :count => 0
    end
  end

  def test_get_mentor_edit_during_first_visit
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :section => MembersController::EditSection::GENERAL, :id => members(:f_mentor), :first_visit => 1}
    assert_response :success
    assert_template 'edit_first_visit'
    assert assigns(:is_first_visit)
    assert_select 'html' do
      assert_select 'div#title_box' do
        assert_select '.lead', "Welcome #{users(:f_mentor).name}"
      end

      assert_select "input[type=?][value='Save & Proceed »']", 'submit'
      assert_select 'input#max_connections_limit', :count => 0
    end

    assert_equal MembersController::EditSection::GENERAL, assigns(:section)
  end

  ##############################################################################
  # USER PROFILE EDIT
  ##############################################################################

  def test_get_mentor_edit_answers_during_first_visit
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION)
    create_mentor_question

    programs(:albers).reload
    users(:f_mentor).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { :id => members(:f_mentor), :first_visit => 1, :last_section => true}
    assert_response :success

    assert_template 'edit_first_visit'
    assert assigns(:is_first_visit)

    # There should not be a cancel link in create profile
    assert_select "form.form-horizontal" do
      assert_select ".question", :count => 3
      assert_select 'div.form-actions' do
        assert_no_select 'a.cancel'
      end
    end
  end

  def test_add_mentor_role_with_basic_information
    current_user_is :f_mentor_student
    create_mentor_question

    programs(:albers).reload
    users(:f_mentor).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { section: MembersController::EditSection::GENERAL, id: members(:f_mentor_student), first_visit: 1}
    assert_response :success

    assert_template 'edit_first_visit'
    assert assigns(:is_first_visit)
    assert_nil assigns(:back_link)

    assert_select "form.form-horizontal" do
      # Name, email and picture are shown by default to all users
      assert_select "input#member_first_name"
      assert_select "input#member_last_name"
      assert_select "input#profile_picture_image_url"

      assert_select ".question", count: programs(:org_primary).sections.find_by(title: "Basic Information").profile_questions.where.not(question_type: [ProfileQuestion::Type::EMAIL, ProfileQuestion::Type::NAME]).size
      assert_select "input#last_section[value='false']"

      # There should not be a cancel link in create profile
      assert_select 'div.form-actions' do
        assert_no_select 'a.cancel'
      end
    end
  end

  def test_add_mentor_role_without_default_section_questions
    user = users(:f_mentor_student)
    current_user_is user
    program = user.program

    default_section = program.organization.sections.default_section.first
    default_section_questions = program.organization.profile_questions.where(section_id: default_section.id)
    name_email_questions = default_section_questions.where(question_type: [ProfileQuestion::Type::EMAIL, ProfileQuestion::Type::NAME])
    default_section_questions.where.not(id: name_email_questions.pluck(:id)).destroy_all
    program.reload

    get :edit, params: { section: MembersController::EditSection::GENERAL, id: members(:f_mentor_student), first_visit: 1}
    assert_response :success
    assert_equal MembersController::EditSection::GENERAL, assigns(:section)

    assert_template 'edit_first_visit'
    assert assigns(:is_first_visit)

    assert_select "form.form-horizontal" do
      # Should be shown even though there are no questions in default section
      assert_select "input#member_first_name"
      assert_select "input#member_last_name"
      assert_select "input#profile_picture_image_url"

      # There should not be a cancel link in create profile
      assert_select ".question", count: 0
      assert_select 'div.form-actions' do
        assert_no_select 'a.cancel'
      end
    end
  end

  def test_get_mentor_student_edit_answers_during_first_visit
    current_user_is :f_mentor_student

    create_mentor_question

    programs(:albers).reload
    users(:f_mentor).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { :id => members(:f_mentor_student), :first_visit => 1}

    assert_response :success

    assert_template 'edit_first_visit'
    assert assigns(:is_first_visit)

    # There should not be a cancel link in create profile
    assert_select "form.form-horizontal" do
      assert_select ".question", :count => 4
      assert_select 'div.form-actions' do
        assert_no_select 'a.cancel'
      end
    end
  end

  def test_get_mentor_edit_answers_during_first_visit_without_questions_should_redirect_to_program_root_path_if_there_are_no_questions
    current_user_is :mentor_3

    # Delete all questions
    programs(:org_primary).profile_questions.destroy_all
    assert programs(:org_primary).profile_questions.reload.empty?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never

    get :edit, params: { :id => members(:mentor_3), :section => MembersController::EditSection::PROFILE, :first_visit => 'mentor'}
    assert_redirected_to program_root_path
    assert_equal programs(:albers).mentor_questions_last_update_timestamp.to_s, cookies[DISABLE_PROFILE_PROMPT]
  end

  def test_should_redirect_to_program_root_path_when_edit_answers_page_is_accessed_and_there_are_no_custom_questions
    current_user_is :f_mentor

    programs(:org_primary).profile_questions.destroy_all
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never
    get :edit, params: { :id => members(:f_mentor), :section => MembersController::EditSection::PROFILE}
    assert_redirected_to program_root_path
    assert_nil cookies[DISABLE_PROFILE_PROMPT]
  end

  def test_should_set_disable_profile_prompt_cookie_on_edit_with_params_src
    current_user_is :f_mentor

    programs(:org_primary).profile_questions << create_question(:role_names => [RoleConstants::MENTOR_NAME])
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_mentor), :section => MembersController::EditSection::PROFILE, :src => 'update_prompt'}
    assert_response :success
    assert_template 'edit'
    assert_equal programs(:albers).mentor_questions_last_update_timestamp.to_s, cookies[DISABLE_PROFILE_PROMPT]
  end

  def test_admin_to_admin_mentor_after_role_update
    current_user_is :f_admin
    users(:f_admin).add_role(RoleConstants::MENTOR_NAME)
    create_mentor_question
    programs(:albers).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_admin), :section => MembersController::EditSection::PROFILE, :first_visit => true}
    assert_response :success

    assert_template 'edit_first_visit'
    assert assigns(:is_first_visit)
    assert_equal programs(:albers).mentor_questions_last_update_timestamp.to_s, cookies[DISABLE_PROFILE_PROMPT]
  end

  def test_admin_to_admin_student_after_role_update
    current_user_is :f_admin
    users(:f_admin).add_role(RoleConstants::STUDENT_NAME)
    create_student_question
    programs(:albers).reload
    users(:f_admin).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { :id => members(:f_admin), :section => MembersController::EditSection::PROFILE, :first_visit => true}
    assert_response :success

    assert_template 'edit_first_visit'
    assert assigns(:is_first_visit)
    assert_equal programs(:albers).student_questions_last_update_timestamp.to_s, cookies[DISABLE_PROFILE_PROMPT]
  end

  def test_should_get_the_default_profile_fields_page_for_mentor
    current_user_is :f_mentor
    questions = programs(:albers).profile_questions_for(RoleConstants::MENTOR_NAME, {default: false, skype: true})
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_mentor).id, :section => MembersController::EditSection::PROFILE}
    assert_template 'edit'
    assert_equal(questions, assigns(:program_questions_for_user))

    assert_select 'div.common_questions' do
      assert_select 'form.form-horizontal' do
        assert_select 'div.question', questions.size - 3 # phone skype id and location
      end
    end
  end

  def test_should_get_the_default_profile_fields_page_for_mentee
    programs(:org_primary).profile_questions.destroy_all
    current_user_is :f_student
    questions = []

    6.times { questions << create_question(:role_names => [RoleConstants::STUDENT_NAME]) }
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { :id => members(:f_student).id}
    assert_template 'edit'
    assert_equal(questions, assigns(:program_questions_for_user))

    assert_select 'div.question', 6
  end

  def test_should_update_the_mentee_profile_for_first_visit_and_redirect_to_answers_page
    current_user_is :f_student

    create_student_question

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', :member => {:first_name => "New Name", :last_name => "student"}}
    assert_redirected_to edit_member_path(:first_visit => 'mentee', :section => MembersController::EditSection::PROFILE, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    u = assigns(:profile_user)
    assert_equal('New Name student', u.reload.name)
  end

  def test_should_get_first_visit_custom_profile_fields
    current_user_is :f_student

    create_student_question
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :section => MembersController::EditSection::PROFILE, :id => members(:f_student), :first_visit => 'mentee'}
    assert_response :success
    assert_template 'edit_first_visit'

    assert_select 'form.form-horizontal' do
      assert_select 'input[type=hidden][name=first_visit][value=mentee]'
    end
  end

  ##############################################################################
  # USER UPDATE
  ##############################################################################
  def test_ajax_logout
    prog = programs(:albers)
    current_program_is prog
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => members(:f_student).id,
      :user => {:admin_notes => "My notes"}
    }

    assert_response 401
  end

  def test_update_admin_notes
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => members(:f_student).id,
      :user => {:admin_notes => "My notes"}
    }

    assert_response :success
    assert_template 'admin_note_update'

    assert_equal "My notes", users(:f_student).reload.admin_notes
  end

  def test_update_admin_notes_by_non_admin
    user = users(:f_student)
    assert_nil user.admin_notes

    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    assert_permission_denied do
      post :update, xhr: true, params: { id: user.member_id, user: { admin_notes: "My notes" }}
    end
    assert_nil user.reload.admin_notes
  end

  def test_should_update_location
    current_user_is :ram

    loc_ques = profile_answers(:location_chennai_ans).profile_question
    new_location = locations(:delhi)
    assert_not_equal new_location, users(:ram).location
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, xhr: true, params: { :id => members(:ram), :member => {:first_name => 'new', :last_name => 'ram'}}
    assert_response :success
    members(:ram).reload

    members(:ram).profile_answers.build(:location_id => new_location.id, :profile_question_id => loc_ques.id)
    members(:ram).save!
    assert_equal new_location, users(:ram).reload.location
  end

  def test_accessing_a_guarded_page_without_login_back_marks_the_page
    current_program_is :albers
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never
    get :edit, params: { :root => 'albers', :id => members(:f_mentor)}
    assert_redirected_to new_session_path
    assert_equal edit_member_url(members(:f_mentor)), session[:last_visit_url]
  end

  def test_update_role_can_be_changed_only_by_admin
    current_user_is :f_mentor
    assert_equal [RoleConstants::MENTOR_NAME], users(:f_mentor).role_names
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, xhr: true, params: { :id => members(:f_mentor).id, :user => {
      :role_names => [RoleConstants::STUDENT_NAME]}}
    # The role update should not happen
    assert_equal [RoleConstants::MENTOR_NAME], users(:f_mentor).reload.role_names
  end

  def test_decreasing_max_connection_limit_less_than_his_active_students_should_throw_warning
    current_user_is :mentor_2
    mentor_1 = users(:mentor_2)
    student_1 = users(:student_8)
    student_2 = users(:student_9)
    mentor_1.update_attribute(:max_connections_limit,3)
    assert_equal(3, mentor_1.reload.max_connections_limit)
    g1 = create_group(:mentor => mentor_1, :students => [student_1])
    g2 = create_group(:mentor => mentor_1, :students => [student_2])
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, xhr: true, params: { :id => members(:mentor_2), :user => {:max_connections_limit => 1}}

    assert_equal(3, assigns(:profile_user).reload.max_connections_limit)
    assert_equal( "Your mentoring connections limit cannot be less than 2 since you are already mentoring 2 student(s).", assigns(:settings_flash_error))
  end

  def test_decreasing_max_connection_limit_less_than_his_active_students_should_throw_warning_as_less_than
    current_user_is :mentor_2
    mentor_1 = users(:mentor_2)
    student_1 = users(:student_8)
    student_2 = users(:student_9)
    mentor_1.update_attribute(:max_connections_limit,3)
    assert_equal(3, mentor_1.reload.max_connections_limit)
    g1 = create_group(:mentor => mentor_1, :students => [student_1])
    g2 = create_group(:mentor => mentor_1, :students => [student_2])
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    mentor_1.program.update_attribute(:default_max_connections_limit ,10)
    mentor_1.program.update_attribute(:connection_limit_permission, Program::ConnectionLimit::ONLY_INCREASE)
    post :update, xhr: true, params: { :id => members(:mentor_2), :user => {:max_connections_limit => 8}}

    assert_equal( "The mentoring connection limit cannot be set to a value less than 10", assigns(:settings_flash_error))
  end


  def test_decreasing_max_connection_limit_less_than_his_active_students_should_throw_warning_as_greater_than
    current_user_is :mentor_2
    mentor_1 = users(:mentor_2)
    student_1 = users(:student_8)
    student_2 = users(:student_9)
    mentor_1.update_attribute(:max_connections_limit,3)
    assert_equal(3, mentor_1.reload.max_connections_limit)
    g1 = create_group(:mentor => mentor_1, :students => [student_1])
    g2 = create_group(:mentor => mentor_1, :students => [student_2])
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    mentor_1.program.update_attribute(:default_max_connections_limit ,10)
    mentor_1.program.update_attribute(:connection_limit_permission, Program::ConnectionLimit::ONLY_DECREASE)
    post :update, xhr: true, params: { :id => members(:mentor_2), :user => {:max_connections_limit => 12}}
    assert_equal( "The mentoring connection limit cannot be set to a value greater than 10", assigns(:settings_flash_error))
  end

  def test_should_update_picture_during_first_time_visit
    current_user_is :f_mentor

    programs(:org_primary).profile_questions << create_question(:role_names => [RoleConstants::MENTOR_NAME])
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, params: { :id => members(:f_mentor), :first_visit => 'mentor',
      :member => {:first_name => '', :last_name => "New Name",
      :profile_picture => {:image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
    }}

    assert_redirected_to edit_member_path(members(:f_mentor), :section => MembersController::EditSection::PROFILE, :first_visit => 'mentor', ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    u = assigns(:profile_user)
    assert_equal('New Name', u.reload.name)
    assert_not_nil u.member.profile_picture
    assert u.member.profile_picture.image?
    assert_match(/test_pic.png/, u.member.profile_picture.image_file_name)
  end

  def test_should_delete_user_education_experience_first_visit
    current_user_is :f_mentor
    edu_question = profile_questions(:multi_education_q)
    exp_question = profile_questions(:multi_experience_q)
    pub_question = profile_questions(:multi_publication_q)
    user = users(:f_mentor)
    member = user.member
    create_education(user, edu_question)
    create_experience(user, exp_question)
    create_publication(user, pub_question)

    # User has educations, experiences and publications
    assert !member.educations.empty?
    assert !member.experiences.empty?
    assert !member.publications.empty?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update, params: { :id => user.member.id, :first_visit => 'mentor', :member => {:last_name => "Myname"}}
    user.reload
    #education, experience and publication are part of user answers and updating profile will not update answers
    assert !member.educations.empty?
    assert !member.experiences.empty?
    assert !member.publications.empty?
  end

  def test_update_requires_login
    current_program_is :albers
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, params: { :id => members(:rahim), :member => {:name => "my new name"}}
    assert_redirected_to new_session_path
  end

  def test_update_notification_setting_redirects_to_program_root_url
    current_user_is :f_mentor
    user = users(:f_mentor)
    member = user.member
    create_education(user, profile_questions(:multi_education_q))
    create_experience(user, profile_questions(:multi_experience_q))
    create_publication(user, profile_questions(:multi_publication_q))

    assert !member.educations.empty?
    assert !member.experiences.empty?
    assert !member.publications.empty?

    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, users(:f_mentor).program_notification_setting)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => members(:f_mentor), :user => {:program_notification_setting => UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY}, :member => {:time_zone => "Asia/Kolkata"}}

    assert !member.educations.empty?
    assert !member.experiences.empty?
    assert !member.publications.empty?
    assert members(:f_mentor).reload.time_zone, "Asia/Kolkata"

    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY, assigns(:profile_user).reload.program_notification_setting)
  end

  def test_update_will_set_availability_slots_slots_setting_to_false
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :f_mentor
    user = users(:f_mentor)
    member = user.member
    member.update_attributes!(will_set_availability_slots: true)

    assert member.will_set_availability_slots?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    @controller.expects(:fetch_profile_member)
    @controller.expects(:fetch_profile_user).returns(users(:f_mentor))
    @controller.instance_variable_set(:@profile_member, member)
    @controller.instance_variable_set(:@profile_user, user)

    put :update_settings, xhr: true, params: { :id => user.id, :user =>{:program_id => user.program.id}, :member => {:will_set_availability_slots => false, :availability_not_set_message => "Please contact me directly"}}
    assert_response :success
    member = member.reload
    assert_false member.will_set_availability_slots?
    assert_false assigns(:alert_availability_setting)
    assert_match  /Please contact me directly/, member.availability_not_set_message
  end

  def test_update_will_set_availability_slots_slots_setting_to_true
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :f_mentor
    user = users(:f_mentor)
    member = user.member
    member.will_set_availability_slots = false
    member.save!
    assert_false member.will_set_availability_slots?

    put :update_settings, xhr: true, params: { :id => user.id, :user =>{:program_id => user.program.id}, :member => {:will_set_availability_slots => true}}
    assert_response :success

    member = member.reload
    assert assigns(:alert_availability_setting)
    assert member.will_set_availability_slots?
  end

  def test_update_maximum_connections_limit_setting
    current_user_is :f_mentor

    assert_equal(2, users(:f_mentor).max_connections_limit)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => members(:f_mentor), :user => {:max_connections_limit => 3}}

    assert :success
    assert_equal(3, assigns(:profile_user).reload.max_connections_limit)
  end

  def test_update_user_setting
    current_user_is :f_mentor
    user = users(:f_mentor)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).twice
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, xhr: true, params: { :id => members(:f_mentor), :user => {:user_settings => {:max_meeting_slots => 2}}}
    assert :success

    assert_equal 2, user.reload.user_setting.max_meeting_slots
    user.user_setting.destroy
    assert_difference 'UserSetting.count', 1 do
      post :update, xhr: true, params: { :id => members(:f_mentor), :user=>{:user_settings => {:max_meeting_slots => 4}}}
    end
    assert_response :success
    assert_equal 4, user.reload.user_setting.max_meeting_slots
  end

  def test_admin_should_be_able_to_update_student_profile
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    assert users(:rahim).is_student?

    assert_emails 0 do
      post :update, xhr: true, params: { :id => members(:rahim), :member => {:first_name => "my new", :last_name => "name"}}
    end

    assert_response :success
    assert_equal users(:rahim), assigns(:profile_user)
    users(:rahim).reload

    assert_equal "my new name", users(:rahim).name
  end

  def test_admin_should_be_able_to_update_student_profile_with_email
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    assert users(:rahim).is_student?
    old_email = users(:rahim).email

    assert_emails 1 do
      post :update, xhr: true, params: { :id => members(:rahim), :member => {:email => "new_email@gmail.com"}}
    end

    assert_response :success
    assert_equal users(:rahim), assigns(:profile_user)
    assert assigns(:profile_user).updated_by_admin
    users(:rahim).reload
    assert_equal "new_email@gmail.com", users(:rahim).email
    assert_equal members(:f_admin), assigns(:profile_member).email_changer

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal old_email, delivered_email.to[0]
  end

  def test_admin_should_be_able_to_update_mentor_profile
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    assert users(:f_mentor).is_mentor?

    post :update, xhr: true, params: { :id => members(:f_mentor), :member => {:first_name => "new Mentor", :last_name => "name"}}

    assert_response :success
    assert_equal users(:f_mentor), assigns(:profile_user)
    users(:f_mentor).reload

    assert_equal "new Mentor name", users(:f_mentor).name
  end

  def test_should_update_the_student_profile_for_first_visit_and_redirect_to_answers_page_if_there_are_questions
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    programs(:org_primary).profile_questions << create_question(:role_names => [RoleConstants::MENTOR_NAME])

    post :update, params: { :id => members(:f_mentor), :first_visit => 'mentor', :member => {:first_name => "New", :last_name => "Name" }}

    assert_redirected_to edit_member_path(
      members(:f_mentor),
      :section => MembersController::EditSection::PROFILE,
      :first_visit => 'mentor', ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)

    u = assigns(:profile_user)
    assert_false u.updated_by_admin
    assert_equal('New Name', u.reload.name)
  end

  def test_update_first_visit_with_last_section_parameter_set
    user = users(:f_mentor)
    User.any_instance.stubs(:can_set_availability?).returns(true)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    current_user_is user
    post :update, params: { id: members(:f_mentor),
      first_visit: 'mentor',
      last_section: true,
      member: { first_name: "New", last_name: "Name" }
    }
    assert_redirected_to edit_member_path(user.member,
      section: MembersController::EditSection::MENTORING_SETTINGS,
      first_visit: 'mentor', ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION
    )
  end

  def test_update_first_visit_with_last_section_parameter_set_for_mentee
    user = users(:f_student)
    User.any_instance.stubs(:can_set_availability?).returns(true)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    current_user_is user
    post :update, params: { id: members(:f_student),
      first_visit: 'student',
      last_section: true,
      member: { first_name: "New", last_name: "Name" }
    }
    assert_redirected_to edit_member_path(user.member,
      section: MembersController::EditSection::MENTORING_SETTINGS,
      first_visit: 'student', ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION
    )
  end

  ##############################################################################
  # USER PROFILE UPDATE
  ##############################################################################

  def test_redirected_to_program_root_path_when_user_tries_to_skip_required_fields_while_completing_profile
    current_user_is :f_mentor
    assert_nil users(:f_mentor).profile_updated_at

    q = create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"], :required => 1)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update_answers, params: { prof_c: "true", id: users(:f_mentor).id, profile_answers: { q.id => [""] }, section_id: q.section.id}
    assert_redirected_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
  end

  def test_should_raise_a_flash_when_user_tries_to_skip_required_fields_while_editing_profile_and_is_redirected_to_edit_first_time_experience
    current_user_is :f_mentor
    q = create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"], :required => 1)
    programs(:albers).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { :id => members(:f_mentor).id, :profile_answers => { q.id => [""] }, :first_visit => true}
    assert_equal "Required fields cannot be blank", flash[:error]
    assert_redirected_to edit_member_path(members(:f_mentor), :first_visit => true, :section => MembersController::EditSection::PROFILE, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_change_pending_to_active_once_the_student_profile_is_complete_by_student
    q1 = create_question(:program => programs(:albers), :role_names => [RoleConstants::STUDENT_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"], :required => 1)

    users(:f_student).update_attribute(:state, User::Status::PENDING)
    s1 = users(:f_student)
    current_user_is s1
    assert_equal User::Status::PENDING, s1.state
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).once
    post :update_answers, params: { :id => s1.member.id, :profile_answers => { q1.id => "A" }, :first_visit => true}
    assert_equal  User::Status::ACTIVE, s1.reload.state
  end

  def test_change_pending_to_active_once_the_student_profile_is_complete_by_admin
    q1 = create_question(:program => programs(:albers), :role_names => [RoleConstants::STUDENT_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"], :required => 1)

    users(:f_student).update_attribute(:state, User::Status::PENDING)
    s1 = users(:f_student)

    current_user_is users(:f_admin)
    assert_equal User::Status::PENDING, s1.state
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { :id => s1.member.id, :profile_answers => { q1.id => "A" }, :first_visit => true}
    assert_equal  User::Status::ACTIVE, s1.reload.state
  end

  def test_change_pending_to_active_once_the_mentor_profile_is_complete_by_mentor
    q1 = create_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"], :required => 1)
    m1 = users(:pending_user)

    current_user_is m1
    assert_equal User::Status::PENDING, m1.state
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).once
    post :update_answers, params: { :id => m1.member.id, :profile_answers => { q1.id => "A" }, :first_visit => true}
    assert_equal  User::Status::ACTIVE, m1.reload.state
  end

  def test_do_change_pending_to_active_once_mentor_the_profile_is_complete_by_admin
    q1 = create_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"], :required => 1)
    programs(:albers).reload

    m1 = users(:pending_user)
    current_user_is users(:f_admin)
    assert_equal User::Status::PENDING, m1.state
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    post :update_answers, params: { :id => m1.member.id, :profile_answers => { q1.id => "A" }, :first_visit => true}
    assert_equal  User::Status::ACTIVE, m1.reload.state
  end

  def test_posting_update_to_mentor_custom_fields_should_update_create_non_existent_answers_and_update_existing_answers
    current_user_is :f_mentor
    programs(:org_primary).profile_questions.destroy_all
    ProfileAnswer.destroy_all
    questions = []
    2.times { questions << create_question(:role_names => [RoleConstants::MENTOR_NAME]) }
    questions << create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"])
    questions << create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["A", "B", "C", "D", "E", "F", "G"], :allow_other_option => true)
    ProfileAnswer.create!(:ref_obj => members(:f_mentor), :profile_question => questions[0], :answer_value => "Old answer")
    ProfileAnswer.create!(:ref_obj => members(:f_mentor), :profile_question => questions[2], :answer_value => "B")

    # 2 questions already have answers
    assert_equal('Old answer', users(:f_mentor).answer_for(questions[0]).answer_value)
    assert_equal('B', users(:f_mentor).answer_for(questions[2]).answer_value)

    # 2 new answers should be created, the rest 2 are updated.
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    assert_difference 'ProfileAnswer.count', 2 do
      post :update, xhr: true, params: { :id => members(:f_mentor).id, :profile_answers => {
        questions[0].id => "Answer 1",
        questions[1].id => "Answer 2",
        questions[2].id => "A",
        questions[3].id => [ 'C', 'E', 'G', 'L, M,N, A ' ]
      }, :section_id => questions[0].section.id}
    end

    answers = members(:f_mentor).reload.profile_answers
    assert_equal(4, answers.size)
    assert_equal('Answer 1', users(:f_mentor).answer_for(questions[0]).answer_text)
    assert_equal('Answer 2', users(:f_mentor).answer_for(questions[1]).answer_text)
    assert_equal('A', users(:f_mentor).answer_for(questions[2]).answer_value)
    assert_equal(["A", "C", "E", "G", "L", "M", "N"], users(:f_mentor).answer_for(questions[3]).answer_value)
  end

  def test_should_redirect_to_edit_member_path_and_mentoring_settings_section_not_set_any_flash_on_first_visit_answers_update
    current_user_is :f_mentor
    assert_nil users(:f_mentor).profile_updated_at
    members(:f_mentor).profile_answers.destroy_all
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update_answers, params: { :id => members(:f_mentor), :first_visit => 'mentor', :last_section => true, :profile_answers => {
      profile_questions(:string_q).id => "First Answer",
      profile_questions(:single_choice_q).id => "opt_2",
      profile_questions(:multi_choice_q).id => "Walk"
    }}

    assert_redirected_to edit_member_path(first_visit: :mentor, section: :mentoring_settings, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_nil flash[:notice]
    u = users(:f_mentor).reload
    assert_equal(3, members(:f_mentor).reload.profile_answers.size)
    assert_equal('First Answer', u.answer_for(profile_questions(:string_q)).answer_text)
    assert_equal('opt_2', u.answer_for(profile_questions(:single_choice_q)).answer_value)
    assert_equal(['Walk'], u.answer_for(profile_questions(:multi_choice_q)).answer_value)
    assert_false users(:f_mentor).profile_updated_at.nil?
  end

  def test_record_not_found_when_user_not_found_for_the_member
    current_program_is :ceg
    current_user_is :arun_ceg
    albers_user = users(:f_student)
    assert programs(:albers).member?(albers_user) # member of Albers
    assert !programs(:ceg).member?(albers_user) # not member of CEG
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    assert_record_not_found do
      get :show, params: { :id => albers_user.id}
    end
  end

  def test_manage_connection_page
    current_user_is :f_admin
    user = users(:not_requestable_mentor)
    group = user.groups.first
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => user.member_id, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS}
    assert_equal [groups(:group_3), groups(:group_2)], assigns(:groups)

    # Assert filters
    assert_select 'div.inner_tabs' do
      assert_select 'a', :text => 'Ongoing (2)'
      assert_select 'a', :text => 'Closed (0)'
    end
    assert_select "div#group_#{group.id}" do
      assert_select 'div.col-sm-3', :text => 'Mentor'
      assert_select 'div.col-sm-3', :text => 'Student'
      assert_select 'div.col-sm-3', :text => 'Last activity'
      assert_select 'div.col-sm-3', :text => 'Expires in'
      # Admin actions should  be shown
      assert_select 'div.actions_box'
    end

    assert assigns(:from_member_profile)
    assert_nil assigns(:connection_questions)
  end

  def test_manage_connection_page_for_no_connection_for_student
    current_user_is :f_admin
    u1 = users(:student_5)
    assert_equal 0, u1.groups.size
    u = u1.member
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => u.id, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS}

    assert_select "div#mentor_profile" do
      assert_select "li.active", text: "Ongoing (0)"
      assert_select "div#no_connections", :text=> "The user does not have any ongoing mentoring connections. Switch tabs to see mentoring connections in other states."
    end

    assert_select "div#title_actions" do
      assert_select 'a[href=?]', matches_for_student_users_path(:manage_connections_member => u.id, :student_name => u.name_with_email)
    end
  end

  def test_manage_connection_page_for_no_connection_for_student_for_closed_connections
    current_user_is :f_admin
    u1 = users(:student_5)
    assert_equal 0, u1.groups.size
    u = u1.member
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => u.id, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS, :filter => Group::Status::CLOSED}

    assert_select "div#mentor_profile" do
      assert_select "div#no_connections", :text=> "The user does not have any closed mentoring connections. Switch tabs to see mentoring connections in other states."
    end

    assert_select "div#title_actions" do
      assert_select 'a[href=?]', matches_for_student_users_path(:manage_connections_member => u.id, :student_name => u.name_with_email)
    end
  end

  def test_manage_connection_page_with_drafted_tab
    current_user_is :f_admin_pbe

    profile_user = users(:f_mentor_pbe)

    groups(:group_pbe).update_columns(status: Group::Status::DRAFTED, last_member_activity_at: 2.days.ago)
    groups(:proposed_group_3).update_columns(status: Group::Status::DRAFTED, last_member_activity_at: 1.days.ago)
    groups(:proposed_group_4).update_columns(status: Group::Status::DRAFTED, last_member_activity_at: 3.days.ago)

    get :show, params: { id: profile_user.member_id, tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: GroupsController::StatusFilters::Code::DRAFTED }
    assert_equal [groups(:proposed_group_3), groups(:group_pbe), groups(:proposed_group_4)], assigns(:groups)
  end

  def test_manage_connection_page_with_proposed_tab
    current_user_is :f_admin_pbe

    profile_user = users(:f_mentor_pbe)

    groups(:group_pbe).update_columns(status: Group::Status::PROPOSED, created_at: 2.days.ago)
    groups(:proposed_group_3).update_columns(created_at: 1.days.ago)
    groups(:proposed_group_4).update_columns(created_at: 3.days.ago)

    get :show, params: { id: profile_user.member_id, tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: GroupsController::StatusFilters::Code::PROPOSED }
    assert_equal [groups(:proposed_group_3), groups(:group_pbe), groups(:proposed_group_4)], assigns(:groups)
  end

  def test_manage_connection_page_with_rejected_tab
    current_user_is :f_admin_pbe

    profile_user = users(:f_mentor_pbe)

    groups(:group_pbe).update_columns(status: Group::Status::REJECTED, closed_at: 2.days.ago)
    groups(:proposed_group_3).update_columns(status: Group::Status::REJECTED, closed_at: 1.days.ago)
    groups(:rejected_group_2).update_columns(closed_at: 3.days.ago)

    get :show, params: { id: profile_user.member_id, tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: GroupsController::StatusFilters::Code::REJECTED }
    assert_equal [groups(:proposed_group_3), groups(:group_pbe), groups(:rejected_group_2)], assigns(:groups)
  end

  def test_manage_connection_page_with_withdrawn_tab
    current_user_is :f_admin_pbe

    profile_user = users(:f_mentor_pbe)

    groups(:group_pbe).update_columns(status: Group::Status::WITHDRAWN, closed_at: 2.days.ago)
    groups(:proposed_group_3).update_columns(status: Group::Status::WITHDRAWN, closed_at: 1.days.ago)
    groups(:withdrawn_group_1).update_columns(closed_at: 3.days.ago)

    get :show, params: { id: profile_user.member_id, tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: GroupsController::StatusFilters::Code::WITHDRAWN }
    assert_equal [groups(:proposed_group_3), groups(:group_pbe), groups(:withdrawn_group_1)], assigns(:groups)
  end

  def test_manage_connection_page_with_pending_tab
    current_user_is :f_admin_pbe

    profile_user = users(:f_mentor_pbe)

    groups(:group_pbe).update_columns(status: Group::Status::PENDING, last_activity_at: 2.days.ago)
    groups(:proposed_group_3).update_columns(status: Group::Status::PENDING, last_activity_at: 1.days.ago)
    groups(:proposed_group_4).update_columns(status: Group::Status::PENDING, last_activity_at: 3.days.ago)

    get :show, params: { id: profile_user.member_id, tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: GroupsController::StatusFilters::Code::PENDING }
    assert_equal [groups(:proposed_group_3), groups(:group_pbe), groups(:proposed_group_4)], assigns(:groups)
  end

  def test_manage_connection_page_with_closed_tab
    current_user_is :f_admin_pbe

    profile_user = users(:f_mentor_pbe)

    groups(:group_pbe).update_columns(status: Group::Status::CLOSED, published_at: 2.days.ago, closed_at: 1.day.ago, expiry_time: 1.day.ago)
    groups(:proposed_group_3).update_columns(status: Group::Status::CLOSED, published_at: 1.days.ago, closed_at: 2.day.ago, expiry_time: 2.day.ago)
    groups(:proposed_group_4).update_columns(status: Group::Status::CLOSED, published_at: 3.days.ago, closed_at: 3.day.ago, expiry_time: 3.day.ago)

    get :show, params: { id: profile_user.member_id, tab: MembersController::ShowTabs::MANAGE_CONNECTIONS, filter: GroupsController::StatusFilters::Code::CLOSED }
    assert_equal [groups(:proposed_group_3), groups(:group_pbe), groups(:proposed_group_4)], assigns(:groups)
  end

  def test_meeting_availability_for_ongoing_program
    current_user_is :f_student
    program = programs(:albers)
    get :show, params: { id: members(:f_mentor).id, tab: MembersController::ShowTabs::PROFILE}
    assert_false assigns(:show_meeting_availability)
  end


  def test_meeting_availability_for_flash_only_program
    current_user_is :f_student
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attributes(engagement_type: Program::EngagementType::CAREER_BASED)
    get :show, params: { id: members(:f_mentor).id, tab: MembersController::ShowTabs::PROFILE}
    assert assigns(:show_meeting_availability)
  end

  def test_manage_connection_page_for_no_connection_for_mentor
    current_user_is :f_admin
    u1 = users(:mentor_2)
    assert_equal 0, u1.groups.size
    u = u1.member
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => u.id, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS}

    assert_select "div#mentor_profile" do
      assert_select "div#no_connections", text: "The user does not have any ongoing mentoring connections. Switch tabs to see mentoring connections in other states."
      end

    assert_select "div#title_actions" do
      assert_select 'a[href=?]', groups_path(:show_new => true, :create_connection_member => u.id)
    end
  end

  def test_manage_connection_page_for_no_connection_for_mentor_for_closed_connections
    current_user_is :f_admin
    u1 = users(:mentor_2)
    assert_equal 0, u1.groups.size
    u = u1.member
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => u.id, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS, :filter => Group::Status::CLOSED}

    assert_select "div#mentor_profile" do
      assert_select "div#no_connections", :text => "The user does not have any closed mentoring connections. Switch tabs to see mentoring connections in other states."
    end

    assert_select "div#title_actions" do
      assert_select 'a[href=?]', groups_path(:show_new => true, :create_connection_member => u.id)
    end
  end

  def test_manage_connection_without_status_filter_shows_ongoing_tab
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => users(:f_student).id, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS}
    assert_equal GroupsController::StatusFilters::Code::ONGOING, assigns(:status_filter)
  end

  def test_manage_connection_filter_ongoing
    current_user_is :f_admin
    g = groups(:mygroup)
    g2 = create_group(:student => users(:mkr_student), :mentor => users(:f_mentor_student))
    g2.update_attribute(:status, Group::Status::INACTIVE)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => users(:mkr_student).id, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS, :filter => GroupsController::StatusFilters::Code::ONGOING}
    assert_equal [g2, groups(:mygroup)], assigns(:groups)
  end

  def test_manage_connection_filter_closed
    current_user_is :f_admin
    g = groups(:group_4)
    g2 = create_group(:student => users(:student_4), :mentor => users(:f_mentor_student))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => users(:student_4).id, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS, :filter => Group::Status::CLOSED}
    assert_equal [groups(:group_4)], assigns(:groups)
    assert_false assigns(:can_current_user_create_meeting) #as the tab  is not availability
    assert_nil assigns(:past_meetings_selected)
  end

  def test_show_availability_self_no_archive
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :f_mentor
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    m = members(:f_mentor)
    meeting = meetings(:f_mentor_mkr_student)
    time = Time.now.change(usec: 0)
    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), time+10.minutes, time+20.minutes, {duration: 10.minutes})
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    get :show, params: { :id => m.id, :tab => MembersController::ShowTabs::AVAILABILITY, :src => "quick_links", :meetings_tab => MeetingsController::MeetingsTab::PAST}
    assert_equal wp_collection_from_array([{:current_occurrence_time => meetings(:f_mentor_mkr_student).start_time, :meeting => meetings(:f_mentor_mkr_student)}, {:current_occurrence_time => meetings(:upcoming_calendar_meeting).start_time, :meeting => meetings(:upcoming_calendar_meeting)}]), assigns(:meetings_to_be_held)
    assert assigns(:past_meetings_selected)
    assert_equal assigns(:ei_src), EngagementIndex::Src::UpdateMeeting::MEMBER_MEETING_LISTING
  end

  def test_show_availability_self_with_archive
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    programs(:albers).calendar_setting.update_attribute(:allow_create_meeting_for_mentor, false)
    current_user_is :f_mentor
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    m = members(:f_mentor)
    time = Time.now.change(usec: 0)
    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), time - 100.minutes, time+20.minutes, {duration: 20.minutes})
    update_recurring_meeting_start_end_date(meetings(:student_2_not_req_mentor), time+150.minutes, time+160.minutes, {duration: 10.minutes})
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    get :show, params: { :id => m.id, :tab => MembersController::ShowTabs::AVAILABILITY, :src => "quick_links", :meetings_tab => MeetingsController::MeetingsTab::UPCOMING}
    assert_equal wp_collection_from_array([{:current_occurrence_time => meetings(:f_mentor_mkr_student).start_time, :meeting => meetings(:f_mentor_mkr_student)},  {:current_occurrence_time => meetings(:cancelled_calendar_meeting).start_time, :meeting => meetings(:cancelled_calendar_meeting)}, {:current_occurrence_time => meetings(:completed_calendar_meeting).start_time, :meeting => meetings(:completed_calendar_meeting)},{:current_occurrence_time => meetings(:past_calendar_meeting).start_time, :meeting => meetings(:past_calendar_meeting)}]), assigns(:archived_meetings)
    assert_false assigns(:can_current_user_create_meeting) #current_user is mentor. Calender is enabled and create meeting seeting is false
    assert_false assigns(:past_meetings_selected)
  end

  def test_no_archived_and_meetings_to_be_held_with_feature_disabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, false)
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
    current_user_is :f_mentor
    m = members(:f_mentor)
    meetings(:f_mentor_mkr_student).update_attributes(:start_time => 100.minutes.ago, :end_time => 80.minutes.ago)
    meetings(:student_2_not_req_mentor).update_attributes(:start_time => 150.minutes.since, :end_time => 160.minutes.since)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    get :show, params: { :id => m.id, :tab => MembersController::ShowTabs::AVAILABILITY, :src => "quick_links"}
    assert assigns(:archived_meetings).blank?
    assert_false assigns(:can_current_user_create_meeting)
    assert_false assigns(:past_meetings_selected)
  end

  def test_show_availability_others
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :f_student
    m = members(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => m.id, :tab => MembersController::ShowTabs::AVAILABILITY, :src => "quick_links"}
    assert_nil assigns(:meetings_to_be_held)
    assert_false assigns(:can_current_user_create_meeting) #current_user is not mentor. Calender is enabled and create meeting seeting is true
  end

  def test_show_my_meetings_for_mentor_self_view
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :f_mentor
    m = members(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => m.id}

    assert_select 'div#profile_side_bar' do
      assert_select "div.ibox" do
        assert_select "div.ibox-title" do
          assert_select 'h5', :text => "Meetings (1)"
        end
      end
    end
  end

  def test_show_my_meetings_for_mentee_self_view
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :mkr_student
    m = members(:mkr_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => m.id}

    assert_select 'div#profile_side_bar' do
      assert_select "div.ibox" do
        assert_select "div.ibox-title" do
          assert_select 'h5', :text => "Meetings (1)"
        end
      end
    end
  end

  def test_do_not_show_my_meetings_for_mentor_admin_view
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :f_admin
    m = members(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never

    get :show, params: { :id => m.id}

    assert_select 'div#profile_side_bar' do
      assert_select 'div.side_section.meetings', :count => 0
    end
  end

  def test_do_not_show_my_meetings_for_mentor_mentee_view
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :mkr_student
    m = members(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once
    get :show, params: { :id => m.id}

    assert_select 'div#profile_side_bar' do
      assert_select 'div.side_section.meetings', :count => 0
    end
  end

  def test_do_not_show_my_meetings_for_admin_self_view
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :f_admin
    m = members(:f_admin)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => m.id}

    assert_select 'div#profile_side_bar' do
      assert_select 'div.side_section.meetings', :count => 0
    end
  end

  def test_do_not_show_duplicate_my_meetings_when_non_admin_selects_my_meetings_tab
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_user_is :mkr_student
    m = members(:mkr_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => m.id, :tab => MembersController::ShowTabs::AVAILABILITY}
    assert_false assigns(:show_meetings)
  end

  def test_show_tags_for_admin
    programs(:org_primary).enable_feature(FeatureName::MEMBER_TAGGING)
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never
    get :show, params: { :id => members(:f_mentor).id}

    assert assigns(:show_tags)
  end

  def test_donot_show_tags_for_mentor
    programs(:org_primary).enable_feature(FeatureName::MEMBER_TAGGING)
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    get :show, params: { :id => members(:f_mentor).id}

    assert_false assigns(:show_tags)
  end

  def test_should_create_answers_for_mentor_student_common_question
    user = users(:f_mentor_student)
    current_user_is :f_mentor_student
    q = programs(:org_primary).profile_questions.find_by(question_text: "Location")
    assert_nil user.answer_for(q)
    place = "Chennai, Tamil Nadu, India"
    MembersController.any_instance.expects(:expire_profile_cached_fragments).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    assert_difference "ProfileAnswer.count", 1 do
      post :update, xhr: true, params: { :id => user.id, :profile_answers => {q.id => place }, :section_id => q.section.id}
    end
    second_last = ProfileAnswer.all[-1]
    last = ProfileAnswer.last
    assert_equal last.answer_text, place
    assert_equal user.answer_for(q), last
  end

  def test_should_update_answers_for_mentor_student_common_question_already_existing
    user = users(:f_mentor_student)
    current_user_is :f_mentor_student
    q = programs(:org_primary).profile_questions.find_by(question_text: "Phone")
    assert_nil user.answer_for(q)
    last = ProfileAnswer.create!(:ref_obj => user.member, :profile_question_id => q.id, :answer_text => "123")
    assert_equal user.answer_for(q).answer_text, "123"
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    phone = "789"
    assert_no_difference "ProfileAnswer.count" do
      post :update, params: { :id => user.id, :profile_answers => {q.id.to_s => phone}, :section_id => q.section.id}
    end
    assert_equal phone, last.reload.answer_text
    assert_equal user.answer_for(q), last
  end

  def test_should_not_create_answers_for_student_mentor
    user = users(:f_mentor_student)
    current_user_is :f_mentor_student
    pr = programs(:albers)
    q = programs(:org_primary).profile_questions.find_by(question_text: "Expertise")
    assert_nil user.answer_for(q)
    MembersController.any_instance.expects(:expire_profile_cached_fragments).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    expertise = "Maths"
    assert_difference "ProfileAnswer.count", 1 do
      post :update_answers, params: { :id => user.id, :profile_answers => {q.id => expertise}, :section_id => q.section.id}
    end
    last = ProfileAnswer.last
    assert_equal expertise, last.reload.answer_text
    assert_equal user.answer_for(q), last
  end

  def test_update_mandatory_answers
    user = users(:f_mentor)
    member = user.member
    program = programs(:albers)
    current_user_is user

    mentor_q1 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :question_choices => ["Abc", "Def"], :role_names => [RoleConstants::MENTOR_NAME], :required => true, :question_text => "Whats your name?")

    admin_q1 = create_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Hi", :question_choices => ["L", "M", "N"], :required => true)

    conditional_question = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["Stand", "Walk", "Run"], :role_names => [RoleConstants::MENTOR_NAME], :required => true, :question_text => "cond q")
    conditional_question.update_attributes!(section: programs(:org_primary).sections.third)

    q1 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :role_names => [RoleConstants::MENTOR_NAME], conditional_question_id: conditional_question.id, conditional_match_text: "Stand", :question_text => "cond q1")
    q1.update_attributes!(section: programs(:org_primary).sections.third)
    q2 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :role_names => [RoleConstants::MENTOR_NAME], conditional_question_id: conditional_question.id, conditional_match_text: "Run", :question_text => "cond q2")
    q2.update_attributes!(section: programs(:org_primary).sections.fourth)
    q3 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :role_names => [RoleConstants::STUDENT_NAME], conditional_question_id: conditional_question.id, conditional_match_text: "Stand", :question_text => "cond q3")
    q4 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :role_names => [RoleConstants::MENTOR_NAME], conditional_question_id: conditional_question.id, conditional_match_text: "Walk", :question_text => "cond q4")
    q4.update_attributes!(section: programs(:org_primary).sections.third)

    q5 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :role_names => [RoleConstants::MENTOR_NAME], conditional_question_id: conditional_question.id, conditional_match_text: "Walk", :question_text => "cond q5", private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    q5.update_attributes!(section: programs(:org_primary).sections.third)

    mandatory_child_question = create_question(program: programs(:albers), question_type: ProfileQuestion::Type::TEXT, role_names: [RoleConstants::MENTOR_NAME], conditional_question_id: conditional_question.id, conditional_match_text: "Run", question_text: "cond mandatory_child_question", required: true)
    mandatory_child_question.update_attributes!(section: conditional_question.section)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).times(5)

    assert_difference "ProfileAnswer.count", 1 do
      post :update_mandatory_answers, xhr: true, params: { :id => member.id, :profile_answers => {mentor_q1.id => "Maths"}, section_id: mentor_q1.section.id}
      assert assigns(:is_self_view)
    end
    assert_equal_unordered assigns(:unanswered_mandatory_profile_qs), [admin_q1, conditional_question, q1, q4, mandatory_child_question]

    programs(:albers).reload
    
    assert_difference "ProfileAnswer.count", 1 do
      post :update_mandatory_answers, xhr: true, params: { :id => member.id, :profile_answers => {admin_q1.id => "L"}, section_id: admin_q1.section.id}
    end
    assert_equal_unordered assigns(:unanswered_mandatory_profile_qs), [conditional_question, q1, q4, mandatory_child_question]

    programs(:albers).reload
    assert_difference "ProfileAnswer.count", 2 do
      post :update_mandatory_answers, xhr: true, params: { :id => member.id, :profile_answers => {conditional_question.id => "Stand", q1.id => "rini", q4.id => "Walk"}, section_id: conditional_question.section.id}
    end
    assert_equal [], assigns(:unanswered_mandatory_profile_qs)

    programs(:albers).reload
    assert_difference "ProfileAnswer.count", -1 do
      post :update_mandatory_answers, xhr: true, params: { :id => member.id, :profile_answers => {conditional_question.id => "Run", q1.id => "rini", q4.id => "Walk"}, section_id: conditional_question.section.id}
    end
    assert_equal [mandatory_child_question], assigns(:unanswered_mandatory_profile_qs)

    programs(:albers).reload
    assert_difference "ProfileAnswer.count", 1 do
      post :update_mandatory_answers, xhr: true, params: { :id => member.id, :profile_answers => {conditional_question.id => "Run", q1.id => "rini", q4.id => "Walk", mandatory_child_question.id => "abc"}, section_id: conditional_question.section.id}
    end
    assert_equal [], assigns(:unanswered_mandatory_profile_qs)
  end

  def test_only_logged_in_users_should_access_the_account_settings_page
    current_user_is :f_mentor

    get :account_settings
    assert_response :success

    assert_select "div#org_settings" do
      assert_select "form[action=?]", update_with_reset_code_url
    end
  end

  def test_account_settings_page_for_mentee_should_not_have_mentoring_preferences
    current_user_is :f_student

    get :account_settings
    assert_response :success
    assert_select "div#max_connections_limit", 0
  end

  def test_max_capacity_setting_change_from_account_setting
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    user = users(:f_mentor)

    assert_no_difference 'UserSetting.count' do
      put :update_settings, xhr: true, params: { :user=>{:user_settings => {:max_meeting_slots => 2}, :program_id => user.program.id}, :id => users(:f_mentor).id}
    end
    assert_response :success
    assert_equal 2, user.reload.user_setting.max_meeting_slots
    user.user_setting.destroy
    assert_difference 'UserSetting.count', 1 do
      put :update_settings, xhr: true, params: { :user=>{:user_settings => {:max_meeting_slots => 3}}, :id => users(:f_mentor).id}
    end
    assert_response :success
    assert_equal 3, user.reload.user_setting.max_meeting_slots
  end

  def test_max_connections_limit
    current_user_is :f_mentor
    user = users(:f_mentor)
    assert_equal 2, user.max_connections_limit

    put :update_settings, xhr: true, params: { :user => {:max_connections_limit => 0}, :id => users(:f_mentor).id}
    assert_response :success

    assert assigns(:settings_error_case)
    assert_not_equal 0, user.reload.max_connections_limit
    assert_equal 2, user.max_connections_limit
  end

  def test_update_time_zone_for_member
    user = users(:f_mentor)
    member = user.member
    assert_not_equal "Asia/Kolkata", member.time_zone

    current_user_is user
    put :update_time_zone, xhr: true, params: { id: member.id, member: { time_zone: "Asia/Kolkata" } }
    assert_redirected_to program_root_path
    assert_equal "Asia/Kolkata", member.reload.time_zone
  end

  def test_account_settings_page_for_mentor_should_have_mentoring_preferences
    current_user_is :f_mentor

    get :account_settings
    assert_response :success
    assert_select "input#max_connections_limit_#{programs(:org_primary).programs.ordered.first.id}", 1
  end

  def test_account_settings_page_for_mentor_should_have_max_capacity_settings_if_calendar_enabled
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    get :account_settings
    assert_response :success
    assert_select "input#max_meeting_slots_#{programs(:org_primary).programs.ordered.first.id}", 1
  end

  def test_account_settings_page_at_organization_level_should_have_all_programs_settings
    current_member_is :f_mentor

    get :account_settings
    assert_response :success
    assert_select "div.program_settings", Member.find(members(:f_mentor).id).programs.count
  end

  def test_account_settings_page_at_program_level_should_have_only_one_programs_setting
    current_user_is :f_mentor

    get :account_settings
    assert_response :success
    assert_select "div.program_settings", 1
  end

  def test_non_logged_in_users_should_not_get_account_settings_page
    current_program_is :albers
    get :account_settings
    assert_redirected_to new_session_path
  end

  def test_invite_to_program_permission
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    member = users(:f_mentor).member
    program = member.programs[0]
    current_user_is :f_mentor

    assert_permission_denied do
      post :invite_to_program, params: { member_id: member.id, program_id: program.id, :role => "allow_roles", :allow_roles => ["mentor", "student"], message: "join"}
    end
  end

  def test_invite_to_program_existing_member
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    member = users(:f_mentor).member
    program = member.programs[0]
    current_user_is :f_admin

    assert member.organization.programs.include?(program)
    initial_size = program.program_invitations.size
    post :invite_to_program, params: { member_id: member.id, program_id: program.id, :role => "allow_roles", :allow_roles => ["mentor"], message: "join"}
    assert_redirected_to member_url(member)
    assert_equal "Good unique name is already a member of Albers Mentor Program", flash[:notice]
    assert_equal initial_size, assigns(:program).program_invitations.size
  end

  def test_invite_to_program_dormant_member
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    dormant_member = create_member(organization: programs(:org_primary), first_name: "first", last_name: "last", email: "dormant@domain.com", state: Member::Status::DORMANT)
    program = programs(:albers)
    current_user_is :f_admin
    initial_size = program.program_invitations.size
    post :invite_to_program, params: { member_id: dormant_member.id, program_id: program.id, :role => "allow_roles", :allow_roles => ["mentor", "student"], message: "join"}
    assert_equal "en", program.program_invitations.last.locale
    assert_redirected_to member_url(dormant_member)
    assert_equal "first last is invited to join Albers Mentor Program. <a href=\"/p/albers/program_invitations\">Click here</a> to view the invitation(s).", flash[:notice]
    assert_equal initial_size + 1, assigns(:program).program_invitations.size
  end

  def test_invite_to_program_for_specific_role_dormant_member
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    dormant_member = create_member(organization: programs(:org_primary), first_name: "first", last_name: "last", email: "dormant@domain.com", state: Member::Status::DORMANT)
    program = programs(:albers)
    current_user_is :f_admin

    assert_difference "ProgramInvitation.count", 1 do
      post :invite_to_program, params: { member_id: dormant_member.id, program_id: program.id, :role => "allow_roles", :allow_roles => ["student"], message: "join"}
      assert_redirected_to member_url(dormant_member)
    end
    assert_equal "first last is invited to join Albers Mentor Program. <a href=\"/p/albers/program_invitations\">Click here</a> to view the invitation(s).", flash[:notice]
    assert_equal [RoleConstants::STUDENT_NAME], ProgramInvitation.last.role_names
  end

  def test_invite_to_program_for_multiple_role_dormant_member
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    dormant_member = create_member(organization: programs(:org_primary), first_name: "first", last_name: "last", email: "dormant@domain.com", state: Member::Status::DORMANT)
    program = programs(:albers)
    current_user_is :f_admin

    assert_difference "ProgramInvitation.count", 1 do
      post :invite_to_program, params: { member_id: dormant_member.id, program_id: program.id, :role => "allow_roles", :allow_roles => ["mentor", "student"], message: "join"}
      assert_redirected_to member_url(dormant_member)
    end
    assert_equal "first last is invited to join Albers Mentor Program. <a href=\"/p/albers/program_invitations\">Click here</a> to view the invitation(s).", flash[:notice]
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], ProgramInvitation.last.role_names
  end

  def test_do_not_highlight_fields_for_admin
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_admin).id}

    assert_response :success
    assert_no_select "div.incomplete_field"
  end

  def test_donot_highlight_incomplete_fields_in_edit_profile_page_of_mentor
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_mentor).id}

    assert_response :success
    assert_no_select "div.incomplete_field"
  end

  def test_donot_highlight_incomplete_fields_in_edit_profile_page_of_student
    current_user_is :f_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_student).id}

    assert_response :success
    assert_no_select "div.incomplete_field"
  end

  def test_highlight_only_incomplete_fields_for_mentor
    current_user_is :f_mentor

    questions_for_mentor_to_answer = programs(:albers).profile_questions_for(users(:f_mentor).role_names, {default: false, skype: true})
    answered_questions = members(:f_mentor).profile_answers.for_question(questions_for_mentor_to_answer).answered
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_mentor).id, :prof_c => "true", :src => "profile_c", :section => "profile", :role_names => [RoleConstants::MENTOR_NAME]}

    assert_response :success
    assert_select "div.incomplete_field", :count => questions_for_mentor_to_answer.size-answered_questions.size
  end

  def test_highlight_only_incomplete_fields_for_student
    current_user_is :f_student

    questions_for_student_to_answer = programs(:albers).profile_questions_for(users(:f_student).role_names, {default: false, skype: true})
    answered_questions = members(:f_student).profile_answers.for_question(questions_for_student_to_answer).answered
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once

    get :edit, params: { :id => members(:f_student).id, :prof_c => "true", :src => "profile_c", :section => "profile", :role_names => [RoleConstants::STUDENT_NAME]}

    assert_response :success
    assert_select "div.incomplete_field", :count => questions_for_student_to_answer.size-answered_questions.size
  end

  def test_do_not_highlight_admin_only_editable_incomplete_fields_for_student
    current_user_is :f_student

    questions_for_student_to_answer = programs(:albers).profile_questions_for(users(:f_student).role_names, {default: false, skype: true})
    answered_questions = members(:f_student).profile_answers.for_question(questions_for_student_to_answer).answered
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).twice

    get :edit, params: { :id => members(:f_student).id, :prof_c => "true", :src => "profile_c", :section => "profile", :role_names => [RoleConstants::STUDENT_NAME]}

    assert_response :success
    assert_select "div.incomplete_field", :count => questions_for_student_to_answer.size-answered_questions.size

    role_question = (questions_for_student_to_answer-answered_questions).last.role_questions[0]
    role_question.update_attribute(:admin_only_editable, true)

    get :edit, params: { :id => members(:f_student).id, :prof_c => "true", :src => "profile_c", :section => "profile", :role_names => [RoleConstants::STUDENT_NAME]}

    assert_response :success
    assert_select "div.incomplete_field", :count => questions_for_student_to_answer.size-answered_questions.size-1
  end

  def test_do_not_highlight_hidden_conditional_incomplete_fields_for_student
    current_user_is :f_student

    questions_for_student_to_answer = programs(:albers).profile_questions_for(users(:f_student).role_names, {default: false, skype: true})
    answered_questions = members(:f_student).profile_answers.for_question(questions_for_student_to_answer).answered
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).twice

    get :edit, params: { :id => members(:f_student).id, :prof_c => "true", :src => "profile_c", :section => "profile", :role_names => [RoleConstants::STUDENT_NAME]}

    assert_response :success
    assert_select "div.incomplete_field", :count => questions_for_student_to_answer.size-answered_questions.size

    prof_question = (questions_for_student_to_answer-answered_questions).last
    prof_question.update_attributes!(:conditional_question_id => questions_for_student_to_answer.first.id)
    ConditionalMatchChoice.create(question_choice: questions_for_student_to_answer.first.question_choices.first, profile_question: questions_for_student_to_answer.first)

    get :edit, params: { :id => members(:f_student).id, :prof_c => "true", :src => "profile_c", :section => "profile", :role_names => [RoleConstants::STUDENT_NAME]}

    assert_response :success
    assert_select "div.incomplete_field", :count => questions_for_student_to_answer.size-answered_questions.size-1
  end

  def test_check_admin_only_viewable_question_for_admin
    current_user_is :f_admin
    profile_question = profile_questions(:multi_experience_q)
    role_question = profile_question.role_questions[0]
    role_question.update_attribute(:private, RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    role_question.reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never
    get :edit, params: { :id => members(:f_mentor).id}
    assert assigns(:program_questions_for_user).include?(profile_question)
  end

  def test_check_admin_only_viewable_question_for_non_admin
    current_user_is :f_mentor
    profile_question = profile_questions(:multi_experience_q)
    role_question = profile_question.role_questions[0]
    role_question.update_attribute(:private, RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    role_question.reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { :id => members(:f_mentor).id}
    assert_false assigns(:program_questions_for_user).include?(profile_question)
  end

  def test_check_admin_only_editable_question_for_admin
    current_user_is :f_admin
    profile_question = profile_questions(:multi_experience_q)
    role_question = profile_question.role_questions[0]
    role_question.update_attribute(:admin_only_editable, true)
    role_question.reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never
    get :edit, params: { :id => members(:f_mentor).id}
    assert assigns(:program_questions_for_user).include?(profile_question)
  end

  def test_edit_email_with_email_domain_security_setting_invalid
    security_setting = programs(:org_primary).security_setting
    assert_nil security_setting.email_domain
    security_setting.update_attributes!(:email_domain => "sample.com, tests.com, asdfasdfa.com")
    message = "should be of sample.com, tests.com, asdfasdfa.com"
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    current_user_is :f_student
    programs(:org_primary).reload
    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', :member => {:email => "sample@chronus.com", :first_name => "New Name", :last_name => "student", :password => "manju#Mmanju#Mmanju1#M", :password_confirmation => "manju#Mmanju#Mmanju1#M"}}
    assert_equal [message], assigns(:profile_member).errors[:email]
  end

  def test_edit_email_with_email_domain_security_setting_success
    security_setting = programs(:org_primary).security_setting
    assert_nil security_setting.email_domain
    security_setting.update_attributes!(:email_domain => "sample.com, reste.com, asdfasdf.com")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    current_user_is :f_student
    programs(:org_primary).reload
    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', :member => {:email => "awesome@reste.com", :first_name => "New Name", :last_name => "student", :password => "manju#Mmanju#Mmanju1#M", :password_confirmation => "manju#Mmanju#Mmanju1#M"}}
    assert assigns(:profile_member).errors[:email].blank?
  end

  def test_password_should_not_contain_login_name_containing_first_name
    message = "should not contain your name or your email address"
    security_setting = programs(:org_primary).security_setting
    assert security_setting.can_contain_login_name?
    security_setting.update_attributes!(:can_contain_login_name => false)
    assert_false security_setting.can_contain_login_name?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    current_user_is :f_student
    programs(:org_primary).reload
    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', :member => {:first_name => "Name", :last_name => "student", :password => "name123", :password_confirmation => "name123"}}
    assert_equal [message], assigns(:profile_member).errors[:password]
  end

  def test_password_should_not_contain_login_name_containing_invalid_email
    message = "should not contain your name or your email address"
    security_setting = programs(:org_primary).security_setting
    assert security_setting.can_contain_login_name?
    security_setting.update_attributes!(:can_contain_login_name => false)
    assert_false security_setting.can_contain_login_name?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    current_user_is :f_student
    programs(:org_primary).reload
    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', :member => {:first_name => "Name", :last_name => "student", :password => "student123", :password_confirmation => "student123"}}
    assert_equal [message], assigns(:profile_member).errors[:password]
  end

  def test_password_should_not_contain_login_name_invalid_containing_last_name
    message = "should not contain your name or your email address"
    security_setting = programs(:org_primary).security_setting
    assert security_setting.can_contain_login_name?
    security_setting.update_attributes!(:can_contain_login_name => false)
    assert_false security_setting.can_contain_login_name?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    current_user_is :f_student
    programs(:org_primary).reload
    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', :member => {:first_name => "Name", :last_name => "student", :password => "rahim123", :password_confirmation => "rahim123"}}
    assert_equal [message], assigns(:profile_member).errors[:password]
  end

  def test_password_should_not_contain_login_name_success
    security_setting = programs(:org_primary).security_setting
    assert security_setting.can_contain_login_name?
    security_setting.update_attributes!(:can_contain_login_name => false)
    assert_false security_setting.can_contain_login_name?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    current_user_is :f_student
    programs(:org_primary).reload
    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', :member => {:first_name => "Name", :last_name => "rahim", :password => "random123", :password_confirmation => "random123"}}
    assert assigns(:profile_member).errors[:password].blank?
  end

  def test_admin_only_access_for_account_lockouts_for_student
    current_member_is :f_student

    assert_permission_denied do
      get :account_lockouts
    end
  end

  def test_admin_only_access_for_account_lockouts_for_admin
    current_member_is :f_admin

    assert_permission_denied do
      get :account_lockouts
    end
  end

  def test_admin_only_access_for_account_lockouts_for_admin_success
    current_member_is :f_admin
    org = programs(:org_primary)
    org.security_setting.update_attributes!(:maximum_login_attempts => 2)
    members = org.members.all[2..4]
    members.each {|member| member.account_lockout!(true)}

    get :account_lockouts
    assert_response :success
    assert_equal members, assigns(:locked_out_members)
  end

  def test_admin_only_access_for_reactivate_account
    current_member_is :f_admin

    assert_permission_denied do
      post :reactivate_account, params: { :id => 1}
    end
  end

  def test_reactivate_account_success
    current_member_is :f_admin
    org = programs(:org_primary)
    org.security_setting.update_attributes!(:maximum_login_attempts => 2)
    member = org.members.all[4]
    member.account_lockout!(true)
    assert member.account_locked_at.present?

    post :reactivate_account, xhr: true, params: { :id => member.id}
    assert_response :success

    assert_nil member.reload.account_locked_at
    assert_equal 0, member.failed_login_attempts
  end

  def test_update_state_permission_denied
    member  = members(:student_3)

    current_member_is :f_student
    assert_permission_denied do
      put :update_state, params: { id: member.id, new_state: Member::Status::SUSPENDED, state_change_reason: "Reason"}
    end
    assert_false member.reload.suspended?
  end

  def test_update_state_to_suspend_expects_can_remove_or_suspend
    member = members(:f_student)

    Member.any_instance.expects(:can_remove_or_suspend?).returns(false)
    current_member_is :f_admin
    assert_permission_denied do
      put :update_state, params: { id: member.id, new_state: Member::Status::SUSPENDED, state_change_reason: "Reason"}
    end
    assert_false member.reload.suspended?
  end

  def test_update_state_to_suspend
    request.env["HTTP_REFERER"] = '/' # some path needed since redirect_to :back is there
    current_member_is :f_admin
    test_member = members(:f_student)
    assert test_member.users.size > 1
    assert_false test_member.suspended?
    test_member.users.each do |user|
      assert_false user.suspended?
    end
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      put :update_state, params: { id: test_member.id, new_state: Member::Status::SUSPENDED, state_change_reason: "test"}
    end
    assert test_member.reload.suspended?
    test_member.users.each do |user|
      assert user.suspended?
    end
    mail = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(mail)
    assert_equal "Your membership has been suspended", mail.subject
    assert_equal test_member.email, mail.to[0]
    assert_match "This is to inform you that the program administrator has suspended your membership in Primary Organization", mail_content
    assert_match users(:f_admin).name, mail_content
  end

  def test_update_state_to_active
    request.env["HTTP_REFERER"] = '/' # some path needed since redirect_to :back is there
    current_member_is :f_admin
    test_member = members(:f_student)
    test_member.suspend!(members(:f_admin), "test 1")
    assert test_member.reload.users.size > 1
    assert_false test_member.active?
    test_member.users.each do |user|
      assert_false user.active?
    end
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      put :update_state, params: { id: test_member.id, new_state: Member::Status::ACTIVE}
    end
    assert test_member.reload.active?
    test_member.users.each do |user|
      assert user.active?
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Your account is now reactivated!", mail.subject
    assert_equal test_member.email, mail.to[0]
    assert_match /Your account in Primary Organization has been reactivated/, mail.to_s
  end

  def test_destroy_permission_denied
    current_member_is :f_student
    assert_no_difference "Member.count" do
      assert_permission_denied do
        delete :destroy, params: { id: members(:student_3).id}
      end
    end
  end

  def test_destroy_cannot_remove_self
    admin = members(:f_admin)

    current_member_is admin
    assert_no_difference "Member.count" do
      assert_permission_denied do
        delete :destroy, params: { id: admin.id}
      end
    end
  end

  def test_destroy_expects_can_remove_or_suspend
    admin = members(:f_admin)
    admin_name = admin.name
    users_count = admin.users.size
    assert users_count > 1

    Member.any_instance.expects(:can_remove_or_suspend?).returns(true)
    current_member_is admin
    assert_difference "User.count", -users_count do
      assert_difference "Member.count", -1 do
        delete :destroy, params: { id: admin.id}
      end
    end
    assert_equal "#{admin_name}'s profile, any engagements and other contributions have been removed", flash[:notice]
    assert_redirected_to root_path
  end

  def test_destroy_prompt_permission
    current_member_is :f_mentor
    assert_permission_denied do
      get :destroy_prompt, params: { id: members(:student_3).id, format: :js}
    end
  end

  def test_mentees_count_for_student_with_program_request_style_set_as_none
    current_user_is :f_student
    member = members(:f_mentor)
    student = users(:f_admin_nwen)
    mentor = users(:f_mentor_nwen_student)
    program = programs(:albers)
    student.add_role(RoleConstants::STUDENT_NAME)
    mentor.add_role(RoleConstants::MENTOR_NAME)

    assert_equal 2, member.students.size
    create_group(:student => student, :mentor => mentor, :program => programs(:nwen))
    assert_equal 3, member.reload.students.size
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::NONE)
    program.find_role(RoleConstants::ADMIN_NAME).remove_permission("manage_mentor_requests")
    program.find_role(RoleConstants::STUDENT_NAME).remove_permission("send_mentor_request")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once

    get :show, params: { id: member.id}
    assert_response :success
    assert_select "div#mentor_profile" do
      assert_select "div.ibox:nth-of-type(1)" do
        assert_select "div.ibox-content" do
          assert_select ".pull-left.col-xs-6" do
            assert_no_select ".ct_mentees_count"
          end
        end
      end
    end
  end

  def test_mentees_count_for_mentor
    current_user_is :f_mentor
    member = members(:f_mentor)
    student = users(:f_admin_nwen)
    mentor = users(:f_mentor_nwen_student)
    student.add_role(RoleConstants::STUDENT_NAME)
    mentor.add_role(RoleConstants::MENTOR_NAME)
    programs(:albers).enable_feature(FeatureName::OFFER_MENTORING)
    assert_equal 2, member.students.size
    create_group(:student => student, :mentor => mentor, :program => programs(:nwen))
    assert_equal 3, member.reload.students.size
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => member.id}
    assert_response :success

    assert_select ".ct_name_title" do
      assert_no_select ".text-muted"
    end
  end

  def test_mentees_and_mentor_count_for_student_with_dual_role
    current_user_is :f_mentor_student
    f_mentor_student = users(:f_mentor_student)
    member = members(:f_mentor_student)
    student = users(:f_student)
    mentor = users(:f_mentor_nwen_student)
    program = programs(:albers)

    create_group(:student => student, :mentor => users(:f_mentor_student), :program => program)
    program.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_ADMIN
    program.save!
    programs(:albers).enable_feature(FeatureName::OFFER_MENTORING)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { id: member.id}
    assert_response :success
    assert_select ".ct_mentees_count", false
    assert_select ".ct_mentors_count", false
  end

  def test_mentees_count_for_student_with_program_request_style_set_as_mentee_to_admin
    current_user_is :f_student
    member = members(:f_mentor)
    student = users(:f_admin_nwen)
    mentor = users(:f_mentor_nwen_student)
    program = programs(:albers)

    student.add_role(RoleConstants::STUDENT_NAME)
    mentor.add_role(RoleConstants::MENTOR_NAME)

    assert_equal 2, member.students.size
    create_group(:student => student, :mentor => mentor, :program => programs(:nwen))
    assert_equal 3, member.reload.students.size
    program.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_ADMIN
    program.save!
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once

    get :show, params: { :id => member.id}
    assert_response :success
    assert_select "div#mentor_profile" do
      assert_select "div.ibox:nth-of-type(1)" do
        assert_select "div.ibox-content" do
          assert_select ".pull-left.col-xs-6" do
            assert_select ".ct_mentees_count", false
          end
        end
      end
    end
  end

  def test_mentees_count_for_admin_with_program_request_style_set_as_mentee_to_admin
    current_user_is :f_admin
    member = members(:f_mentor)
    student = users(:f_admin_nwen)
    mentor = users(:f_mentor_nwen_student)
    program = programs(:albers)

    student.add_role(RoleConstants::STUDENT_NAME)
    mentor.add_role(RoleConstants::MENTOR_NAME)
    assert_equal 2, member.students.size
    create_group(:student => student, :mentor => mentor, :program => programs(:nwen))
    assert_equal 3, member.reload.students.size

    program.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_ADMIN
    program.save!
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never

    get :show, params: { :id => member.id}
    assert_response :success

    assert_select ".ct_name_title" do
      assert_no_select ".ct_mentees_count"
    end
  end

  def test_mentees_count_for_admin_with_mentor_request_style_set_to_none_in_non_self_view
    current_user_is :f_admin
    member = members(:f_mentor)
    student = users(:f_admin_nwen)
    mentor = users(:f_mentor_nwen_student)
    program = programs(:albers)

    student.add_role(RoleConstants::STUDENT_NAME)
    mentor.add_role(RoleConstants::MENTOR_NAME)
    assert_equal 2, member.students.size
    create_group(:student => student, :mentor => mentor, :program => programs(:nwen))
    assert_equal 3, member.reload.students.size
    program.mentor_request_style = Program::MentorRequestStyle::NONE
    program.save!
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never

    get :show, params: { :id => member.id}
    assert_response :success
    assert_select ".ct_name_title" do
      assert_no_select ".ct_mentees_count"
    end
  end

  def test_mentees_count_for_mentors_in_organization_view
    current_member_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => members(:f_mentor)}
    assert_response :success

    assert_select ".ct_name_title" do
      assert_no_select ".ct_mentees_count"
    end
  end

  def test_mentees_count_for_mentors_in_organization_view_with_a_program_request_style_set_to_none
    current_member_is :f_admin
    program = programs(:albers)
    program.mentor_request_style = Program::MentorRequestStyle::NONE
    program.save!
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor)}
    assert_response :success

    assert_select ".ct_name_title" do
      assert_no_select ".ct_mentees_count"
    end
  end

  def test_mentees_count_for_mentors_with_mentor_request_style_set_to_none_in_self_view
    current_user_is :f_mentor
    member = members(:f_mentor)
    student = users(:f_admin_nwen)
    mentor = users(:f_mentor_nwen_student)
    program = programs(:albers)

    student.add_role(RoleConstants::STUDENT_NAME)
    mentor.add_role(RoleConstants::MENTOR_NAME)
    assert_equal 2, member.students.size
    create_group(:student => student, :mentor => mentor, :program => programs(:nwen))
    assert_equal 3, member.reload.students.size
    program.mentor_request_style = Program::MentorRequestStyle::NONE
    program.save!
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => member.id}
    assert_response :success
    assert_select "div#mentor_profile" do
      assert_select ".ct_name_title" do
        assert_no_select ".text-muted"
        assert_no_select ".ct_mentees_count"
      end
    end
  end


  def test_match_score_in_self_view_is_not_allowed
    current_user_is :f_mentor
    member = members(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once

    get :show, params: { :id => member.id}
    assert_response :success
    assert_no_select ".ct-match-percent"
  end

  def test_match_score_in_non_self_view_is_allowed
    current_user_is :f_student
    member = members(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once

    get :show, params: { :id => member.id}
    assert_response :success
    assert_select ".ct-match-percent"
  end

  def test_match_score_for_student_is_not_allowed
    current_user_is :f_mentor
    member = members(:f_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => member.id}
    assert_response :success
    assert_no_select ".ct-match-percent"
  end

  def test_match_score_is_not_allowed_if_user_cannot_send_mentor_request_and_calendar_is_not_enabled
    current_user_is :f_student
    member = members(:f_mentor)
    User.any_instance.expects(:can_send_mentor_request?).returns(false).at_least_once
    Program.any_instance.expects(:calendar_enabled?).returns(false).at_least_once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once
    get :show, params: { :id => member.id}
    assert_response :success
    assert_no_select ".ct-match-percent"
  end

  def test_match_score_is_allowed_if_user_cannot_send_mentor_request_and_calendar_is_enabled
    current_user_is :f_student
    member = members(:f_mentor)
    User.any_instance.expects(:can_send_mentor_request?).returns(false).at_least_once
    Program.any_instance.expects(:calendar_enabled?).returns(true).at_least_once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once
    get :show, params: { :id => member.id}
    assert_response :success
    assert_select ".ct-match-percent"
  end

  def test_match_score_is_allowed_if_user_can_send_mentor_request_and_calendar_is_not_enabled
    current_user_is :f_student
    member = members(:f_mentor)
    User.any_instance.expects(:can_send_mentor_request?).returns(true).at_least_once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once
    get :show, params: { :id => member.id}
    assert_response :success
    assert_select ".ct-match-percent"
  end

  def test_add_member_as_admin_in_organization
    current_member_is :f_admin

    assert_false members(:f_student).admin?

    assert_difference 'User.count', 2 do
      post :add_member_as_admin, params: { :id => members(:f_student).id, :program_id => "-1"}
    end
    assert members(:f_student).reload.admin?
    assert_equal "#{members(:f_student).name(:name_only => true)} has been added to the list of administrators", flash[:notice]
    assert_redirected_to member_path(members(:f_student))
  end

  def test_add_member_as_admin_in_different_organization
    current_member_is :f_admin

    assert_difference 'User.count', 0 do
      assert_record_not_found do
        post :add_member_as_admin, params: { :id => members(:arun_ceg).id, :program_id => "-1"}
      end
    end
    assert_nil flash[:notice]
  end

  def test_add_member_as_admin_in_existing_program
    current_member_is :f_admin

    assert_false members(:f_student).user_in_program(programs(:nwen)).is_admin?

    assert_difference 'User.count', 0 do
      assert_difference 'ActionMailer::Base.deliveries.size', 1 do
        post :add_member_as_admin, params: { :id => members(:f_student).id, :program_id => programs(:nwen).id}
      end
    end
    assert members(:f_student).reload.user_in_program(programs(:nwen)).is_admin?
    assert_equal members(:f_student).name(:name_only => true) + " has been added to the list of administrators", flash[:notice]
  end

  def test_add_member_as_admin_in_new_program
    member = members(:f_student)
    program = programs(:moderated_program)
    assert_nil member.user_in_program(program)

    current_member_is :f_admin
    assert_difference "User.count" do
      assert_emails 1 do
        post :add_member_as_admin, params: { id: member.id, program_id: program.id}
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "#{member.name(name_only: true)} has been added to the list of administrators", flash[:notice]
    assert member.reload.user_in_program(program).is_admin?
    assert_match /<a[^>]*href=\"https:\/\/primary.#{DEFAULT_HOST_NAME}\/p\/#{program.root}\/members\/#{member.id}\/edit\?first_visit=true/, get_html_part_from(email)
  end

  def test_dormant_member_as_admin_in_new_program
    member = members(:dormant_member)
    program = programs(:no_subdomain)
    assert_nil member.user_in_program(program)

    current_member_is :no_subdomain_admin
    Member.any_instance.stubs(:can_signin?).returns(false)
    assert_difference "User.count" do
      assert_emails 1 do
        post :add_member_as_admin, params: { id: member.id, program_id: program.id}
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "#{member.name(name_only: true)} has been added to the list of administrators", flash[:notice]
    assert member.reload.user_in_program(program).is_admin?
    assert_match(/<a[^>]*href=\"https:\/\/nosubdomtest.com\/p\/#{program.root}\/users\/new_user_followup\?reset_code=#{member.passwords.first.reset_code}/, get_html_part_from(email))
  end

  def test_add_member_as_admin_in_different_program
    current_member_is :f_admin

    assert_false users(:f_student).member.admin?
    assert_difference 'User.count', 0 do
      assert_record_not_found do
        post :add_member_as_admin, params: { :id => users(:f_student).id, :program_id => programs(:ceg).id}
      end
    end
    assert_false users(:f_student).reload.member.admin?
  end

def test_permission_denied_for_add_member_as_admin_in_different_program
  current_member_is :f_student

  assert_permission_denied do
    post :add_member_as_admin, params: { :id => users(:f_student).id, :program_id => programs(:ceg).id}
  end
end

def test_qa_answers_page
  current_program_is :albers
  current_user_is :f_admin
  u1 = users(:f_mentor)
  u = u1.member

  qa_question = programs(:albers).qa_questions.first
  ans1 = create_qa_answer(:qa_question => qa_question, :user => u1, :content => "My first answer")
  ans1.update_attribute(:created_at, 1.week.ago)
  ans2 = create_qa_answer(:qa_question => qa_question, :user => u1, :content => "My second answer")
  @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

  get :show, params: { :id => u.id, :tab => MembersController::ShowTabs::QA_ANSWERS}

  assert_select "div#qa_question_#{qa_question.id}" do
    assert_select "div", :text => /My second answer/
  end
end

  def test_it_should_assign_unanswered_questions
    current_member_is :foster_admin
    member = members(:foster_mentor7)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never
    get :show, params: { :id => member.id}
    assert_response :success
    assert assigns(:unanswered_questions).present?
  end

  def test_get_invite_to_program_roles
    user = users(:f_admin)
    member = user.member
    program = user.program

    current_member_is member
    get :get_invite_to_program_roles, xhr: true, params: { id: member.id, program_id: program.id }
    assert_response :success
    assert_equal program, assigns(:program)
    assert_equal user, assigns(:user)
  end

  def test_skip_answer
    current_member_is :f_admin
    current_program_is :albers
    member = members(:f_admin)
    question = profile_questions(:multi_experience_q)

    get :skip_answer, xhr: true, params: { :id => member.id, :home_page => true, :question_id => question.id}
    assert_response :success

    answer = member.answer_for(question)

    assert assigns(:home_page)
    assert answer.not_applicable?
    assert_blank answer.answer_text

    # Profile picture
    assert member.profile_picture.blank?
    get :skip_answer, xhr: true, params: { :id => member.id, :profile_picture => true}
    assert_response :success
    profile_picture = member.reload.profile_picture
    assert profile_picture.present?
    assert profile_picture.not_applicable?
  end

  def test_show_availability_self_with_archive_for_xss_issue
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    programs(:albers).calendar_setting.update_attribute(:allow_create_meeting_for_mentor, false)
    current_user_is :f_mentor
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    m = members(:f_mentor)
    time = Time.now.change(usec: 0)
    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), time - 100.minutes, time+20.minutes, {duration: 20.minutes})
    update_recurring_meeting_start_end_date(meetings(:student_2_not_req_mentor), time+150.minutes, time+160.minutes, {duration: 10.minutes})
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).once
    get :show, params: { :id => m.id, :tab => MembersController::ShowTabs::AVAILABILITY, :src => "quick_links", :meeting_id => "#{meetings(:f_mentor_mkr_student).id}<whs//]]></script><script>prompt()</script>check>"}
    assert_equal wp_collection_from_array([{:current_occurrence_time => meetings(:f_mentor_mkr_student).start_time, :meeting => meetings(:f_mentor_mkr_student)},  {:current_occurrence_time => meetings(:cancelled_calendar_meeting).start_time, :meeting => meetings(:cancelled_calendar_meeting)}, {:current_occurrence_time => meetings(:completed_calendar_meeting).start_time, :meeting => meetings(:completed_calendar_meeting)},{:current_occurrence_time => meetings(:past_calendar_meeting).start_time, :meeting => meetings(:past_calendar_meeting)}]), assigns(:archived_meetings)
    assert_false assigns(:can_current_user_create_meeting) #current_user is mentor. Calender is enabled and create meeting seeting is false
    assert_equal meetings(:f_mentor_mkr_student).id.to_s, assigns(:meeting_id)
  end

  def test_invalid_meeting_in_show
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    programs(:albers).calendar_setting.update_attribute(:allow_create_meeting_for_mentor, false)
    current_user_is :f_mentor
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => members(:f_mentor).id, :tab => MembersController::ShowTabs::AVAILABILITY, :src => "quick_links", :meeting_id => 0}
    assert_nil assigns(:current_occurrence_time)
    assert_nil assigns(:hashed_feedback_id)
    assert_equal "The meeting you are trying to access does not exist.", flash[:error]
    assert_redirected_to root_path
  end

  def test_show_reviews
    programs(:albers).enable_feature(FeatureName::COACH_RATING)
    current_program_is :albers
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never
    get :show, params: { :id => members(:f_mentor).id}
    assert_nil assigns(:show_reviews)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never
    get :show, params: { :id => members(:f_mentor).id, :root => 'albers', :show_reviews => 'abc'}
    assert assigns(:show_reviews)
  end

  def test_show_mentor_request_popup_global_level
    current_member_is :f_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never

    get :show, params: { :id => members(:f_mentor).id, :show_mentor_request_popup => true, :src => "mail"}

    assert_response :success
    assert_nil assigns(:profile_user)
    assert_nil assigns(:show_mentor_request_popup)
    assert_nil assigns(:mentor_request_url)
  end

  def test_show_pending_connection_requests
    current_user_is :f_mentor
    m1 = create_mentor_request(:student => users(:rahim),
      :mentor => users(:f_mentor), :message => 'good')
    programs(:albers).update_attributes(allow_one_to_many_mentoring: true)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    get :show, params: { :id => users(:rahim)}
    assert assigns(:show_connection_requests)
    assert_equal [m1], assigns(:side_pane_connection_requests)
    assert_equal [m1], assigns(:side_pane_requests)
    assert_equal 1, assigns(:side_pane_requests_count)
  end

  def test_show_pending_meeting_requests
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    m1 = create_meeting_request(:student => users(:rahim),
      :mentor => users(:f_mentor))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    get :show, params: { :id => users(:rahim)}
    assert assigns(:show_meeting_requests)
    assert_equal [m1], assigns(:side_pane_requests)
    assert_equal 1, assigns(:side_pane_requests_count)
  end

  def test_show_mentor_request_popup_for_no_popup
    current_user_is :f_student
    current_program_is :albers
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once

    get :show, params: { :id => members(:f_mentor).id, :root => 'albers', :show_mentor_request_popup => true, :src => "mail"}

    assert_response :success
    assert_false assigns(:show_mentor_request_popup)
    assert_nil assigns(:mentor_request_url)
    assert_equal "#{members(:f_mentor).name} is not available for a mentoring connection at this time and is not accepting any requests. You can look for other mentors who are available and reach out to them from <a href=\"/p/albers/users\">here</a>.", assigns(:invalid_mentor_request_flash)
  end

  def test_show_mentor_request_popup_with_no_param
    current_user_is :f_student
    current_program_is :albers
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once

    get :show, params: { :id => members(:f_mentor).id, :root => 'albers', :src => "mail"}

    assert_response :success
    assert_nil assigns(:show_mentor_request_popup)
    assert_nil assigns(:mentor_request_url)
    assert_nil assigns(:invalid_mentor_request_flash)
  end

  def test_show_mentor_request_popup_showing_popup
    current_user_is :f_student
    current_program_is :albers

    User.any_instance.stubs(:can_send_mentor_request_to_mentor_with_error_flash?).returns([true, "some text"])
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once

    get :show, params: { :id => members(:f_mentor).id, :root => 'albers', :show_mentor_request_popup => true, :src => "mail"}

    assert_response :success
    assert assigns(:show_mentor_request_popup)
    assert_equal "some text", assigns(:invalid_mentor_request_flash)
    assert_equal new_mentor_request_path(mentor_id: users(:f_mentor).id, format: :js, src: "mail"), assigns(:mentor_request_url)
  end

  def test_mentoring_mode_no_update_for_mentee
    current_user_is :f_student
    current_program_is :albers
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, params: { :id => members(:f_student), :first_visit => 'mentee', user: {mentoring_mode: 1}}
    assert_redirected_to edit_member_path(:first_visit => 'mentee', :section => MembersController::EditSection::PROFILE, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_equal assigns(:profile_user).mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING
  end

  def test_mentoring_mode_no_update_for_mentor_in_disabled_program
    current_user_is :f_mentor
    current_program_is :albers
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    post :update, params: { :id => members(:f_mentor), :first_visit => 'mentor', user: {mentoring_mode: 1}}
    assert_equal assigns(:profile_user).mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING
  end

  def test_mentoring_mode_no_update_for_mentor_in_enabled_program
    current_user_is :f_mentor
    current_program_is :albers
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never

    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    post :update, params: { :id => members(:f_mentor), :first_visit => 'mentor', user: {mentoring_mode: 1}}
    assert_equal assigns(:profile_user).mentoring_mode, User::MentoringMode::ONGOING
  end

  def test_mentoring_mode_update_fail_if_pending_requests
    user = users(:f_mentor)
    current_user_is user

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::PUBLISH_PROFILE).never
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)

    mentor_request = create_mentor_request
    user.update_attributes!(mentoring_mode: User::MentoringMode::ONE_TIME_AND_ONGOING)

    assert mentor_request.active?
    post :update, params: { id: members(:f_mentor),
      first_visit: true,
      section: MembersController::EditSection::MENTORING_SETTINGS,
      user: {mentoring_mode: User::MentoringMode::ONE_TIME}
    }

    assert_equal "You already have pending mentoring request(s), Kindly reply to those first and then you can change the mentoring mode.", assigns(:settings_flash_error)
    assert_redirected_to edit_member_path(user.member,
      section: MembersController::EditSection::MENTORING_SETTINGS,
      first_visit: true)
    assert_equal User::MentoringMode::ONE_TIME_AND_ONGOING, user.mentoring_mode
  end

  def test_update_setting_for_mentor_user_params
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    assert_equal 2, user.max_connections_limit

    put :update_settings, xhr: true, params: { :user => {:max_connections_limit => 0, mentoring_mode: User::MentoringMode::ONE_TIME}, :id => users(:f_mentor).id}
    assert_response :success
    assert_equal 2, user.reload.max_connections_limit
    assert_equal ["You already have pending mentoring request(s), Kindly reply to those first and then you can change the mentoring mode."], assigns(:error_message)
    assert assigns(:settings_error_case)
    assert_equal User::MentoringMode::ONE_TIME_AND_ONGOING, user.reload.mentoring_mode
  end

  def test_update_setting_for_mentor_member_params
    current_member_is :f_admin
    current_organization_is :org_primary
    member = members(:f_admin)

    @controller.expects(:fetch_profile_member)
    @controller.expects(:fetch_profile_user).never
    @controller.instance_variable_set(:@profile_member, member)

    put :update_settings, xhr: true, params: { :member => {:time_zone => "Asia/Kolkata"}, :id => member.id, :root => nil, :commit => "Save Settings", :acc_settings => true}
    assert_response :success
    assert_equal "Asia/Kolkata", member.reload.time_zone
  end

  def test_update_setting_from_account_settings_page_does_not_notify_user_if_unavailable
    user = users(:f_mentor)
    current_user_is user
    user.received_mentor_requests.destroy_all
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)

    put :update_settings, xhr: true, params: { user: { mentoring_mode: User::MentoringMode::ONE_TIME, id: user.id, program_id: program.id }, id: user.member_id, acc_settings: true }
    assert_response :success
    assert_nil assigns(:notify_user_if_unavailable)
  end


  def test_update_setting_for_mentor_updated
    current_user_is :f_mentor
    user = users(:f_mentor)
    user.received_mentor_requests.destroy_all
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    assert_equal 2, user.max_connections_limit
    assert_not_equal UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY, user.program_notification_setting

    put :update_settings, xhr: true, params: { :user => {:max_connections_limit => 0, mentoring_mode: User::MentoringMode::ONE_TIME, :program_notification_setting => UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY}, :id => users(:f_mentor).id}
    assert_response :success
    assert_equal 2, user.reload.max_connections_limit
    assert assigns(:notify_user_if_unavailable)
    assert_false assigns(:is_connection_limit_zero)
    assert_false assigns(:is_meeting_limit_zero)
    assert_equal [], assigns(:error_message)
    assert_nil assigns(:settings_error_case)
    user.reload
    assert_equal User::MentoringMode::ONE_TIME, user.mentoring_mode
    assert_equal UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY, user.program_notification_setting
  end

  def test_update_setting_for_mentor_with_connection_limit_zero
    current_user_is :f_mentor
    user = users(:f_mentor)
    user.received_meeting_requests.destroy_all
    user.groups.destroy_all
    user.update_attributes!(mentoring_mode: User::MentoringMode::ONE_TIME)
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    assert_not_equal UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY, user.program_notification_setting

    put :update_settings, xhr: true, params: { :user => {:max_connections_limit => 0, mentoring_mode: User::MentoringMode::ONGOING}, :id => users(:f_mentor).id}
    assert_response :success

    assert assigns(:notify_user_if_unavailable)
    assert assigns(:is_connection_limit_zero)
    assert_false assigns(:is_meeting_limit_zero)
  end

  def test_update_setting_for_mentor_with_meeting_limit_zero
    current_user_is :f_mentor
    user = users(:f_mentor)
    user.received_mentor_requests.destroy_all
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    user.user_setting.update_attributes!(max_meeting_slots: 0)

    put :update_settings, xhr: true, params: { :user => {mentoring_mode: User::MentoringMode::ONE_TIME}, :id => users(:f_mentor).id}
    assert_response :success

    assert assigns(:notify_user_if_unavailable)
    assert_false assigns(:is_connection_limit_zero)
    assert assigns(:is_meeting_limit_zero)
  end

  def test_update_setting_for_mentor_without_meeting_limit
    current_user_is :f_mentor
    user = users(:f_mentor)
    user.received_mentor_requests.destroy_all
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    user.user_setting.destroy

    put :update_settings, xhr: true, params: { :user => {mentoring_mode: User::MentoringMode::ONE_TIME}, :id => users(:f_mentor).id}
    assert_response :success

    assert assigns(:notify_user_if_unavailable)
    assert_false assigns(:is_connection_limit_zero)
    assert assigns(:is_meeting_limit_zero)
  end

  def test_update_setting_for_mentor_mode_change_disabled
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    assert_equal 2, user.max_connections_limit

    put :update_settings, xhr: true, params: { :user => {:max_connections_limit => 4, mentoring_mode: User::MentoringMode::ONE_TIME}, :id => users(:f_mentor).id}
    assert_response :success
    assert_equal User::MentoringMode::ONE_TIME_AND_ONGOING, user.reload.mentoring_mode
    assert_equal 4, user.reload.max_connections_limit
    assert_nil assigns(:notify_user_if_unavailable)
    assert_nil assigns(:is_connection_limit_zero)
    assert_nil assigns(:is_meeting_limit_zero)
  end

  def test_update_mode_setting_for_mentor_with_mentor_request
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    user = program.mentor_requests.first.mentor
    assert_equal user.mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING
    current_user_is user
    put :update_settings, xhr: true, params: { :user => {:max_connections_limit => 40, mentoring_mode: User::MentoringMode::ONE_TIME}, :id => user.id}
    assert assigns(:settings_error_case)
    assert_equal ["You already have pending mentoring request(s), Kindly reply to those first and then you can change the mentoring mode."], assigns(:error_message)
    assert_equal User::MentoringMode::ONE_TIME_AND_ONGOING, user.reload.mentoring_mode
    assert_equal user.max_connections_limit, 2
  end

  def test_update_mode_setting_for_mentor_with_meeting_request
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    user = program.meeting_requests.first.mentor
    current_user_is user
    put :update_settings, xhr: true, params: { :user => {:max_connections_limit => 4, mentoring_mode: User::MentoringMode::ONGOING}, :id => user.id}
    assert assigns(:settings_error_case)
    assert_equal ["You already have pending meeting request(s), Kindly reply to those first and then you can change the mentoring mode."], assigns(:error_message)
    assert_equal user.reload.mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING
    assert_equal user.max_connections_limit, 2
  end

  def test_negative_max_connections_limit
    current_user_is :f_mentor
    user = users(:f_mentor)
    assert_equal 2, user.max_connections_limit

    put :update_settings, xhr: true, params: { :user => {:max_connections_limit => -5}, :id => users(:f_mentor).id}
    assert_response :success
    assert assigns(:settings_error_case)
    assert_not_equal -5, user.reload.max_connections_limit
    assert_equal 2, user.max_connections_limit
    assert_equal ["The mentoring connection limit cannot be negative"], assigns(:error_message)
  end

  def test_negative_max_connections_limit_first_visit
    current_user_is :f_mentor
    post :update, params: { :id => users(:f_mentor).id, :first_visit => 'mentor', :section => MembersController::EditSection::SETTINGS, :user => {:max_connections_limit => -5}}
    assert_equal "The mentoring connection limit cannot be negative", flash[:error]
  end

  def test_update_mode_setting_for_mentor_with_mentor_offer
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    offer = create_mentor_offer(:mentor => user, :group => groups(:mygroup))


    assert_equal user.mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING
    put :update_settings, xhr: true, params: { :user => {:max_connections_limit => 40, mentoring_mode: User::MentoringMode::ONE_TIME}, :id => user.id}
    assert assigns(:settings_error_case)
    assert_equal ["You already have pending mentoring request(s) and mentoring offer(s), Kindly reply to those first and then you can change the mentoring mode."], assigns(:error_message)
    assert_equal User::MentoringMode::ONE_TIME_AND_ONGOING, user.reload.mentoring_mode
    assert_equal user.max_connections_limit, 10
  end

  def test_update_mode_setting_for_mentor_with_mentor_offer_and_mentor_request
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    user = program.mentor_requests.first.mentor
    assert_equal user.mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING
    User.update_all(max_connections_limit: 20)
    current_user_is user
    offer = create_mentor_offer(:mentor => user, :group => groups(:mygroup))

    put :update_settings, xhr: true, params: { :user => {:max_connections_limit => 100, mentoring_mode: User::MentoringMode::ONE_TIME}, :id => user.id}
    assert assigns(:settings_error_case)
    assert_equal ["You already have pending mentoring request(s) and mentoring offer(s), Kindly reply to those first and then you can change the mentoring mode."], assigns(:error_message)
    assert_equal User::MentoringMode::ONE_TIME_AND_ONGOING, user.reload.mentoring_mode
    assert (user.max_connections_limit != 100)
  end

  def test_profile_section_hidden
    current_user_is :f_admin
    mentor_student = users(:f_mentor_student)
    assert mentor_student.is_mentor_and_student?
    more_info_section = programs(:org_primary).sections.readonly(false).find_by(title: "More Information")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).never
    get :edit, params: { :id => mentor_student.member.id}
    assert_response :success
    assert assigns(:profile_sections)
    assert assigns(:program_custom_term)
    assert_template 'edit'
    assert_select 'html'
    assert_equal mentor_student, assigns(:profile_user)

    assert_select "div#collapsible_section_content_#{sections(:sections_3).id}" do
      assert_no_select "form.form-horizontal" do
        assert_no_select ".question", :count => sections(:sections_3).profile_questions.size
        assert_no_select 'input[type=?][value=?]', 'submit', "Save"
      end
    end

    assert_select "div#collapsible_section_content_#{sections(:section_albers).id}" do
      assert_no_select "form.form-horizontal" do
        assert_no_select ".question", :count => more_info_section.profile_questions.size
        assert_no_select 'input[type=?][value=?]', 'submit', "Save"
      end
    end

    assert_select "div#general_profile" do
      assert_select ".question", :count => 3 # Email, Location and Phone
    end

    assert_equal MembersController::EditSection::GENERAL, assigns(:section)
  end

  def test_edit_profile_sections_ordering
    mentor = users(:f_mentor)
    program = mentor.program
    mentor_sections = program.profile_questions_for([RoleConstants::MENTOR_NAME]).collect(&:section).reject(&:default_field?).uniq.sort_by(&:position)
    section = mentor_sections[0]
    section_position = section.position
    initial_sections_count = mentor_sections.size

    # creating a new section and setting its position as that of the current first non-default section
    new_section = Section.create!(organization: program.organization, title: "New Mentor Section", position: section_position)
    new_question = create_question(program: program, role_names: [RoleConstants::MENTOR_NAME])
    new_question.update_attribute(:section_id, new_section.id)
    section.update_attribute(:position, program.organization.sections.size)

    current_user_is mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EDIT_PROFILE, context_place: nil).once
    get :edit, params: { id: mentor.member_id}
    assert_response :success
    assert_equal "New Mentor Section", assigns(:profile_sections)[0].title
    assert_equal section.title, assigns(:profile_sections)[-1].title
    assert_equal initial_sections_count + 1, assigns(:profile_sections).size
  end

  def test_fill_section_profile_detail
    current_user_is :f_mentor
    get :fill_section_profile_detail, xhr: true, params: { :id => members(:f_mentor).id, :section_id => sections(:sections_3).id,:formats => :js}
    assert_response :success
    assert_false assigns(:is_admin_view)
    assert assigns(:profile_questions)
    assert assigns(:section_for).present?
    assert_equal members(:f_mentor).profile_answers.group_by(&:profile_question_id).count, assigns(:all_answers).count
  end

  def test_fill_section_profile_detail_show_linked_in_link
    current_user_is :f_mentor
    get :fill_section_profile_detail, xhr: true, params: { :id => members(:f_mentor).id, :section_id => sections(:sections_2).id,:formats => :js}
    assert_match "Click here to import your experience from", response.body
  end

  def test_fill_section_profile_detail_dont_show_linked_in_link
    linked_in_link_not_required_setup
    prof_q = ProfileQuestion.create!(:organization => programs(:org_anna_univ), :question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?", :section => sections(:sections_5))
    mentor_question = create_role_question(:program => programs(:ceg), :role_names => [RoleConstants::MENTOR_NAME], :profile_question => prof_q)

    current_user_is :f_mentor_ceg

    get :fill_section_profile_detail, xhr: true, params: { :id => members(:f_mentor_ceg).id, :section_id => sections(:sections_5).id,:formats => :js}
    assert_no_match(/Click here to import your experience from/, response.body)
  end

  def test_current_and_next_month_session_slots
    current_user_is :f_admin
    program = programs(:albers)
    assert_false program.calendar_enabled?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never

    get :show, params: { id: members(:f_mentor).id, tab: MembersController::ShowTabs::PROFILE}
    assert_response :success
    assert_nil assigns(:current_and_next_month_session_slots)
  end

  def test_current_and_next_month_session_slots_with_user_not_configured_to_set_availability
    current_user_is :f_admin
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    User.any_instance.stubs(:opting_for_one_time_mentoring?).returns(true)
    User.any_instance.stubs(:ask_to_set_availability?).returns(false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never

    get :show, params: { id: members(:f_mentor).id, tab: MembersController::ShowTabs::PROFILE}
    assert_response :success
    assert_nil assigns(:current_and_next_month_session_slots)
  end

  def test_suspended_flash_message_in_case_of_standalone_org
    o = programs(:org_foster)
    assert o.standalone?
    current_program_is :foster
    current_user_is :foster_admin

    member = members(:foster_mentor1)
    member.suspend!(members(:foster_admin), "Suspension Reason")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never

    get :show, params: { id: member.id}
    assert_response :success
    assert_match "#{member.name}'s membership has been suspended and their access has been revoked from all the programs they were part of.", flash[:error]
    assert_match(/Please .*click here.* to reactivate the user's profile in #{member.organization.name}./, flash[:error])
  end

  def test_current_and_next_month_session_slots_with_no_available_hours
    current_user_is :f_admin
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    User.any_instance.stubs(:opting_for_one_time_mentoring?).returns(true)
    User.any_instance.stubs(:ask_to_set_availability?).returns(true)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never

    get :show, params: { id: members(:f_mentor).id, tab: MembersController::ShowTabs::PROFILE}
    assert_response :success
    assert_equal 0, assigns(:current_and_next_month_session_slots)
  end

  def test_current_and_next_month_session_slots_with_calender_feature
    mock_now(Time.now)
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    Program.any_instance.stubs(:get_allowed_advance_slot_booking_time).returns(5)
    User.any_instance.stubs(:opting_for_one_time_mentoring?).returns(true)
    User.any_instance.stubs(:ask_to_set_availability?).returns(true)
    Member.any_instance.expects(:available_slots).with(program.reload, Time.now.utc + 5.hours, (Time.now.utc + 5.hours).next_month.end_of_month).returns(5).once

    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).never
    get :show, params: { id: members(:f_mentor).id, tab: MembersController::ShowTabs::PROFILE}
    assert_response :success
    assert_equal 5, assigns(:current_and_next_month_session_slots)
  end

  def test_destroy_other_sessions
    current_user_is :f_student
    member = members(:f_student)
    mobile_devices = []
    mobile_devices << member.set_mobile_access_tokens_v2!("Iphone", "qwerty", MobileDevice::Platform::IOS)
    mobile_devices << member.set_mobile_access_tokens_v2!("HTC", "asdfgh", MobileDevice::Platform::IOS)
    assert_equal_unordered member.mobile_devices.pluck(:id), mobile_devices.collect(&:id)
    member.remember_me
    ActionController::TestRequest.any_instance.stubs(:session_options).returns({id: "session-id"})
    ["abcde12345", request.session_options[:id]].each do |session_id|
      ActiveRecord::SessionStore::Session.create!(:session_id => session_id, :data => {"member_id" => member.id})
    end
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).count, 2

    put :update_settings, xhr: true, params: { :sign_out_of_all_other_sessions => true, :id => users(:f_student).id}
    assert_response :success
    member.reload
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).count, 1
    assert_equal_unordered member.mobile_devices.pluck(:id), []
    assert_nil member.remember_token
  end

  def test_track_activity_for_ei
    current_user_is :f_student
    fetch_role(:albers, :student).remove_permission('view_mentors')
    create_mentor_offer(mentor: users(:f_mentor), student: users(:f_student))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {:context_place => nil, context_object: users(:f_mentor).id}).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_SELF_PROFILE).never
    get :show, params: { :id => members(:f_mentor).id}
  end

  def test_access_denied_try_to_see_pdf_profile_others
    current_user_is :f_student
    assert_permission_denied do
      get :show, params: { :id => members(:student_3).id, :format => "pdf"}
    end
  end

  def test_cookies_for_edit_first_visit
    user = users(:f_student)

    @request.cookies[:first_time_sections_filled] = ActiveSupport::JSON.encode(user.id => { user.role_ids => [3, 4] } )
    current_user_is user
    get :edit, params: { id: user.member_id, first_visit: true }
    assert_equal_hash( { 1 => "Basic Information", 2 => "Work and Education", 3 => "Mentoring Profile", sections(:section_albers_students).id => "More Information Students" }, assigns(:all_profile_section_titles_hash))
    assert_equal [1, 2, 3, sections(:section_albers_students).id], assigns(:all_profile_section_ids)
    assert_equal [3, 4], assigns(:sections_filled)
  end

  def test_set_cookies_for_edit_first_visit
    current_user_is :f_student
    @request.cookies[:first_time_sections_filled] = ActiveSupport::JSON.encode({users(:f_student).id => {users(:f_student).role_ids => ["3","4"]}})
    post :update_answers, params: {:id => members(:f_student), :first_visit => true, section_id: 2}
    assert_equal ["3", "4", "2"], ActiveSupport::JSON.decode(cookies[:first_time_sections_filled])[users(:f_student).id.to_s][users(:f_student).role_ids.to_s]
  end

  def test_set_cookies_for_edit_first_visit_existing_cookies
    current_user_is :f_student
    @request.cookies[:first_time_sections_filled] = {}
    post :update_answers, params: {:id => members(:f_student), :first_visit => true, section_id: 2}
    assert_equal ["2"], ActiveSupport::JSON.decode(cookies[:first_time_sections_filled])[users(:f_student).id.to_s][users(:f_student).role_ids.to_s]
    assert_equal "2", assigns(:section_id)
  end

  def test_set_cookies_for_edit_first_visit_existing_cookies_with_other_role_id
    current_user_is :f_student
    @request.cookies[:first_time_sections_filled] = ActiveSupport::JSON.encode({users(:f_student).id => {users(:f_mentor).role_ids => ["3","4"]}})
    post :update_answers, params: {:id => members(:f_student), :first_visit => true, section_id: 2}
    assert_equal ["2"], ActiveSupport::JSON.decode(cookies[:first_time_sections_filled])[users(:f_student).id.to_s][users(:f_student).role_ids.to_s]
    assert_equal "2", assigns(:section_id)
    assert_nil ActiveSupport::JSON.decode(cookies[:first_time_sections_filled])[users(:f_student).id.to_s][users(:f_mentor).role_ids.to_s]
  end

  private

  def assert_section_expanded(section_name)
    assert_select 'div.ibox' do
      assert_select '.ibox-title', :text => /#{section_name}/
    end
  end

  def linked_in_link_not_required_setup
    profile_questions(:profile_questions_23).destroy
    profile_questions(:profile_questions_24).destroy
  end

  def setup_conditional_question_to_test(member, choices, text_to_match)
    conditional_question = create_question(:organization => programs(:org_primary), :program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :question_text => "a conditional question", :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :available_for => RoleQuestion::AVAILABLE_FOR::BOTH, question_choices: choices)
    dependent_question = create_question(:organization => programs(:org_primary), :program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :question_text => "dependent question", :question_type => ProfileQuestion::Type::TEXT, :available_for => RoleQuestion::AVAILABLE_FOR::BOTH)

    dependent_question.conditional_question_id = conditional_question.id
    dependent_question.save!

    question_choice_id = QuestionChoice.find_by(text: text_to_match, ref_obj_id: conditional_question.id, ref_obj_type: ProfileQuestion.name).id
    dependent_question.conditional_match_choices.create!(question_choice_id: question_choice_id)

    pa1 = ProfileAnswer.create!(:profile_question => dependent_question, :ref_obj => member, :answer_text => 'Conditional answer')
    return conditional_question
  end
end
