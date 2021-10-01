require_relative './../test_helper.rb'

class MentorOffersControllerTest < ActionController::TestCase
  def test_feature_needed
    current_user_is :mentor_6

    src = EngagementIndex::Src::SendRequestOrOffers::USER_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_OFFER, {:context_place => src}).never
    assert_permission_denied do
      post :create, params: { src: src}
    end
  end

  def test_feature_needed_for_new
    current_user_is :mentor_6
    assert_permission_denied do
      get :new, xhr: true
    end
  end

  def test_new_add_as_mentee
    current_user_is :f_mentor

    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    program.update_attribute(:mentor_offer_needs_acceptance, false)

    get :new, xhr: true, params: { student_id: users(:f_student).id}
    assert_equal assigns(:student), users(:f_student)
    assert_equal assigns(:mentor), users(:f_mentor)
    assert_equal assigns(:existing_connections_of_mentor), [groups(:mygroup)]
    assert assigns(:can_add_to_existing_group)
    assert_select "div.modal-header" do
      assert_select "h4", "Offer mentoring to student example"
    end
    assert_select "div.modal-body" do
      assert_select "label", "Type an optional message to student example:"
    end
  end

  def test_new_mentor_offer
    current_user_is :f_mentor

    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    program.update_attribute(:mentor_offer_needs_acceptance, true)

    get :new, xhr: true, params: { student_id: users(:f_student).id}
    assert_equal assigns(:student), users(:f_student)
    assert_equal assigns(:mentor), users(:f_mentor)
    assert_equal assigns(:existing_connections_of_mentor), [groups(:mygroup)]
    assert assigns(:can_add_to_existing_group)
    assert_select "div.modal-header" do
      assert_select "h4", "Offer mentoring to student example"
    end
    assert_select "div.modal-body" do
      assert_select "label", "Type an optional message to student example. Your offer would be sent to student example for acceptance."
    end
  end

  def test_new_mentor_offer_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_mentor

    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_raise Authorization::PermissionDenied do
      get :new, xhr: true, params: { student_id: users(:f_student).id}
    end
  end

  def test_add_as_mentee_for_program_with_disabled_ongoing_mentoring
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    assert users(:mentor_6).can_offer_mentoring?

    current_user_is :mentor_6

    src = EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_OFFER, {:context_place => src}).never
    assert_raise Authorization::PermissionDenied do
      post :create, params: { src: src, :student_id => users(:student_6).id}
    end
  end

  def test_check_program_has_ongoing_mentoring_enabled
    current_user_is :f_mentor
    # changing engagement type of program to career and ongoing based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)

    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    program.update_attribute(:mentor_offer_needs_acceptance, true)

    get :new, xhr: true, params: { student_id: users(:f_student).id}
    assert_response :success
    assert assigns(:is_ongoing_mentoring_enabled)
  end

  def test_mentor_offers_listing_for_program_with_disabled_ongoing_mentoring
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    program.update_attribute(:mentor_offer_needs_acceptance, true)

    current_user_is :student_6

    assert_permission_denied do
      get :index, xhr: true
    end
    assert_false assigns(:is_ongoing_mentoring_enabled)
  end

  def test_mentor_offers_listing_not_accessible_for_non_mentor_student_admin
    current_user_is :f_user
    enable_mentor_offer_listing

    assert_permission_denied do
      get :index
    end
  end

  def test_mentor_offers_listing_not_accessible_when_mentor_offer_disabled
    current_user_is :f_mentor
    program = programs(:albers)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    assert_false program.mentor_offer_enabled?
    assert program.mentor_offer_needs_acceptance?

    assert_permission_denied do
      get :index
    end
  end

  def test_mentor_offers_listing_not_accessible_when_mentor_offer_acceptance_not_needed
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert program.mentor_offer_enabled?
    assert_false program.mentor_offer_needs_acceptance?

    assert_permission_denied do
      get :index
    end
  end

  def test_mentor_offers_listing_success_for_mentor
    current_user_is :f_mentor
    enable_mentor_offer_listing

    get :index
    assert_response :success
    assert_equal 'mentor_offer', assigns(:mentor_offer_partial)
    assert_false assigns(:received_offers_view)
    assert_equal "Mentoring Offers Initiated", assigns(:title)
    filter_params = assigns(:filter_params)
    assert_equal 1, filter_params[:page]
    assert_equal 'pending', filter_params[:status]
    assert_equal users(:f_mentor).id, filter_params[:user_id]
    assert_equal programs(:albers).id, filter_params[:program_id]
    assert_equal AbstractRequest::Filter::BY_ME, filter_params[:filter_field]
  end

  def test_mentor_offers_listing_success_for_student
    current_user_is :f_student
    enable_mentor_offer_listing

    get :index
    assert_response :success
    assert_equal 'mentor_offer', assigns(:mentor_offer_partial)
    assert assigns(:received_offers_view)
    assert_equal "Received Mentoring Offers", assigns(:title)
    filter_params = assigns(:filter_params)
    assert_equal 1, filter_params[:page]
    assert_equal 'pending', filter_params[:status]
    assert_equal users(:f_student).id, filter_params[:user_id]
    assert_equal programs(:albers).id, filter_params[:program_id]
    assert_equal AbstractRequest::Filter::TO_ME, filter_params[:filter_field]
  end

  def test_mentor_offers_listing_success_for_admin
    current_user_is :f_admin
    enable_mentor_offer_listing

    get :index, params: { sort_field: 'id', sort_order: 'asc'}
    assert_response :success
    assert_equal programs(:albers).mentor_offers.order(id: 'asc').pluck(:id).first(10).sort, assigns(:mentor_offers).pluck(:id).sort
    assert_equal 'mentor_offer_for_admin', assigns(:mentor_offer_partial)
    assert_false assigns(:received_offers_view)
    assert_equal "Mentoring Offers", assigns(:title)
    filter_params = assigns(:filter_params)
    assert_equal 'id', filter_params[:sort_field]
    assert_equal 'asc', filter_params[:sort_order]
    assert_equal 1, filter_params[:page]
    assert_equal 'pending', filter_params[:status]
    assert_equal users(:f_admin).id, filter_params[:user_id]
    assert_equal programs(:albers).id, filter_params[:program_id]
    assert_equal AbstractRequest::Filter::ALL, filter_params[:filter_field]
  end

  def test_mentor_offers_listing_success_for_mentor_student
    current_user_is :f_mentor_student
    enable_mentor_offer_listing

    get :index
    assert_response :success
    assert_equal 'mentor_offer', assigns(:mentor_offer_partial)
    assert assigns(:received_offers_view)
    assert_equal "Received Mentoring Offers", assigns(:title)
    filter_params = assigns(:filter_params)
    assert_equal 1, filter_params[:page]
    assert_equal 'pending', filter_params[:status]
    assert_equal users(:f_mentor_student).id, filter_params[:user_id]
    assert_equal programs(:albers).id, filter_params[:program_id]
    assert_equal AbstractRequest::Filter::TO_ME, filter_params[:filter_field]
  end

  def test_mentor_offers_listing_wrong_filter_field_by_mentor_1
    current_user_is :f_mentor
    enable_mentor_offer_listing

    get :index, xhr: true, params: { filter: AbstractRequest::Filter::TO_ME}
    assert_redirected_to mentor_offers_path
  end

  def test_mentor_offers_listing_wrong_filter_field_by_mentor_2
    current_user_is :f_mentor
    enable_mentor_offer_listing

    get :index, xhr: true, params: { filter: AbstractRequest::Filter::ALL}
    assert_redirected_to mentor_offers_path
  end

  def test_mentor_offers_listing_wrong_filter_field_by_student_1
    current_user_is :f_student
    enable_mentor_offer_listing

    get :index, xhr: true, params: { filter: AbstractRequest::Filter::BY_ME}
    assert_redirected_to mentor_offers_path
  end

  def test_mentor_offers_listing_wrong_filter_field_by_student_2
    current_user_is :f_student
    enable_mentor_offer_listing

    get :index, xhr: true, params: { filter: AbstractRequest::Filter::ALL}
    assert_redirected_to mentor_offers_path
  end

  def test_mentor_offers_listing_wrong_filter_field_by_admin_1
    current_user_is :f_admin
    enable_mentor_offer_listing

    get :index, xhr: true, params: { filter: AbstractRequest::Filter::TO_ME}
    assert_redirected_to mentor_offers_path
  end

  def test_mentor_offers_listing_wrong_filter_field_by_admin_2
    current_user_is :f_admin
    enable_mentor_offer_listing

    get :index, xhr: true, params: { filter: AbstractRequest::Filter::BY_ME}
    assert_redirected_to mentor_offers_path
  end

  def test_mentor_offers_invalid_filter_field_by_mentor
    current_user_is :f_mentor
    enable_mentor_offer_listing

    get :index, xhr: true, params: { filter: "random_string", status: "accepted"}
    assert_response :success
    filter_params = assigns(:filter_params)
    assert_equal 'accepted', filter_params[:status]
    assert_equal AbstractRequest::Filter::BY_ME, filter_params[:filter_field]
  end

  def test_mentor_offers_invalid_filter_field_by_student
    current_user_is :f_student
    enable_mentor_offer_listing

    get :index, xhr: true, params: { filter: "random_string", status: "rejected", page: 3}
    assert_response :success
    filter_params = assigns(:filter_params)
    assert_equal 'rejected', filter_params[:status]
    assert_equal 3, filter_params[:page]
    assert_equal AbstractRequest::Filter::TO_ME, filter_params[:filter_field]
  end

  def test_mentor_offers_invalid_filter_field_by_admin
    current_user_is :f_admin
    enable_mentor_offer_listing

    get :index, xhr: true, params: { filter: "random_string", page: "dff"}
    assert_response :success
    filter_params = assigns(:filter_params)
    assert_equal 'pending', filter_params[:status]
    assert_equal 1, filter_params[:page]
    assert_equal AbstractRequest::Filter::ALL, filter_params[:filter_field]
  end

  def test_mentor_offers_invalid_filter_field_by_mentor_student
    current_user_is :f_mentor_student
    enable_mentor_offer_listing

    get :index, xhr: true, params: { filter: "random_string", status: "pending", page: -2}
    assert_response :success
    filter_params = assigns(:filter_params)
    assert_equal 'pending', filter_params[:status]
    assert_equal 1, filter_params[:page]
    assert_equal AbstractRequest::Filter::TO_ME, filter_params[:filter_field]
  end

  def test_mentor_offers_manage_not_accessible_for_non_mentor_student_admin
    current_user_is :f_user
    enable_mentor_offer_listing

    assert_permission_denied do
      get :manage
    end
  end

  def test_mentor_offers_manage_for_program_with_disabled_ongoing_mentoring
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    program.update_attribute(:mentor_offer_needs_acceptance, true)

    current_user_is :student_6

    assert_permission_denied do
      get :manage, xhr: true
    end
    assert_false assigns(:is_ongoing_mentoring_enabled)
  end

  def test_mentor_offers_manage_not_accessible_when_mentor_offer_disabled
    current_user_is :f_admin
    program = programs(:albers)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    assert_false program.mentor_offer_enabled?
    assert program.mentor_offer_needs_acceptance?

    assert_permission_denied do
      get :manage
    end
  end

  def test_mentor_offers_manage_not_accessible_when_mentor_offer_acceptance_not_needed
    current_user_is :f_admin
    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert program.mentor_offer_enabled?
    assert_false program.mentor_offer_needs_acceptance?

    assert_permission_denied do
      get :manage
    end
  end

  def test_mentor_offers_manage_invalid_filter_field_by_student
    current_user_is :f_admin
    enable_mentor_offer_listing

    get :manage, xhr: true, params: { status: "rejected", page: 3}
    assert_response :success
    filter_params = assigns(:filter_params)
    assert_equal 'rejected', filter_params[:status]
    assert_equal 3, filter_params[:page]
  end

  def test_mentor_offers_manage_success
    current_user_is :f_admin
    enable_mentor_offer_listing

    get :manage
    assert_response :success
    assert_equal 'mentor_offer_for_admin', assigns(:mentor_offer_partial)
    assert_nil assigns(:received_offers_view)
    assert_equal "Mentoring Offers", assigns(:title)
    filter_params = assigns(:filter_params)
    assert_equal 1, filter_params[:page]
    assert_equal 'pending', filter_params[:status]
    assert_equal users(:f_admin).id, filter_params[:user_id]
    assert_equal programs(:albers).id, filter_params[:program_id]
    assert_equal AbstractRequest::Filter::ALL, filter_params[:filter_field]
  end

  def test_mentor_offers_manage_invalid_filter_field_by_mentor_student
    current_user_is :f_admin
    enable_mentor_offer_listing

    get :manage, xhr: true, params: { status: "pending", page: -2}
    assert_response :success
    filter_params = assigns(:filter_params)
    assert_equal 'pending', filter_params[:status]
    assert_equal 1, filter_params[:page]
  end

  def test_mentor_offers_manage_invalid_filter_field_by_admin
    current_user_is :f_admin
    enable_mentor_offer_listing

    get :manage, xhr: true, params: { page: "dff"}
    assert_response :success
    filter_params = assigns(:filter_params)
    assert_equal 'pending', filter_params[:status]
    assert_equal 1, filter_params[:page]
  end

  def test_mentor_offers_manage_success_with_sorting
    current_user_is :f_admin
    enable_mentor_offer_listing

    get :manage, params: { sort_field: 'id', sort_order: 'asc'}
    assert_response :success
    assert_equal programs(:albers).mentor_offers.pending.order(id: 'asc').pluck(:id).first(10).sort, assigns(:mentor_offers).pluck(:id)
    assert_equal 'mentor_offer_for_admin', assigns(:mentor_offer_partial)
    assert_nil assigns(:received_offers_view)
    assert_equal "Mentoring Offers", assigns(:title)
    filter_params = assigns(:filter_params)
    assert_equal 'id', filter_params[:sort_field]
    assert_equal 'asc', filter_params[:sort_order]
    assert_equal 1, filter_params[:page]
    assert_equal 'pending', filter_params[:status]
    assert_equal users(:f_admin).id, filter_params[:user_id]
    assert_equal programs(:albers).id, filter_params[:program_id] 
    assert_equal AbstractRequest::Filter::ALL, filter_params[:filter_field]
  end

  def test_mentor_offers_manage_success_with_sorting_rejected_status
    current_user_is :f_admin
    enable_mentor_offer_listing

    get :manage, params: { sort_field: 'id', sort_order: 'asc', status: "rejected"}
    assert_response :success
    assert_equal programs(:albers).mentor_offers.rejected.order(id: 'asc').pluck(:id).first(10).sort, assigns(:mentor_offers).pluck(:id)
    assert_equal 'mentor_offer_for_admin', assigns(:mentor_offer_partial)
    assert_nil assigns(:received_offers_view)
    assert_equal "Mentoring Offers", assigns(:title)
    filter_params = assigns(:filter_params)
    assert_equal 'id', filter_params[:sort_field]
    assert_equal 'asc', filter_params[:sort_order]
    assert_equal 1, filter_params[:page]
    assert_equal 'rejected', filter_params[:status]
    assert_equal users(:f_admin).id, filter_params[:user_id]
    assert_equal programs(:albers).id, filter_params[:program_id] 
    assert_equal AbstractRequest::Filter::ALL, filter_params[:filter_field]
  end

  def test_mentor_adds_mentee_to_new_group
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, false)
    assert users(:mentor_6).can_offer_mentoring?

    current_user_is :mentor_6
    src = EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_OFFER, {:context_place => src}).once
    assert_emails 1 do
      assert_difference 'RecentActivity.count' do
        assert_difference 'Group.count' do
          post :create, params: { src: src, :student_id => users(:student_6).id}
        end
      end
    end

    group = Group.last
    assert group.has_mentor?(users(:mentor_6))
    assert group.has_mentee?(users(:student_6))
  end

  def test_mentor_adds_mentee_to_existing_group
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, false)
    group = groups(:mygroup)
    mentor = group.mentors.first
    assert !group.has_mentee?(users(:f_student))
    assert mentor.reload.can_offer_mentoring?

    current_user_is mentor
    src = EngagementIndex::Src::SendRequestOrOffers::HOVERCARD
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_OFFER, {:context_place => src}).once
    assert_pending_notifications do
      assert_emails do
        assert_difference 'RecentActivity.count' do
          assert_no_difference 'Group.count' do
            post :create, params: { src: src, :student_id => users(:f_student).id, :group_id => group.id}
          end
        end
      end
    end

    assert group.reload.has_mentee?(users(:f_student))
  end

  def test_mentor_offer_creation
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    assert !group.has_mentee?(users(:f_student))
    assert mentor.reload.can_offer_mentoring?

    current_user_is mentor
    src = EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_OFFER, {:context_place => src}).once
    assert_emails 1 do
      assert_difference 'RecentActivity.count' do
        assert_no_difference 'Group.count' do
          post :create, params: { src: src, :student_id => users(:f_student).id, :group_id => group.id}
        end
      end
    end

    assert_equal MentorOffer.last.student, users(:f_student)
  end

  def test_update_invalid_id
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)

    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).never
    assert_nothing_raised do
      put :update, params: { id: 0, mentor_offer: { status: MentorOffer::Status::ACCEPTED }}
    end
    assert_redirected_to mentor_offers_path
    assert_equal "The offer you are trying to access does not exist.", flash[:error]
  end

  def test_update_non_pending_offer
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    mentor_offer = create_mentor_offer
    mentor_offer.update_column(:status, MentorOffer::Status::CLOSED)

    current_user_is mentor_offer.student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).never
    assert_nothing_raised do
      put :update, params: { id: mentor_offer.id, mentor_offer: { status: MentorOffer::Status::ACCEPTED }}
    end
    assert_redirected_to mentor_offers_path
    assert_equal "The offer has already been closed.", flash[:error]
  end

  def test_mentor_offer_acceptance_new_group
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?

    offer = create_mentor_offer(:mentor => mentor, :student => mentee)

    current_user_is mentee
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).once
    assert_emails 1 do
      assert_difference 'RecentActivity.count' do
        assert_difference 'Group.count' do
          put :update, params: { :id => offer.id, :mentor_offer => {:status => MentorOffer::Status::ACCEPTED}}
        end
      end
    end

    assert Group.last.has_mentee?(mentee)
  end

  def test_mentor_offer_acceptance_existing_group
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?

    offer = create_mentor_offer(:mentor => mentor, :student => mentee, :group => group)

    current_user_is mentee
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).once
    assert_pending_notifications do
      assert_emails do
        assert_difference 'RecentActivity.count' do
          assert_no_difference 'Group.count' do
            put :update, params: { :id => offer.id, :mentor_offer => {:status => MentorOffer::Status::ACCEPTED}}
          end
        end
      end
    end

    notif = PendingNotification.last
    assert_equal notif.action_type, RecentActivityConstants::Type::MENTORING_OFFER_ACCEPTANCE
    assert_equal notif.ref_obj_creator.user, group.students.to_a.first

    assert group.reload.has_mentee?(mentee)
  end

  def test_mentor_offer_rejection
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?

    offer = create_mentor_offer(:mentor => mentor, :student => mentee)

    current_user_is mentee
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).never
    assert_emails 1 do
      assert_difference 'RecentActivity.count' do
        assert_no_difference 'Group.count' do
          put :update, params: { :id => offer.id, :mentor_offer => {:status => MentorOffer::Status::REJECTED, :response => "Test response"}}
        end
      end
    end
  end

  def test_mentor_offer_rejection_from_user_profile_page
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?

    offer = create_mentor_offer(:mentor => mentor, :student => mentee)

    current_user_is mentee
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).never
    assert_emails 1 do
      assert_difference 'RecentActivity.count' do
        assert_no_difference 'Group.count' do
          put :update, params: { :id => offer.id, :mentor_offer => {:status => MentorOffer::Status::REJECTED, :response => "Test response"}}
        end
      end
    end
  end

  def test_mentor_offer_rejection_from_user_listing_page
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?

    offer = create_mentor_offer(:mentor => mentor, :student => mentee)

    current_user_is mentee
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).never
    assert_emails 1 do
      assert_difference 'RecentActivity.count' do
        assert_no_difference 'Group.count' do
          put :update, params: { :id => offer.id, :mentor_offer => {:status => MentorOffer::Status::REJECTED, :response => "Test response"}}
        end
      end
    end
  end

  def test_close_mentor_offer
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    Timecop.freeze(Time.now) do
      admin = users(:f_admin)

      mentor_offers = []
      mentor_offers << create_mentor_offer
      mentor_offers << (mentor_offer = create_mentor_offer(mentor: users(:mentor_0), student: users(:student_0))); mentor_offer.update_column(:status, MentorOffer::Status::ACCEPTED); mentor_offer
      mentor_offers << (mentor_offer = create_mentor_offer(mentor: users(:mentor_1), student: users(:student_1))); mentor_offer.update_column(:status, MentorOffer::Status::REJECTED); mentor_offer
      mentor_offers << (mentor_offer = create_mentor_offer(mentor: users(:mentor_2), student: users(:student_2))); mentor_offer.update_column(:status, MentorOffer::Status::WITHDRAWN); mentor_offer
      mentor_offers << (mentor_offer = create_mentor_offer(mentor: users(:mentor_3), student: users(:student_3))); mentor_offer.update_column(:status, MentorOffer::Status::CLOSED); mentor_offer

      current_user_is admin
      @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).never
      assert_emails 1 do
        post :update_bulk_actions, xhr: true, params: { bulk_actions: { offer_status: MentorOffer::Status::CLOSED, mentor_offer_ids: mentor_offers.collect(&:id).join(" ") },
          mentor_offer: { response: "Sorry" }, sender: true
        }
      end

      assert_equal "The selected offer has been closed.", assigns(:notice)
      recently_closed_mentor_offer = mentor_offers[0].reload
      assert_equal "Sorry", recently_closed_mentor_offer.response
      assert_equal MentorOffer::Status::CLOSED, recently_closed_mentor_offer.status
      assert_equal MentorOffer::Status::ACCEPTED, mentor_offers[1].reload.status
      assert_equal MentorOffer::Status::REJECTED, mentor_offers[2].reload.status
      assert_equal MentorOffer::Status::WITHDRAWN, mentor_offers[3].reload.status
      assert_equal MentorOffer::Status::CLOSED, mentor_offers[4].reload.status
      assert_equal admin, recently_closed_mentor_offer.closed_by
      assert_equal Time.now.utc.to_s, recently_closed_mentor_offer.closed_at.utc.to_s
    end
  end

  def test_close_mentor_offer_only_by_admin
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?
    offer = create_mentor_offer(:mentor => mentor, :student => mentee, :group => group)

    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).never
    assert_permission_denied  do
      post :update_bulk_actions, xhr: true, params: { :bulk_actions => {:offer_status => MentorOffer::Status::CLOSED, :mentor_offer_ids => [offer.id]}, :mentor_offer => {:response => "Sorry"}, :sender => true}
    end
  end

  def test_withdraw_mentor_offer
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?
    offer = create_mentor_offer(:mentor => mentor, :student => mentee, :group => group)

    current_user_is :f_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).never
    assert_permission_denied do
      post :update, params: { :id => offer.id, :mentor_offer => {:status => MentorOffer::Status::WITHDRAWN }}
    end
  end

  def test_withdraw_mentor_offer_by_mentor
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?
    offer = create_mentor_offer(:mentor => mentor, :student => mentee, :group => group)

    current_user_is mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).never
    assert_emails 1 do
      post :update, params: { :id => offer.id, :mentor_offer => {:status => MentorOffer::Status::WITHDRAWN }}
    end
  end

  def test_flash_messages_for_create_update_maxlimit_allowed
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    assert !group.has_mentee?(users(:f_student))
    User.any_instance.expects(:can_mentor?).once.returns(false)
    current_user_is mentor
    src = EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_OFFER, {:context_place => src}).never
    post :create, params: { src: src, :student_id => users(:f_student).id, :group_id => group.id}
    assert_equal "You cannot offer mentoring as you have reached the mentoring connections limit. Please update your profile and then retry.", assigns(:error_flash)
  end

  def test_flash_messages_for_create_update_maxlimit_not_allowed
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.update_attributes(:connection_limit_permission => Program::ConnectionLimit::NONE)
    assert_false program.allow_mentor_update_maxlimit?

    group = groups(:mygroup)
    mentor = group.mentors.first
    assert !group.has_mentee?(users(:f_student))
    User.any_instance.expects(:can_mentor?).once.returns(false)
    current_user_is mentor

    src = EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_OFFER, {:context_place => src}).never
    post :create, params: { src: src, :student_id => users(:f_student).id, :group_id => group.id}
    assert_equal "You cannot offer mentoring as you have reached the mentoring connections limit.", assigns(:error_flash)
  end

  def test_flash_messages_for_create_connection_limit_as_mentee_reached
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    assert !group.has_mentee?(users(:f_student))
    User.any_instance.expects(:connection_limit_as_mentee_reached?).once.returns(true)
    current_user_is mentor
    src = EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_OFFER, {:context_place => src}).never
    post :create, params: { src: src, :student_id => users(:f_student).id, :group_id => group.id}
    assert_equal "You cannot offer mentoring as student example has reached the mentoring connection limit.", assigns(:error_flash)
  end

  def test_flash_messages_for_create_connection_limit_as_mentee_reached_no_acceptance_required
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, false)

    group = groups(:mygroup)
    mentor = group.mentors.first
    assert !group.has_mentee?(users(:f_student))
    User.any_instance.expects(:connection_limit_as_mentee_reached?).once.returns(true)
    current_user_is mentor
    src = EngagementIndex::Src::SendRequestOrOffers::USER_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MENTORING_OFFER, {:context_place => src}).never
    post :create, params: { src: src, :student_id => users(:f_student).id, :group_id => group.id}
    assert_equal "You cannot offer mentoring as student example has reached the mentoring connection limit.", assigns(:error_flash)
  end

  def test_flash_messages_for_update_connection_limit_as_mentee_reached
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?

    offer = create_mentor_offer(:mentor => mentor, :student => mentee, :group => group)
    User.any_instance.expects(:connection_limit_as_mentee_reached?).at_least_once.returns(true)
    current_user_is mentee
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).never
    put :update, params: { :id => offer.id, :mentor_offer => {:status => MentorOffer::Status::ACCEPTED}}
    assert_equal "You have reached the maximum mentoring connections limit.", flash[:error]
  end

  def test_accept_mentor_offer_when_it_can_be_accepted_based_on_mentors_limits
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    group = groups(:mygroup)
    mentor = group.mentors.first
    mentee = users(:f_student)
    assert !group.has_mentee?(mentee)
    assert mentor.reload.can_offer_mentoring?

    offer = create_mentor_offer(:mentor => mentor, :student => mentee, :group => group, :max_connection_limit => 2)
    current_user_is mentee
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MENTORING_OFFER).once
    put :update, params: { :id => offer.id, :mentor_offer => {:status => MentorOffer::Status::ACCEPTED}}
    assert_redirected_to group_path(group)
  end

  def test_bulk_csv_export_for_approver
    current_user_is :f_admin
    mentor_offer = create_mentor_offer(:mentor => users(:f_mentor), :group => groups(:mygroup))
    mentor_offer1 = create_mentor_offer(:mentor => users(:f_mentor_student), :group => groups(:mygroup))

    get :export, params: { :mentor_offer_ids => "#{mentor_offer.id},#{mentor_offer1.id}", :format => 'csv'}
    assert_response :success
  end

  def test_select_all_ids
    program = programs(:albers)
    enable_mentor_offer_listing
    program.reload.update_attribute(:allow_one_to_many_mentoring, true)

    mentor = users(:f_mentor)
    mentee = users(:f_student)

    mentor_offer = create_mentor_offer(mentor: mentor, student: mentee, program: program)
    reindex_documents(created: mentor_offer)

    current_user_is :f_admin
    get :select_all_ids, params: {filter_field: "all", status: "pending", page: 1, sort_field: "id", sort_order: "desc", user_id: mentor.id, program_id: program.id}
    assert_response :success

    output = JSON.parse(response.body)
    assert_equal output["mentor_offer_ids"], [mentor_offer.id.to_s]
    assert_equal output["sender_ids"], [mentor.id]
    assert_equal output["receiver_ids"], [mentee.id]
  end

  private

  def enable_mentor_offer_listing(program = nil)
    program ||= programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
  end
end
