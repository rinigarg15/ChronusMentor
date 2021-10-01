require_relative './../test_helper.rb'

class UsersControllerTest < ActionController::TestCase
  include MentoringSlotsHelper

  def test_new_from_other_program
    programs(:albers).update_attribute(:allow_track_admins_to_access_all_users, true)

    current_user_is :f_admin
    get :new_from_other_program, params: { items_per_page: 1_000 }
    assert_response :success
    assert_equal "1000", assigns(:listing_options)[:items_per_page]
    assert_equal_unordered members(:nwen_admin, :assistant, :moderated_admin, :moderated_mentor, :moderated_student, :no_mreq_admin, :no_mreq_mentor, :no_mreq_student).map(&:id) +
      5.times.map { |i| members("teacher_#{i}").id }, assigns(:members).map(&:id).map(&:to_i)
  end

  def test_new_from_other_program_with_program_filter
    programs(:albers).update_attribute(:allow_track_admins_to_access_all_users, true)

    current_user_is :f_admin
    get :new_from_other_program, params: { filter_program_id: programs(:moderated_program).id }
    assert_response :success
    assert_equal programs(:moderated_program).id, assigns(:listing_options)[:filters][:program_id]
    assert_nil assigns(:listing_options)[:filters][:role]
    assert_equal_unordered(
      programs(:moderated_program).all_users.map(&:member_id) - programs(:albers).all_users.map(&:member_id),
      assigns(:members).map(&:id).map(&:to_i)
    )
  end

  def test_new_from_other_program_with_program_and_role_filter
    programs(:albers).update_attribute(:allow_track_admins_to_access_all_users, true)
    mentor_role_id = [programs(:moderated_program).find_role(RoleConstants::MENTOR_NAME).id.to_s]

    current_user_is :f_admin
    get :new_from_other_program, params: { filter_program_id: programs(:moderated_program).id, filter_role: mentor_role_id }
    assert_response :success
    assert_equal programs(:moderated_program).id, assigns(:listing_options)[:filters][:program_id]
    assert_equal mentor_role_id, assigns(:listing_options)[:filters][:role]
    assert_equal_unordered(
      programs(:moderated_program).all_users.mentors.map(&:member_id) - programs(:albers).all_users.map(&:member_id),
      assigns(:members).map(&:id).map(&:to_i)
    )
  end

  def test_new_from_other_program_without_permission_to_allow_track_users
    current_user_is :f_admin

    assert_permission_denied do
      get :new_from_other_program
    end
  end

  def test_auth_for_new_from_other_program
    current_user_is :ram

    assert_permission_denied { get :new_from_other_program }
  end

  def test_auth_for_create_from_other_program
    current_user_is :ram

    assert_permission_denied { get :create_from_other_program }
  end

  def test_auth_for_bulk_confirmation_view
    current_user_is :ram

    assert_permission_denied { get :bulk_confirmation_view }
  end

  def test_standalone_auth_for_new_from_other_program
    current_user_is :foster_admin

    programs(:albers).update_attribute(:allow_track_admins_to_access_all_users, true)

    assert_permission_denied { get :new_from_other_program }
  end

  def test_new_from_other_program_for_no_dormant_members
    current_user_is :f_admin

    programs(:albers).update_attribute(:allow_track_admins_to_access_all_users, true)

    get :new_from_other_program, params: { filter_role: "Dormant"}

    assert_response :success
    assert_equal ["assistant@chronus.com"], assigns(:members).to_a.collect(&:email)
  end

  def test_create_from_other_program_success
    current_user_is :f_admin_nwen
    current_program_is :nwen

    programs(:nwen).update_attribute(:allow_track_admins_to_access_all_users, true)

    assert_emails 3 do
      assert_difference 'programs(:nwen).users.mentors.reload.count', 3 do
        post :create_from_other_program, params: { member_ids: [members(:mentor_3).id, members(:student_2).id, members(:mentor_1).id].join(","),
          roles: [RoleConstants::MENTOR_NAME]}
      end
    end

    assert_redirected_to new_from_other_program_users_path
  end

  def test_create_from_other_program_failure
    current_user_is :f_admin_nwen
    current_program_is :nwen

    programs(:nwen).update_attribute(:allow_track_admins_to_access_all_users, true)

    assert_no_difference 'User.count' do
      assert_raise ActiveRecord::RecordInvalid do
        post :create_from_other_program, params: { member_ids: [
          members(:mentor_4).id, members(:f_mentor).id, members(:student_2).id,
          members(:mentor_1).id, members(:student_3).id
        ].join(","),
          roles: [RoleConstants::STUDENT_NAME]
        }
      end
    end
  end

  def test_create_from_other_program_to_portal_success
    current_user_is :portal_admin
    current_program_is :primary_portal

    programs(:primary_portal).update_attribute(:allow_track_admins_to_access_all_users, true)

    assert_emails 2 do
      assert_difference 'programs(:primary_portal).users.reload.count', 2 do
        post :create_from_other_program, params: { member_ids: [members(:nch_mentor).id, members(:nch_mentee).id].join(","),
          roles: [RoleConstants::EMPLOYEE_NAME]}
      end
    end

    assert_redirected_to new_from_other_program_users_path
  end

  def test_create_from_other_program_to_portal_failure
    current_user_is :portal_admin
    current_program_is :primary_portal

    programs(:primary_portal).update_attribute(:allow_track_admins_to_access_all_users, true)

    assert_no_difference 'User.count' do
      assert_raise ActiveRecord::RecordInvalid do
        post :create_from_other_program, params: { member_ids: [
          members(:nch_admin).id   # User already in portal
        ].join(","),
          roles: [RoleConstants::EMPLOYEE_NAME]
        }
      end
    end
  end

  def test_create_from_other_program_from_portal_to_program_success
    current_user_is :portal_admin
    current_program_is :nch_mentoring

    programs(:nch_mentoring).update_attribute(:allow_track_admins_to_access_all_users, true)

    user = create_user({program: programs(:primary_portal), role_names: RoleConstants::EMPLOYEE_NAME})

    assert_emails 1 do
      assert_difference 'programs(:nch_mentoring).users.mentors.reload.count', 1 do
        assert_difference 'programs(:nch_mentoring).users.students.reload.count', 1 do
          post :create_from_other_program, params: { member_ids: [user.member.id].join(","),
            roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]}
        end
      end
    end

    assert_redirected_to new_from_other_program_users_path
  end

  def test_check_new_members_by_program_admin_success
    ram1 = create_user member: members(:ram), program: programs(:nwen), role_names: [RoleConstants::ADMIN_NAME]

    current_user_is ram1
    current_program_is :nwen

    programs(:nwen).update_attribute(:allow_track_admins_to_access_all_users, true)

    assert_emails 2 do
      assert_difference 'programs(:nwen).users.mentors.reload.count', 2 do
        post :create_from_other_program, params: { member_ids: [members(:rahim).id, members(:robert).id].join(","),
          roles: [RoleConstants::MENTOR_NAME]}
      end
    end
  end

  def test_new_members_from_other_programs_for_program_admins
    ram1 = create_user member: members(:ram), program: programs(:nwen), role_names: [RoleConstants::ADMIN_NAME]
    current_user_is ram1
    current_program_is :nwen

    programs(:nwen).update_attribute(:allow_track_admins_to_access_all_users, true)

    get :new_from_other_program, params: { filter_program_id: programs(:albers).id, items_per_page: 1_000}

    assert_response :success
    assert_equal_unordered(
      programs(:albers).users.collect(&:member_id) - programs(:nwen).all_users.collect(&:member_id),
      assigns(:members).collect(&:id).map(&:to_i) - [members(:ram).id] #subtract member id of ram1 because ram1 is not indexed
    )
  end

  def test_new_members_from_other_programs_for_program_admins_with_program_filter_role_filter
    ram1 = create_user member: members(:ram), program: programs(:nwen), role_names: [RoleConstants::ADMIN_NAME]
    current_user_is ram1
    current_program_is :nwen
    mentor_role_id = [programs(:albers).roles.where(name: "mentor").first.id.to_s]

    programs(:nwen).update_attribute(:allow_track_admins_to_access_all_users, true)

    get :new_from_other_program, params: { filter_program_id: programs(:albers).id,
      filter_role: mentor_role_id}

    assert_response :success
    assert_equal_unordered(
      programs(:albers).all_users.mentors.collect(&:member_id) - programs(:nwen).all_users.collect(&:member_id),
      assigns(:members).collect(&:id).map(&:to_i) - [members(:ram).id] #subtract member id of ram1 because ram1 is not indexed
    )
  end

  def test_new_mentor_form_required_signup
    get :new, params: { role: RoleConstants::MENTOR_NAME}
    assert_redirected_to new_session_path
  end

  def test_new_mentee_form_required_signup
    get :new, params: { role: RoleConstants::STUDENT_NAME}
    assert_redirected_to new_session_path
  end

  def test_permission_denied_for_new
    current_user_is :f_mentor

    assert_permission_denied do
      get :new, params: { role: RoleConstants::MENTOR_NAME}
    end
  end

  def test_render_new_mentor_form
    setup_up_for_add_user
    current_user_is @add_mentor_user

    get :new, params: { role: RoleConstants::MENTOR_NAME}
    assert_response :success
    assert_select 'html'

    assert_template 'new'
    assert_not_nil assigns(:user)
    assert assigns(:user).is_mentor?
  end

  def test_render_new_mentee_form
    setup_up_for_add_user
    current_user_is @add_student_user

    get :new, params: { role: RoleConstants::STUDENT_NAME}
    assert_response :success
    assert_select 'html'

    assert_template 'new'
    assert_not_nil assigns(:user)
    assert assigns(:user).is_student?
  end

  def test_render_new_form_by_js
    setup_up_for_add_user
    current_user_is @add_student_user

    get :new, xhr: true, params: { role: RoleConstants::STUDENT_NAME}
    assert_response :success

    assert_template 'new'
    assert_not_nil assigns(:user)
    assert assigns(:user).is_student?
  end

  def test_create_permission_deined
    current_user_is :f_mentor

    assert_permission_denied do
      post :create, params: { user: {
        member: {
          first_name: 'some',
          last_name: 'user',
          location_name: "Chennai"
        },
        max_connections_limit: 12,
        program_id: programs(:albers).id
      },
        external_user: "true",
        role: RoleConstants::MENTOR_NAME+","+RoleConstants::STUDENT_NAME, email: 'mentor@chronus.com'
      }
    end
  end

  def test_create_mentor_success
    setup_up_for_add_user
    prog = programs(:albers)
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION)
    skype_q = programs(:org_primary).profile_questions.skype_question.first
    phone_q = programs(:org_primary).profile_questions.find_by(question_text: "Phone")

    current_user_is @add_mentor_user

    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    assert_no_difference "ProfilePicture.count" do
      assert_difference('ActionMailer::Base.deliveries.size') do
        assert_difference('Password.count') do
          post :create, params: { user: {
            member: {
              first_name: 'some',
              last_name: 'user',
              profile_picture: {image: "", image_url: ""}
            },
            max_connections_limit: 12,
            program_id: programs(:albers).id
          },
            profile_answers: { profile_questions(:string_q).id.to_s => "First Answer",
                          profile_questions(:single_choice_q).id.to_s => "opt_2",
                          profile_questions(:multi_choice_q).id.to_s => "Walk",
                          skype_q.id.to_s => "api",
                          phone_q.id.to_s => "123"},
            external_user: "true",
            role: RoleConstants::MENTOR_NAME, email: 'mentor@chronus.com'
          }
        end
      end
    end

    assert_redirected_to program_root_path

    assert_not_nil assigns(:user)
    assert_equal "<a href='#{member_path(assigns(:user).member)}'>#{assigns(:user).name}</a> has been added as #{@controller._a_Mentor}.", flash[:notice]

    assert assigns(:user).is_mentor?
    assert_equal 'some user', assigns(:user).name
    assert_equal 'mentor@chronus.com', assigns(:user).email
    assert_equal programs(:albers), assigns(:user).program
    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, assigns(:user).program_notification_setting)
    assert_equal programs(:albers), assigns(:user).program
    assert_equal(12, assigns(:user).max_connections_limit)
    assert_equal_unordered [profile_questions(:string_q).id.to_s, profile_questions(:single_choice_q).id.to_s, profile_questions(:multi_choice_q).id.to_s, skype_q.id.to_s, phone_q.id.to_s], assigns(:answers).keys
    assert_equal_unordered ["First Answer", "opt_2", "Walk", "api", "123"], assigns(:answers).values
  end

  def test_create_mentor_success_with_removal_of_profile_answer_with_invalid_answers
    setup_up_for_add_user
    prog = programs(:albers)
    conditional_question = create_question(organization: programs(:org_primary), program: programs(:albers), role_names: [RoleConstants::MENTOR_NAME], question_text: "a conditional question", question_type: ProfileQuestion::Type::SINGLE_CHOICE, available_for: RoleQuestion::AVAILABLE_FOR::BOTH, question_choices: ["will never match", "match"])
    dependent_question = create_question(organization: programs(:org_primary), program: programs(:albers), role_names: [RoleConstants::MENTOR_NAME], question_text: "dependent question", question_type: ProfileQuestion::Type::TEXT, available_for: RoleQuestion::AVAILABLE_FOR::BOTH, conditional_question_id: conditional_question.id, conditional_match_text: "will never match")
    current_user_is @add_mentor_user

    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    assert_no_difference "ProfilePicture.count" do
      assert_difference('ActionMailer::Base.deliveries.size') do
        assert_difference('Password.count') do
          post :create, params: { user: {
            member: {
              first_name: 'some',
              last_name: 'user',
              profile_picture: {image: "", image_url: ""}
            },
            max_connections_limit: 12,
            program_id: programs(:albers).id
          },
            profile_answers: { conditional_question.id.to_s => "match",
                                  dependent_question.id.to_s => "opt_2"
                                },
            external_user: "true",
            role: RoleConstants::MENTOR_NAME, email: 'mentor@chronus.com'
          }
        end
      end
    end

    assert_redirected_to program_root_path
    new_member = assigns(:user).member
    assert_false new_member.profile_answers.collect(&:answer_value).include?("opt_2")
  end

  def test_create_mentor_success_with_no_removal_of_profile_answer_with_satisfying_conditional_answers
    setup_up_for_add_user
    prog = programs(:albers)
    conditional_question = create_question(organization: programs(:org_primary), program: programs(:albers), role_names: [RoleConstants::MENTOR_NAME], question_text: "a conditional question", question_type: ProfileQuestion::Type::SINGLE_CHOICE, available_for: RoleQuestion::AVAILABLE_FOR::BOTH, question_choices: "match_1,match_2,match_3")
    dependent_question = create_question(organization: programs(:org_primary), program: programs(:albers), role_names: [RoleConstants::MENTOR_NAME], question_text: "dependent question", question_type: ProfileQuestion::Type::TEXT, available_for: RoleQuestion::AVAILABLE_FOR::BOTH, conditional_question_id: conditional_question.id, conditional_match_text: "match_1")

    current_user_is @add_mentor_user

    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    assert_no_difference "ProfilePicture.count" do
      assert_difference('ActionMailer::Base.deliveries.size') do
        assert_difference('Password.count') do
          post :create, params: { user: {
            member: {
              first_name: 'some',
              last_name: 'user',
              profile_picture: {image: "", image_url: ""}
            },
            max_connections_limit: 12,
            program_id: programs(:albers).id
          },
            profile_answers: { conditional_question.id.to_s => "match_1",
                                  dependent_question.id.to_s => "opt_2"
                                },
            external_user: "true",
            role: RoleConstants::MENTOR_NAME, email: 'mentor@chronus.com'
          }
        end
      end
    end

    assert_redirected_to program_root_path
    new_member = assigns(:user).member
    assert new_member.profile_answers.collect(&:answer_value).include?("opt_2")
  end

  def test_create_student_success
    setup_up_for_add_user
    skype_q = programs(:org_primary).profile_questions.skype_question.first
    phone_q = programs(:org_primary).profile_questions.find_by(question_text: "Phone")
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION)

    prog = programs(:albers)
    current_user_is @add_student_user

    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    assert_no_difference "ProfilePicture.count" do
      assert_difference('ActionMailer::Base.deliveries.size') do
        assert_difference('Password.count') do
          post :create, params: { user: {
            member: {
              first_name: 'some',
              last_name: 'user',
              profile_picture: {image: "", image_url: ""}
            },
            max_connections_limit: 11,
            program_id: programs(:albers).id
          },
            profile_answers: { profile_questions(:student_string_q).id.to_s => "First Answer",
                          profile_questions(:student_single_choice_q).id.to_s => "opt_2",
                          profile_questions(:student_multi_choice_q).id.to_s => "Walk",
                          skype_q.id.to_s => "api",
                          phone_q.id.to_s => "123"},
            role: RoleConstants::STUDENT_NAME, email: 'student@chronus.com'
          }
        end
      end
    end

    assert_redirected_to program_root_path

    assert_not_nil assigns(:user)
    assert_equal "<a href='#{member_path(assigns(:user).member)}'>#{assigns(:user).name}</a> has been added as a #{@controller._Mentee}.", flash[:notice]

    assert assigns(:user).is_student?
    assert_equal 'some user', assigns(:user).name
    assert_equal 'student@chronus.com', assigns(:user).email
    assert_equal programs(:albers), assigns(:user).program
    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, assigns(:user).program_notification_setting)
    assert_equal programs(:albers), assigns(:user).program
    assert_equal(11, assigns(:user).max_connections_limit)
    assert_equal_unordered [profile_questions(:student_string_q).id.to_s, profile_questions(:student_single_choice_q).id.to_s, profile_questions(:student_multi_choice_q).id.to_s, skype_q.id.to_s, phone_q.id.to_s], assigns(:answers).keys
    assert_equal_unordered ["First Answer", "opt_2", "Walk", "api", "123"], assigns(:answers).values
  end

  def test_create_mentor_with_answers_success
    setup_up_for_add_user
    current_user_is @add_mentor_user
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    assert_difference 'User.count' do
      post :create, params: {
        user: {
        member: {
          first_name: 'some',
          last_name: 'user',
          profile_picture: {image: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
        },
        program_id: programs(:albers).id
      },
        profile_answers: {
        profile_questions(:string_q).id.to_s => "First Answer",
        profile_questions(:single_choice_q).id.to_s => "opt_2",
        profile_questions(:multi_choice_q).id.to_s => "Walk"
      }, add_another: 0, role: RoleConstants::MENTOR_NAME, email: 'mentor@chronus.com'}
    end

    # Not adding another mentor profile. Redirect to program home page.
    assert_redirected_to program_root_path

    user = assigns(:user)
    user.reload
    member = user.member
    assert_not_nil user
    assert_equal "<a href='#{member_path(assigns(:user).member)}'>#{assigns(:user).name}</a> has been added as #{@controller._a_Mentor}.", flash[:notice]

    assert assigns(:user).is_mentor?
    assert_equal 'some user', user.name
    assert_equal 'mentor@chronus.com', user.email
    assert_not_nil member.profile_picture
    assert_match(/test_pic.png/, member.profile_picture.image_file_name)
    assert_equal programs(:albers), assigns(:user).program
    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, assigns(:user).program_notification_setting)
    assert_equal_unordered [profile_questions(:string_q).id.to_s, profile_questions(:single_choice_q).id.to_s, profile_questions(:multi_choice_q).id.to_s], assigns(:answers).keys
    assert_equal_unordered ["First Answer", "opt_2", "Walk"], assigns(:answers).values
    assert_equal(3, user.member.profile_answers.size)
    assert_equal("First Answer", user.answer_for(profile_questions(:string_q)).answer_text)
    assert_equal("opt_2", user.answer_for(profile_questions(:single_choice_q)).answer_value)
    assert_equal(["Walk"], user.answer_for(profile_questions(:multi_choice_q)).answer_value)
  end

  def test_create_mentee_with_answers_success
    setup_up_for_add_user
    current_user_is @add_student_user
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    post :create, params: { user: { member: {
        first_name: 'some',
        last_name: 'user',
        profile_picture: {image: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
      },
      program_id: programs(:albers).id
    },
      profile_answers: {
      profile_questions(:student_string_q).id.to_s => "First Answer",
      profile_questions(:student_single_choice_q).id.to_s => "opt_2",
      profile_questions(:student_multi_choice_q).id.to_s => "Walk"
    }, add_another: 0, role: RoleConstants::STUDENT_NAME, email: 'student@chronus.com'}

    # Not adding another mentor profile. Redirect to program home page.
    assert_redirected_to program_root_path

    user = assigns(:user)
    member = user.member
    assert_not_nil user
    assert_equal "<a href='#{member_path(assigns(:user).member)}'>#{assigns(:user).name}</a> has been added as a #{@controller._Mentee}.", flash[:notice]

    assert assigns(:user).is_student?
    assert_equal 'some user', user.name
    assert_equal 'student@chronus.com', user.email
    assert_not_nil member.profile_picture
    assert_match(/test_pic.png/, member.profile_picture.image_file_name)
    assert_equal programs(:albers), assigns(:user).program
    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, assigns(:user).program_notification_setting)
    assert_equal_unordered [profile_questions(:student_string_q).id.to_s, profile_questions(:student_single_choice_q).id.to_s, profile_questions(:student_multi_choice_q).id.to_s], assigns(:answers).keys
    assert_equal_unordered ["First Answer", "opt_2", "Walk"], assigns(:answers).values
    assert_equal(3, user.member.profile_answers.size)
    assert_equal("First Answer", user.answer_for(profile_questions(:student_string_q)).answer_text)
    assert_equal("opt_2", user.answer_for(profile_questions(:student_single_choice_q)).answer_value)
    assert_equal(["Walk"], user.answer_for(profile_questions(:student_multi_choice_q)).answer_value)
  end

  def test_create_mentor_and_add_another
    setup_up_for_add_user
    current_user_is @add_mentor_user
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    post :create, params: { user: { member: {
        first_name: 'some',
        last_name: 'user'
      },
      program_id: programs(:albers).id
    }, profile_answers: {
      profile_questions(:string_q).id.to_s => "First answer",
      profile_questions(:single_choice_q).id.to_s => "opt_2"
    }, add_another: 1, role: RoleConstants::MENTOR_NAME, email: 'mentor@chronus.com'}

    assert_redirected_to new_user_path(role: RoleConstants::MENTOR_NAME )

    user = assigns(:user)
    user.reload
    assert_not_nil user
    assert_equal "<a href='#{member_path(assigns(:user).member)}'>#{assigns(:user).name}</a> has been added as #{@controller._a_Mentor}. You can continue adding the next #{@controller._Mentor}.", flash[:notice]

    assert_equal 'some user', user.name
    assert_equal [RoleConstants::MENTOR_NAME], user.role_names
    assert_equal 'mentor@chronus.com', user.email
    assert_equal programs(:albers), assigns(:user).program
    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, assigns(:user).program_notification_setting)
    assert_equal_unordered [profile_questions(:string_q).id.to_s, profile_questions(:single_choice_q).id.to_s], assigns(:answers).keys
    assert_equal_unordered ["First answer", "opt_2"], assigns(:answers).values
    assert_equal 2, user.member.profile_answers.reload.size
    assert_equal "First answer", user.answer_for(profile_questions(:string_q)).answer_text
    assert_equal "opt_2", user.answer_for(profile_questions(:single_choice_q)).answer_value
  end

  def test_create_mentee_and_add_another
    setup_up_for_add_user
    current_user_is @add_student_user
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    assert_difference 'ProfileAnswer.count', 2 do
      assert_difference 'User.count' do
        post :create, params: { user: { member: {
            first_name: 'some',
            last_name: 'user'
            },
          program_id: programs(:albers).id
        }, profile_answers: {
          profile_questions(:student_string_q).id.to_s => "First answer",
          profile_questions(:student_single_choice_q).id.to_s => "opt_2"
        }, add_another: 1, role: RoleConstants::STUDENT_NAME, email: 'student@chronus.com'}
      end
    end

    assert_redirected_to new_user_path(role: RoleConstants::STUDENT_NAME )

    user = assigns(:user)
    assert_not_nil user
    assert_equal "<a href='#{member_path(assigns(:user).member)}'>#{assigns(:user).name}</a> has been added as a #{@controller._Mentee}. You can continue adding the next #{@controller._Mentee}.", flash[:notice]

    assert_equal 'some user', user.name
    assert_equal 'student@chronus.com', user.email
    assert_equal programs(:albers), assigns(:user).program
    assert_equal(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, assigns(:user).program_notification_setting)
    assert_equal_unordered [profile_questions(:student_string_q).id.to_s, profile_questions(:student_single_choice_q).id.to_s], assigns(:answers).keys
    assert_equal_unordered ["First answer", "opt_2"], assigns(:answers).values
    assert_equal 2, user.member.profile_answers.size
    assert_equal "First answer", user.answer_for(profile_questions(:student_string_q)).answer_text
    assert_equal "opt_2", user.answer_for(profile_questions(:student_single_choice_q)).answer_value
  end

  def test_create_mentor_with_profile_failure
    setup_up_for_add_user
    ordered_profile_question = create_question(question_type: ProfileQuestion::Type::ORDERED_OPTIONS, question_text: "Select Preference", question_choices: "alpha, beta, gamma", options_count: 2, role_names: [RoleConstants::MENTOR_NAME])

    # The email is already taken
    current_user_is @add_mentor_user
    post :create, params: {
      user: {
        member: {
          last_name: 'some user'
        }
      },
      profile_answers: {
        profile_questions(:string_q).id => "First answer",
        profile_questions(:single_choice_q).id => "opt_2",
        ordered_profile_question.id => { "0" => "", "1" => "" }
      },
      email: users(:ram).email,
      role: RoleConstants::MENTOR_NAME
    }
    assert_response :success
    assert_template 'new'
    assert_equal_unordered (profile_questions(:string_q, :single_choice_q) + [ordered_profile_question]).map(&:id).map(&:to_s), assigns(:answers).keys
    assert_equal_unordered ["First answer", "opt_2", { "0" => "", "1" => "" } ], assigns(:answers).values
  end

  def test_admin_creating_existing_member_user_in_the_program
    setup_up_for_add_user
    current_user_is @add_mentor_user
    programs(:albers).update_attribute(:allow_track_admins_to_access_all_users, true)

    assert_difference "User.count", 1 do
      post :create, params: { user: { member: {
        first_name: 'existing',
        last_name: 'member user'
      }, program_id: programs(:albers).id}, member_id: members(:moderated_mentor).id, role: RoleConstants::MENTOR_NAME}
    end

    assert_equal User.last.member, members(:moderated_mentor)
  end

  def test_create_student_with_profile_failure
    setup_up_for_add_user
    current_user_is @add_student_user

    # The email is already taken
    post :create, params: { user: { member: {
        last_name: 'some user' },
      program_id: programs(:albers).id
    },
      profile_answers: {
          profile_questions(:student_string_q).id.to_s => "First answer",
          profile_questions(:student_single_choice_q).id.to_s => "opt_2"
        },
      role: RoleConstants::STUDENT_NAME, email: users(:ram).email
    }

    assert_response :success
    assert_template 'new'

    assert_equal_unordered [profile_questions(:student_string_q).id.to_s, profile_questions(:student_single_choice_q).id.to_s], assigns(:answers).keys
    assert_equal_unordered ["First answer", "opt_2"], assigns(:answers).values
  end

  def test_create_mentor_without_required_fields
    setup_up_for_add_user
    current_user_is @add_mentor_user

    assert_no_difference "ProfileAnswer.count" do
      assert_no_difference 'User.count' do
        post :create, params: { user: { member: {
          program_id: programs(:albers).id
        }},
          profile_answers: {
              profile_questions(:string_q).id.to_s => "First answer",
              profile_questions(:single_choice_q).id.to_s => "opt_2"
            },
          role: RoleConstants::MENTOR_NAME
        }
      end
    end
    assert_response :success
    assert_template 'new'
    assert_equal_unordered [profile_questions(:string_q).id.to_s, profile_questions(:single_choice_q).id.to_s], assigns(:answers).keys
    assert_equal_unordered ["First answer", "opt_2"], assigns(:answers).values
  end

  def test_create_mentor_success_with_timezone
    setup_up_for_add_user
    current_user_is @add_mentor_user

    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    post :create, params: { user: { member: {
        last_name: 'some user',
        first_name: 'some member',
        time_zone: "Asia/Kolkata"
        },
      program_id: programs(:albers).id
    },
      role: RoleConstants::MENTOR_NAME, email: 'mentor@chronus.com'
    }

    assert_equal "Asia/Kolkata", User.find_by_email_program("mentor@chronus.com", programs(:albers)).member.time_zone
  end

  # UsersController#new_user_with_invite has been deprecated
  # and the entire logic has been shifted to RegistrationsController#new
  # The route is only for backward compatibility
  def test_new_user_with_invite_backward_compatibility
    assert_routing '/users/new_user_with_invite', controller: 'registrations', action: 'new'
  end

  ### New User Followup ###

  def test_new_user_followup_when_invalid_code
    setup_new_user_followup

    current_program_is @program
    get :new_user_followup, params: { reset_code: "invalid"}
    assert_invalid_new_user_followup
  end

  def test_new_user_followup_when_organization_mismatch
    setup_new_user_followup

    current_program_is :ceg
    get :new_user_followup, params: { reset_code: @password.reset_code}
    assert_invalid_new_user_followup
  end

  def test_new_user_followup_when_loggedin_as_different_member
    setup_new_user_followup

    current_user_is :f_student
    get :new_user_followup, params: { reset_code: @password.reset_code}
    assert_invalid_new_user_followup(new_user_followup_users_path(reset_code: @password.reset_code))
    assert_false assigns(:current_member)
  end

  def test_new_user_followup_when_loggedin_at_organization_level
    setup_new_user_followup

    current_member_is @member
    get :new_user_followup, params: { reset_code: @password.reset_code}
    assert_invalid_new_user_followup
    assert @member, assigns(:current_member)
  end

  def test_new_user_followup_when_loggedin_and_no_user_at_program_level
    member = members(:dormant_member)
    password = Password.create!(member_id: member.id)

    current_program_is :albers
    current_member_is member
    get :new_user_followup, params: { reset_code: password.reset_code}
    assert_invalid_new_user_followup(nil, "You are not a member of this program.")
    assert_equal member, assigns(:current_member)
  end

  def test_new_user_followup_when_member_can_signin
    setup_new_user_followup
    linkedin_oauth = @organization.linkedin_oauth
    @member.login_identifiers.create!(auth_config: linkedin_oauth, identifier: "123")

    current_program_is @program
    get :new_user_followup, params: { reset_code: @password.reset_code}
    assert_redirected_to login_path(auth_config_ids: [linkedin_oauth.id])
    assert_equal "Please login to complete the signup process.", flash[:info]
    assert_equal @password.reset_code, session[:reset_code]
  end

  def test_new_user_followup_when_authenticated_externally
    setup_new_user_followup
    auth_config = @organization.linkedin_oauth
    session[:new_user_import_data] = { @organization.id => { "ProfileAnswer" => { "1" => "answer text" } } }
    session[:new_custom_auth_user] = { @organization.id => "uid", auth_config_id: auth_config.id }

    current_program_is @program
    get :new_user_followup, params: { reset_code: @password.reset_code}
    assert_response :success
    assert_template "registrations/new"
    assert_valid_new_user_followup(auth_config)
    assert_equal( { "1" => "answer text" }, assigns(:profile_answers_map))
  end

  def test_new_user_followup_when_non_indigenous_auth
    setup_new_user_followup
    non_indigenous_auth = @organization.linkedin_oauth

    @controller.expects(:get_and_set_current_auth_config).returns(non_indigenous_auth)
    current_program_is @program
    get :new_user_followup, params: { reset_code: @password.reset_code}
    assert_redirected_to login_path(auth_config_ids: [non_indigenous_auth.id])
    assert_equal "Please login to complete the signup process.", flash[:info]
    assert_valid_new_user_followup(non_indigenous_auth)
  end

  def test_new_user_followup_when_indigenous_auth
    setup_new_user_followup
    chronus_auth = @organization.chronus_auth

    @controller.expects(:get_and_set_current_auth_config).returns(chronus_auth)
    current_program_is @program
    get :new_user_followup, params: { reset_code: @password.reset_code}
    assert_response :success
    assert_template "registrations/new"
    assert_valid_new_user_followup(chronus_auth)
  end

  def test_new_user_followup
    setup_new_user_followup
    custom_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)

    current_program_is @program
    get :new_user_followup, params: { reset_code: @password.reset_code}
    assert_response :success
    assert_template "registrations/new"
    assert_valid_new_user_followup
    assert_equal 2, assigns(:login_sections).size
    assert assigns(:login_sections)[1][:auth_configs].all?(&:default?)
    assert_equal [custom_auth], assigns(:login_sections)[0][:auth_configs]
  end

  ### New User Followup - END ###

  def test_show_skype_and_phone_on_add_mentor_page
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION)

    get :new, params: { role: RoleConstants::MENTOR_NAME, email: "userram@example.com"}
    assert_response :success
    assert_template 'new'

    assert_equal assigns(:existing_member), Member.find_by(email: "userram@example.com")
    assert members(:f_admin).admin?
    assert assigns(:can_add_existing_member)
    assert_equal assigns(:member), assigns(:existing_member)
    assert_equal assigns(:email), "userram@example.com"
  end

  def test_validate_email_address
    security_setting = programs(:org_primary).security_setting
    security_setting.update_attribute(:email_domain, "test.com, gmail.com")

    current_user_is :f_admin
    get :validate_email_address, params: { email: "a@b.com"}
    assert_equal "{\"is_valid\":false,\"flash_message\":\"Email domain should be of test.com, gmail.com\"}", response.body

    security_setting.update_attribute(:email_domain, "")

    get :validate_email_address, params: { email: "user@chronus.com"}
    assert_equal "{\"is_valid\":true,\"flash_message\":\"Please enter a valid email address\"}", response.body

    get :validate_email_address, params: { email: "user@test123.com"}
    assert_equal "{\"is_valid\":false,\"flash_message\":\"Please enter a valid email address\"}", response.body
  end

  def test_show_no_skype_and_phone_on_add_mentor_page
    current_user_is :f_admin

    members(:f_admin).update_attribute(:admin, false)

    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION, false)
    get :new, params: { role: RoleConstants::MENTOR_NAME, email: "userram@example.com"}
    assert_response :success
    assert_template 'new'

    assert_no_select "input#profile_answers_#{programs(:org_primary).profile_questions.skype_question.first.id}"

    assert_equal assigns(:existing_member), Member.find_by(email: "userram@example.com")
    assert_false assigns(:can_add_existing_member)
    assert_nil assigns(:member).id
    assert_equal assigns(:email), "userram@example.com"
  end

  def test_should_not_show_skype_on_add_mentor_page_when_feature_disabled
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION, false)

    get :new, params: { role: RoleConstants::MENTOR_NAME}
    assert_response :success
    assert_template 'new'
    assert_no_select "input#user_member_skype_id"
  end

  def test_should_not_show_name_and_email_as_profile_summary_in_listing
    current_user_is :f_admin

    get :index, params: { view:  'students', highlight_filters: true}
    assert_select "div#page_heading", text: /Students/
    assert_select ".section-pane" do
      assert_select "h4", text: /Name/, count: 0
      assert_select "h4", text: /Email/, count: 0
    end
    assert assigns(:highlight_filters)
    assert_false assigns(:show_favorite_ignore_links)
  end

  def test_mentors_listing_should_show_pending_mentor_to_admin
    m1 = users(:pending_user)
    assert_equal User::Status::PENDING, m1.reload.state
    current_user_is users(:f_admin)
    src = EngagementIndex::Src::BrowseMentors::MENTOR_PROFILE_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).never
    get :index, xhr: true, params: { src: src, filter: "all", page: 3}
    users2 = assigns(:users)
    assert users2.include?(m1)
    assert_false assigns(:show_favorite_ignore_links)
  end

  def test_mentors_listing_should_not_show_pending_mentor_to_other_mentors
    m1 = users(:pending_user)
    m1.program.enable_feature(FeatureName::CALENDAR)
    assert_equal User::Status::PENDING, m1.state
    current_user_is users(:f_mentor)
    src = EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).never
    get :index, params: { src: src, filter: "all", page: 1}
    #Availability icons to be displayed in mentors listing page
    assert_select "i.fa.fa-user-plus"
    assert_select "i.fa.fa-calendar"

    users1 = assigns(:users)
    assert !users1.include?(m1)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).never
    get :index, params: { src: src, filter: "all", page: 2}
    users2 = assigns(:users)
    assert !users2.include?(m1)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).never
    get :index, params: { src: src, filter: "all", page: 3}
    users3 = assigns(:users)
    assert !users3.include?(m1)
  end

  def test_mentors_listing_default_general_availability_meeting_filter
    current_user_is :f_student
    programs(:albers).enable_feature(FeatureName::CALENDAR, true)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)

    UserSetting.destroy_all

    assert Meeting.of_program(programs(:albers)).non_group_meetings.present?
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)

    src = EngagementIndex::Src::BrowseMentors::QUICK_CONNECT_BOX
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 50}

    assert assigns(:program_only_has_general_availabilty_meeting_filter)
    assert assigns(:my_filters).include?({label: 'Availability Status', reset_suffix: 'availability_status'})

    assert_equal_unordered programs(:albers).mentor_users.active, assigns(:users)
    assert assigns(:show_favorite_ignore_links)
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:favorite_1).id, users(:robert).id=>abstract_preferences(:favorite_3).id}, assigns(:favorite_preferences_hash))
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:ignore_1).id, users(:ram).id=>abstract_preferences(:ignore_3).id}, assigns(:ignore_preferences_hash))
  end

  def test_mentors_listing_default_general_availability_meeting_filter_ajax_request
    abstract_preferences(:ignore_1).destroy!
    abstract_preferences(:ignore_3).destroy!
    current_user_is :f_student
    programs(:albers).enable_feature(FeatureName::CALENDAR, true)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(false)

    assert Meeting.of_program(programs(:albers)).non_group_meetings.present?
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)

    src = EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, xhr: true, params: { src: src, items_per_page: 50}

    assert assigns(:program_only_has_general_availabilty_meeting_filter)
    assert_false assigns(:my_filters).include?({label: 'Availability Status', reset_suffix: 'availability_status'})

    assert_equal_unordered (assigns(:match_results).keys & programs(:albers).mentor_users.active.map(&:id)), assigns(:users).map(&:id)
    assert_false assigns(:show_favorite_ignore_links)
  end

  def test_mentors_listing_default_general_availability_meeting_filter_for_mentors_limit_combination
    current_user_is :f_student
    programs(:albers).enable_feature(FeatureName::CALENDAR, true)

    Meeting.of_program(programs(:albers)).destroy_all
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)

    User.any_instance.stubs(:is_student_meeting_request_limit_reached?).returns(false)
    User.any_instance.stubs(:is_student_meeting_limit_reached?).returns(false)

    users(:f_mentor).user_setting.update_attributes!(max_meeting_slots: 1)
    users(:f_mentor_student).user_setting.update_attributes!(max_meeting_slots: 0)

    assert_nil users(:not_requestable_mentor).user_setting

    current_time = Time.now
    Time.stubs(:now).returns(current_time.beginning_of_month + 3.days)

    src = EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 50}

    assert assigns(:users).include?(users(:f_mentor))
    assert_false assigns(:users).include?(users(:f_mentor_student))
    assert assigns(:users).include?(users(:not_requestable_mentor))

    m1 = create_meeting(members: [members(:f_mentor), members(:mkr_student)], owner_id: members(:mkr_student).id, program_id: programs(:albers).id, start_time: Time.now + 1.day + 4.hours, end_time: Time.now + 1.day + 5.hours, topic: "trial", description: "test")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 50}

    assert assigns(:users).include?(users(:f_mentor))
    assert_false assigns(:users).include?(users(:f_mentor_student))
    assert assigns(:users).include?(users(:not_requestable_mentor))

    m2 = create_meeting(members: [members(:f_mentor), members(:mkr_student)], owner_id: members(:mkr_student).id, program_id: programs(:albers).id, start_time: Time.now.next_month, end_time: Time.now.next_month + 1.hour, topic: "trial", description: "test")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 50}

    assert_false assigns(:users).include?(users(:f_mentor))
    assert_false assigns(:users).include?(users(:f_mentor_student))
    assert assigns(:users).include?(users(:not_requestable_mentor))
  end

  def test_mentors_listing_meeting_filter_with_pending_and_accepted_requests
    current_user_is :f_student
    programs(:albers).enable_feature(FeatureName::CALENDAR, true)

    Meeting.of_program(programs(:albers)).destroy_all
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)

    User.any_instance.stubs(:is_student_meeting_request_limit_reached?).returns(false)
    User.any_instance.stubs(:is_student_meeting_limit_reached?).returns(false)

    users(:f_mentor).user_setting.update_attributes!(max_meeting_slots: 1)
    users(:f_mentor_student).user_setting.update_attributes!(max_meeting_slots: 0)

    assert_nil users(:not_requestable_mentor).user_setting

    current_time = Time.now
    Time.stubs(:now).returns(current_time.beginning_of_month + 3.days)

  src = EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 50}

    assert assigns(:users).include?(users(:f_mentor))
    assert_false assigns(:users).include?(users(:f_mentor_student))
    assert assigns(:users).include?(users(:not_requestable_mentor))

    m1 = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now + 1.day + 4.hours, end_time: Time.now + 1.day + 5.hours)

    mr1 = m1.meeting_request
    mr1.update_attributes!(status: AbstractRequest::Status::NOT_ANSWERED)
    m1.update_attributes!(meeting_request_id: mr1.id)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 50}

    assert assigns(:users).include?(users(:f_mentor))
    assert_false assigns(:users).include?(users(:f_mentor_student))
    assert assigns(:users).include?(users(:not_requestable_mentor))

    m2 = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now.next_month, end_time: Time.now.next_month + 1.hour)

    mr2 = m2.meeting_request
    mr2.update_attributes!(status: AbstractRequest::Status::NOT_ANSWERED)
    m2.update_attributes!(meeting_request_id: mr2.id)

    create_meeting_proposed_slot(start_time: Time.now.next_month, end_time: Time.now.next_month + 1.hour, meeting_request_id: mr2.id)

  @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 50}

    assert_false assigns(:users).include?(users(:f_mentor))
    assert_false assigns(:users).include?(users(:f_mentor_student))
    assert assigns(:users).include?(users(:not_requestable_mentor))
  end

  def test_mentors_listing_meeting_filter_mentors_having_capacity_but_no_slots
    current_user_is :f_student
    programs(:albers).enable_feature(FeatureName::CALENDAR, true)

    Meeting.of_program(programs(:albers)).destroy_all
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)

    User.any_instance.stubs(:is_student_meeting_request_limit_reached?).returns(false)
    User.any_instance.stubs(:is_student_meeting_limit_reached?).returns(false)

    users(:f_mentor).user_setting.update_attributes!(max_meeting_slots: 10)
    users(:f_mentor_student).user_setting.update_attributes!(max_meeting_slots: 10)

    members(:f_mentor).update_attributes!(will_set_availability_slots: true)
    members(:f_mentor_student).update_attributes!(will_set_availability_slots: true)

    users(:f_student).program.calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: true, allow_mentor_to_describe_meeting_preference: true)

    current_time = Time.now
    Time.stubs(:now).returns(current_time.beginning_of_month + 3.days)

    mentoring_slots(:f_mentor).update_attributes!(start_time: Time.now + 1.day, end_time: Time.now + 1.day + 1.hour)
    mentoring_slots(:f_mentor_student).update_attributes!(start_time: Time.now + 1.day, end_time: Time.now + 1.day + 1.hour, member: members(:f_mentor_student))

    members(:f_mentor_student).reload

    src = EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 50}

    assert assigns(:available_mentor_member_ids).include?(members(:f_mentor).id)
    assert assigns(:available_mentor_member_ids).include?(members(:f_mentor_student).id)

    assert assigns(:users).include?(users(:f_mentor))
    assert assigns(:users).include?(users(:f_mentor_student))

    m1 = create_meeting(members: [members(:f_mentor), members(:mkr_student)], owner_id: members(:mkr_student).id, program_id: programs(:albers).id, start_time: Time.now + 1.day, end_time: Time.now + 1.day + 1.hour, topic: "trial", description: "test")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 50}

    assert_false assigns(:available_mentor_member_ids).include?(members(:f_mentor).id)
    assert assigns(:available_mentor_member_ids).include?(members(:f_mentor_student).id)

    assert_false assigns(:users).include?(users(:f_mentor))
    assert assigns(:users).include?(users(:f_mentor_student))

    members(:f_mentor).update_attributes!(will_set_availability_slots: false)

    src = EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 50}

    assert assigns(:available_mentor_member_ids).include?(members(:f_mentor).id)
    assert assigns(:available_mentor_member_ids).include?(members(:f_mentor_student).id)

    assert assigns(:users).include?(users(:f_mentor))
    assert assigns(:users).include?(users(:f_mentor_student))
  end

  def test_mentors_listing_should_show_recommendations_badge_preferred_mentoring
    rahim = users(:rahim)
    ram = users(:ram)

    current_user_is :rahim
    Program.any_instance.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    get :index, params: { items_per_page: 20 }
    assert_select "div#mentor_#{ram.id}" do
      assert_select ".label-success", text: "Recommended"
    end
    assert_false assigns(:show_favorite_ignore_links)
    create_group(students: [rahim], mentor: ram, program: programs(:albers))
    get :index, params: { items_per_page: 20}
    assert_select "div#mentor_#{ram.id}" do
      assert_select ".label-success", text: "Recommended", count: 1
    end
  end

  def test_mentors_listing_should_show_recommendations_badge_self_mentoring
    rahim = users(:rahim)
    ram = users(:ram)

    current_user_is :rahim
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(true)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    get :index, params: { items_per_page: 20 }
    assert_select "div#mentor_#{ram.id}" do
      assert_select ".label-success", text: "Recommended"
    end
    assert assigns(:show_favorite_ignore_links)
    assert_equal_hash({users(:ram).id=>abstract_preferences(:favorite_2).id}, assigns(:favorite_preferences_hash))
    assert_equal_hash({users(:robert).id=>abstract_preferences(:ignore_2).id}, assigns(:ignore_preferences_hash))

    create_group(students: [rahim], mentor: ram, program: programs(:albers))
    get :index, params: { items_per_page: 20}
    assert_select "div#mentor_#{ram.id}" do
      assert_select ".label-success", text: "Recommended", count: 1
    end
    assert assigns(:show_favorite_ignore_links)
    assert_equal_hash({users(:ram).id=>abstract_preferences(:favorite_2).id}, assigns(:favorite_preferences_hash))
    assert_equal_hash({users(:robert).id=>abstract_preferences(:ignore_2).id}, assigns(:ignore_preferences_hash))
  end

  def test_mentors_listing_should_not_show_recommendation_badge_when_not_preferred_mentoring_or_self_matching
    rahim = users(:rahim)
    ram = users(:ram)
    current_user_is :rahim
    Program.any_instance.stubs(:matching_by_mentee_alone?).returns(false)
    Program.any_instance.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    get :index, params: { items_per_page: 20}
    assert_select "div#mentor_#{ram.id}" do
      assert_select "div.label.label-inverse", 0
    end
  end

  def test_students_listing_should_show_find_a_mentor_for_only_unconnected_students_to_admins
    current_user_is users(:f_admin)
    unconnected_student = users(:student_5)

    src = EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).never
    get :index, params: { src: src, filter: "unconnected", items_per_page: 5,  view: RoleConstants::STUDENTS_NAME}
    users1 = assigns(:users)
    assert_select 'div#inner_content' do
      assert_select 'div.listing' do
        assert_select 'a', text: "Find a Mentor", count: 10 # Mobile and Web
      end
    end
    assert_false assigns(:student_document_available)
  end

  def test_index_user_search_activity_for_student
    current_user_is :f_student
    options = {"quick_search"=>"sample text", "locale"=>"en", "source"=>UserSearchActivity::Src::LISTING_PAGE, "session_id"=>"#{session.id}", "custom_profile_filters"=>{}}
    UserSearchActivity.expects(:add_user_activity).with(users(:f_student), options).once
    get :index, xhr: true, params: {"sf" => {"quick_search" => "sample text"}}
    assert_response :success

    UserSearchActivity.expects(:add_user_activity).never
    get :index, xhr: true, params: { items_per_page: 5}
    assert_response :success

    @controller.stubs(:working_on_behalf?).returns(true)
    UserSearchActivity.expects(:add_user_activity).never
    get :index, xhr: true, params: {"sf" => {"quick_search" => "sample text"}}
    assert_response :success
  end

  def test_index_user_search_activity_for_mentor
    current_user_is :f_mentor
    UserSearchActivity.expects(:add_user_activity).never
    get :index, xhr: true, params: {"sf" => {"quick_search" => "sample text"}}
    assert_response :success
  end

  def test_index_user_search_activity_for_admin
    current_user_is :f_admin
    UserSearchActivity.expects(:add_user_activity).never
    get :index, xhr: true, params: {"sf" => {"quick_search" => "sample text"}}
    assert_response :success
  end

  def test_find_mentor_should_have_back_link
    current_user_is users(:f_admin)
    unconnected_student = users(:student_5)
    get :matches_for_student, params: { student_name: unconnected_student.name_with_email,
      src: "students_listing"}

    assert_select 'div#title_box' do
      assert_select "a[class=\"back_link text-default cui_off_canvas_hide cjs_page_back_link\"][href=\"#{users_path(view: RoleConstants::STUDENTS_NAME)}\"]"
    end

    assert assigns(:student_document_available)

    get :matches_for_student, params: { student_name: unconnected_student.name_with_email,
      src: "students_profile"}

    assert_select 'div#title_box' do
      assert_select "a[class=\"back_link text-default cui_off_canvas_hide cjs_page_back_link\"][href=\"#{member_path(id: unconnected_student.id)}\"]"
    end

    assert assigns(:student_document_available)
  end

  def test_find_mentor_with_no_match_filter
    current_user_is users(:f_admin)
    unconnected_student = users(:student_5)
    get :matches_for_student, params: { student_name: unconnected_student.name_with_email, src: "students_listing"}
    assert assigns(:show_no_match_filter_visible)
    assert assigns(:show_no_match_filter_value)
    assert_false assigns(:hide_no_match_users)
  end

  def test_include_user_stat_when_coach_rating_enabled
    programs(:albers).enable_feature(FeatureName::COACH_RATING, true)
    current_user_is users(:f_admin)
    unconnected_student = users(:student_5)
    get :matches_for_student, params: { student_name: unconnected_student.name_with_email,
      src: "students_listing"}
    assert assigns(:includes_list).include?(:user_stat)
  end

  def test_include_groups_for_project_based_program_for_listing_page
    current_user_is users(:f_admin_pbe)
    get :index
    assert assigns(:includes_list).include?(:groups)

    Program.any_instance.stubs(:project_based?).returns(false)
    get :index
    assert_false assigns(:includes_list).include?(:groups)
  end

  def test_do_not_include_groups_for_project_based_program_for_matches_for_student
    Program.any_instance.stubs(:project_based?).returns(true)
    current_user_is users(:f_admin)
    unconnected_student = users(:student_5)
    get :matches_for_student, params: { student_name: unconnected_student.name_with_email,
      src: "students_listing"}
    assert_false assigns(:includes_list).include?(:groups)
  end

  def test_mentors_listing_should_not_show_pending_mentors_to_students
    m1 = users(:pending_user)
    assert_equal User::Status::PENDING, m1.state
    current_user_is users(:f_student)
  src = EngagementIndex::Src::BrowseMentors::QUICK_LINKS
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, filter: "all"}
    users1 = assigns(:users)
    assert !users1.include?(m1)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, filter: "all", page: 2}
    users2 = assigns(:users)
    assert !users2.include?(m1)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, filter: "all", page: 3}
    users3 = assigns(:users)
    assert !users3.include?(m1)
  end

  def test_mentors_listing_should_show_link_to_availability_calendar_when_feature_enabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    users(:f_student).program.calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: true)
    current_user_is users(:f_student)
    get :index

    assert_select "div#title_actions" do
      assert_select "a", text: "See Mentoring Calendar"
    end
    assert_equal "Availability Status", assigns(:status_filter_label)
    assert_false assigns(:program_only_has_general_availabilty_meeting_filter)
  end

  def test_mentors_listing_should_not_show_link_to_availability_calendar_when_feature_disabled
    current_user_is users(:f_student)
    get :index

    assert_no_select "div#title_actions"
  end

  def test_mentors_listing_should_contain_hidden_field_reset_page
    current_user_is users(:f_admin)
    get :index

    assert_select "form#search_filter_form" do
      assert_select "input#reset_page", text: "", count: 1
    end
  end

  def test_mentors_listing_for_admin_and_no_match_filter
    current_user_is users(:f_admin)
    get :index
    assert_false assigns(:match_view)
    assert_false assigns(:show_no_match_filter_visible)
    assert_nil assigns(:show_no_match_filter_value)
    assert_false assigns(:hide_no_match_users)
  end

  def test_mentors_listing_for_student_with_document_available
    current_user_is users(:f_student)
    get :index
    assert assigns(:student_document_available)
    assert_false assigns(:program_only_has_general_availabilty_meeting_filter)
  end

  def test_fetch_change_roles_failure
    current_user_is users(:f_student)
    assert_record_not_found do
      get :fetch_change_roles, params: { id: 0 }
    end

    assert_permission_denied do
      get :fetch_change_roles, params: { id: users(:f_student).id}
    end
  end

  def test_fetch_change_roles_success_administrative
    current_user_is users(:f_admin)
    get :fetch_change_roles, params: { id: users(:f_admin).id}
    assert_response :success
    assert_equal users(:f_admin), assigns(:profile_user)
    assert_equal_unordered [RoleConstants::ADMIN_NAME], assigns(:admin_roles).collect{|r| r.name}
    assert_equal_unordered [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME, "user"], assigns(:non_admin_roles).collect{|r| r.name}
    assert_match "What roles would you like to play in this program?", @response.body
    assert_match "add_role_form", @response.body
    assert_select "input#role_names_admin[class='change_roles_checkbox'][checked='checked'][disabled='disabled'][name='role_names[]'][type='checkbox'][value='admin']"
    programs(:albers).roles.each do |r|
      assert_match "value=\"#{r.name}\"", @response.body
    end
  end

  def test_fetch_change_roles_success_non_administrative
    current_user_is users(:f_admin)
    get :fetch_change_roles, xhr: true, params: { id: users(:f_student).id}
    assert_response :success
    assert_equal users(:f_student), assigns(:profile_user)
    assert_equal_unordered [RoleConstants::ADMIN_NAME], assigns(:admin_roles).collect{|r| r.name}
    assert_equal_unordered [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME, "user"], assigns(:non_admin_roles).collect{|r| r.name}
    assert_match "What roles would you like to assign to student example in this program?", @response.body
    assert_match "add_role_form", @response.body
    assert_select "input#role_names_admin[class='change_roles_checkbox'][name='role_names[]'][type='checkbox'][value='admin']"
    programs(:albers).roles.each do |r|
      assert_match "value=\"#{r.name}\"", @response.body
    end
  end

  def test_update_role_admin_to_admin_mentor
    current_user_is :f_admin

    assert_emails 0 do
      post :change_roles, params: { id: users(:f_admin).id, role_names_str: RoleConstants::MENTOR_NAME+','+RoleConstants::ADMIN_NAME}
    end

    assert_redirected_to edit_member_url(members(:f_admin), first_visit: true, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION_CHANGE_ROLES)
    assert_equal "The roles have been successfully updated", flash[:notice]
    assert_equal [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME], users(:f_admin).reload.role_names
  end

  def test_update_role_admin_to_admin_student
    current_user_is :f_admin

    post :change_roles, params: { id: users(:f_admin).id, role_names_str: RoleConstants::STUDENT_NAME+','+RoleConstants::ADMIN_NAME}

    assert_redirected_to edit_member_url(members(:f_admin), first_visit: true, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION_CHANGE_ROLES)
    assert_match "The roles have been successfully updated", flash[:notice]
    assert_equal [RoleConstants::ADMIN_NAME, RoleConstants::STUDENT_NAME], users(:f_admin).reload.role_names
  end

  def test_update_role_scenario_admin_to_all_roles
    current_user_is :f_admin
    create_mentor_question

    post :change_roles, params: { id: users(:f_admin).id, role_names_str: programs(:albers).roles.pluck(:name).join(",")}

    assert_equal_unordered [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, "user"],
      users(:f_admin).reload.role_names
    assert_redirected_to edit_member_url(members(:f_admin), first_visit: true, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION_CHANGE_ROLES)
    assert_match "The roles have been successfully updated", flash[:notice]
  end

  def test_update_role_scenario_admin_to_only_mentor_student
    current_user_is :f_admin
    create_mentor_question
    #It should not remove admin role
    assert_permission_denied do
      post :change_roles, params: { id: users(:f_admin).id, role_names_str: RoleConstants::MENTOR_NAME+','+RoleConstants::STUDENT_NAME}
    end

    assert_equal [RoleConstants::ADMIN_NAME], users(:f_admin).reload.role_names
  end

  def test_update_role_mentor_to_mentor_admin_to_student
    current_user_is :f_admin
    post :change_roles, params: { id: users(:f_mentor).id, role_names_str: RoleConstants::MENTOR_NAME+','+RoleConstants::ADMIN_NAME}

    assert_redirected_to member_path(members(:f_mentor))
    assert_match "The roles have been successfully updated", flash[:notice]
    assert_equal [RoleConstants::MENTOR_NAME,RoleConstants::ADMIN_NAME], users(:f_mentor).reload.role_names

    #Remove admin role
    post :change_roles, params: { id: users(:f_mentor).id, role_names_str: RoleConstants::STUDENT_NAME}

    assert_redirected_to member_path(members(:f_mentor))
    assert_match "The roles have been successfully updated", flash[:notice]
    assert_equal [RoleConstants::STUDENT_NAME], users(:f_mentor).reload.role_names
  end

  def test_update_role_mentor_to_mentor_student
    current_user_is :f_admin
    post :change_roles, params: { id: users(:f_mentor).id, role_names_str: RoleConstants::MENTOR_NAME+','+RoleConstants::STUDENT_NAME}

    assert_redirected_to member_path(members(:f_mentor))
    assert_match "The roles have been successfully updated", flash[:notice]
    assert_equal [RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME], users(:f_mentor).reload.role_names
  end

  def test_update_role_mentor_to_student
    current_user_is :f_admin
    post :change_roles, params: { id: users(:f_mentor).id, role_names_str: RoleConstants::STUDENT_NAME}

    assert_redirected_to member_path(members(:f_mentor))
    assert_match "The roles have been successfully updated", flash[:notice]
    assert_equal [RoleConstants::STUDENT_NAME], users(:f_mentor).reload.role_names
    assert_nil users(:f_mentor).max_connections_limit
  end

  def test_update_role_mentor_to_user
    current_user_is :f_admin
    post :change_roles, params: { id: users(:f_mentor).id, role_names_str: "user"}

    assert_redirected_to member_path(members(:f_mentor))
    assert_match "The roles have been successfully updated", flash[:notice]
    assert_equal ["user"], users(:f_mentor).reload.role_names
    assert_nil users(:f_mentor).max_connections_limit
  end

  def test_update_role_user_to_student
    current_user_is :f_admin
    post :change_roles, params: { id: users(:f_user).id, role_names_str: RoleConstants::STUDENT_NAME}

    assert_redirected_to member_path(members(:f_user))
    assert_match "The roles have been successfully updated", flash[:notice]
    assert_equal [RoleConstants::STUDENT_NAME], users(:f_user).reload.role_names
  end

  def test_update_role_mentor_student_to_mentor
    current_user_is :f_admin
    post :change_roles, params: { id: users(:f_mentor_student).id, role_names_str: RoleConstants::MENTOR_NAME}

    assert_equal [RoleConstants::MENTOR_NAME], users(:f_mentor_student).reload.role_names
    assert_redirected_to member_path(members(:f_mentor_student))
    assert_match "The roles have been successfully updated", flash[:notice]
  end

  def test_update_role_mentor_to_mentor_admin
    current_user_is :f_admin
    post :change_roles, params: { id: users(:f_mentor).id, role_names_str: RoleConstants::MENTOR_NAME+','+RoleConstants::ADMIN_NAME}

    assert_redirected_to member_path(members(:f_mentor))
    assert_match "The roles have been successfully updated", flash[:notice]
    assert_equal [RoleConstants::MENTOR_NAME,RoleConstants::ADMIN_NAME], users(:f_mentor).reload.role_names
  end

  def test_update_role_mentor_to_admin
    current_user_is :f_admin
    post :change_roles, params: { id: users(:f_mentor).id, role_names_str: RoleConstants::ADMIN_NAME}

    assert_redirected_to member_path(members(:f_mentor))
    assert_match "The roles have been successfully updated", flash[:notice]
    assert_equal [RoleConstants::ADMIN_NAME], users(:f_mentor).reload.role_names
  end

  def test_autocomplete_user_name_with_json_params
    user = users(:f_admin)
    current_user_is user

    get :auto_complete_for_name, xhr: true, params: { search: user.name(name_only: true), format: :json, for_autocomplete: true, no_email: true}
    assert_response :success
    assert_equal_unordered [user].collect(&:id), assigns(:users).collect(&:id)
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["Freakin Admin"], JSON.parse(@response.body)
  end

  def test_autocomplete_user_name_with_json_params_no_results
    current_user_is users(:f_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "Sample Name", format: :json, for_autocomplete: true}
    assert_response :success
    assert_equal_unordered [], assigns(:users)
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [], JSON.parse(@response.body)
  end

  def test_autocomplete_user_name
    current_user_is users(:f_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "Mentor Studenter", format: :json, for_autocomplete: true, no_email: true}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["Mentor Studenter"], JSON.parse(@response.body)
    assert_equal_unordered [users(:f_mentor_student)].collect(&:id), assigns(:users).collect(&:id)
  end

  def test_autocomplete_user_name_for_students
    current_user_is users(:f_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "Mentor Studenter", role: RoleConstants::STUDENT_NAME, format: :json, for_autocomplete: true}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["Mentor Studenter <mentrostud@example.com>"], JSON.parse(@response.body)
    assert_equal_unordered [users(:f_mentor_student)].collect(&:id), assigns(:users).collect(&:id)
  end

  def test_autocomplete_name_with_accents
    members(:f_student).update_attributes(first_name: "Chloé")
    members(:f_mentor).update_attributes(first_name: "Chloe")
    reindex_documents(updated: members(:f_student).users + members(:f_mentor).users)

    current_user_is :f_admin
    get :auto_complete_for_name, xhr: true, params: { search: "Chloe", format: :json, for_autocomplete: true}
    assert_response :success
    assert_equal_unordered ["Chloé example <rahim@example.com>", "Chloe name <robert@example.com>"], JSON.parse(@response.body)
  end

  def test_autocomplete_user_name_for_students_no_result_case
    current_user_is users(:f_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "#{users(:f_mentor).name}", role: RoleConstants::STUDENT_NAME, format: :json, for_autocomplete: true}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [], JSON.parse(@response.body)
    assert_equal_unordered [], assigns(:users)
  end

  def test_autocomplete_user_name_for_mentors
    current_user_is users(:f_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "Mentor Studenter", role: RoleConstants::MENTOR_NAME, format: :json, for_autocomplete: true}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered ["Mentor Studenter <mentrostud@example.com>"], JSON.parse(@response.body)
    assert_equal_unordered [users(:f_mentor_student)].collect(&:id), assigns(:users).collect(&:id)
  end

  def test_autocomplete_user_name_for_mentors_drafts
    current_user_is users(:f_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "Draft Mentor", role: RoleConstants::MENTOR_NAME, format: :json, for_autocomplete: true}
    assert_response :success
    assert assigns(:users).empty?
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [], JSON.parse(@response.body)
  end

  def test_autocomplete_user_name_for_mentors_no_result_case
    current_user_is users(:f_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "#{users(:f_student).name}", role: RoleConstants::MENTOR_NAME, format: :json, for_autocomplete: true}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [], JSON.parse(@response.body)
    assert_equal_unordered [], assigns(:users)
  end

  def test_autocomplete_users_show_mentors_false
    student = users(:f_student)
    current_user_is student
    student.roles.first.remove_permission("view_mentors")
    @controller.stubs(:check_access_auto_complete?).returns(true)
    get :auto_complete_for_name, xhr: true, params: { search: "Mentor Studenter", role: RoleConstants::MENTOR_NAME, preferred: "true", format: :json}
    assert_response :success
    assert_equal_unordered [], assigns(:users)
    @response.stubs(:content_type).returns "application/json"
    expected = {"render_html"=>"No Results Found"}
    assert_equal expected, JSON.parse(@response.body)
  end

  def test_autocomplete_for_suspended_mentors
    current_user_is users(:psg_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "inactive", role: RoleConstants::MENTOR_NAME, show_all_users: "true",  for_autocomplete: true, format: :json}
    assert_response :success

    assert_equal_unordered [users(:inactive_user)].collect(&:id), assigns(:users).collect(&:id)
  end

  def test_autocomplete_user_name_multi_complete
    current_user_is users(:f_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "Mentor Studenter", multi_complete: "true", format: :json}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [users(:f_mentor_student)].collect(&:id), assigns(:users).collect(&:id)
  end

  def test_autocomplete_user_name_multi_complete_for_connections
    current_user_is users(:f_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "Good unique", multi_complete: "true", connections: "true", format: :json}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [users(:f_mentor)].collect(&:id), assigns(:users).collect(&:id)
    assert_equal_unordered [groups(:mygroup)], assigns(:groups)
  end

  def test_autocomplete_user_name_for_dormant_member_in_other_cases
    current_user_is users(:no_subdomain_admin)

    get :auto_complete_for_name, xhr: true, params: { search: "Dor", format: :json}
    assert_response :success
    assert_equal [], assigns(:users).to_a
    assert_equal [], assigns(:members).to_a
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [], JSON.parse(@response.body)
  end

  def test_auto_complete_for_name_for_preferred_mentor_by_student
    current_program_is :moderated_program
    current_user_is :moderated_student
    get :auto_complete_for_name, xhr: true, params: { search: "mentor", preferred: true, format: :json}
    assert_response :success
    assert assigns(:is_preferred_request)
    assert_equal_unordered [users(:moderated_mentor)], assigns(:users).to_a
  end

  def test_auto_complete_for_name_for_preferred_mentor_by_mentor
    current_program_is :moderated_program
    current_member_is :moderated_mentor
    assert_permission_denied do
      get :auto_complete_for_name, xhr: true, params: { search: "mentor/", preferred: true, format: :json}
    end
  end

  def test_auto_complete_for_name_for_program_event
    current_user_is users(:f_admin)

    event = program_events(:birthday_party)
    invited_users = event.program_event_users.map(&:user)
    post :auto_complete_for_name, xhr: true, params: { search: invited_users.first.name(name_only: true), program_event_users: invited_users.map(&:id).join(","), format: :json, autocomplete: true, no_email: true}
    assert_response :success
    assert assigns(:program_event_users)
    assert_equal_unordered [invited_users.first], assigns(:users).to_a
    # Not in the event list
    post :auto_complete_for_name, xhr: true, params: { search: invited_users.first.name(name_only: true), program_event_users: "2", format: :json}
    assert_response :success
    assert assigns(:program_event_users)
    assert_blank assigns(:users)
  end

  def test_auto_complete_for_name_for_program_event_when_program_events_not_enabled
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_EVENTS, false)
    assert_permission_denied do
      post :auto_complete_for_name, xhr: true, params: { search: "mentor", program_event_users: "1", format: :json}
    end
  end

  def test_auto_complete_for_name_for_owner
    current_user_is :f_mentor

    assert_permission_denied do
      get :auto_complete_for_name, xhr: true, params: { search: "mentor/", format: :json}
    end
    groups(:mygroup).membership_of(users(:f_mentor)).update_attributes!(owner: true)

    get :auto_complete_for_name, xhr: true, params: { search: "Good unique", format: :json}
    assert_response :success
    assert_equal_unordered [users(:f_mentor)].collect(&:id), assigns(:users).collect(&:id)
  end

  def test_auto_complete_for_name_for_preferred_mentor_by_student_without_preferred
    current_program_is :moderated_program
    current_user_is :moderated_student
    assert_permission_denied do
      get :auto_complete_for_name, xhr: true, params: { search: "mentor/", format: :json}
    end
  end

  def test_auto_complete_for_filters
    current_user_is users(:f_admin)

    get :auto_complete_for_name, xhr: true, params: { format: :json, "filter"=>{"filters"=>{"0"=>{"field"=>"first_name", "operator"=>"startswith", "value"=>"pen"}}}}
    assert_equal_unordered [{"first_name"=> members(:pending_user).first_name}], JSON.parse(response.body)

    get :auto_complete_for_name, xhr: true, params: { format: :json, "filter"=>{"filters"=>{"0"=>{"field"=>"last_name", "operator"=>"startswith", "value"=>"use"}}}}
    assert_equal_unordered [{"last_name"=> members(:pending_user).last_name}], [JSON.parse(response.body).first]

    get :auto_complete_for_name, xhr: true, params: { format: :json, "filter"=>{"filters"=>{"0"=>{"field"=>"email", "operator"=>"startswith", "value"=>"pend"}}}}
    assert_equal_unordered [{"email"=> members(:pending_user).email}], JSON.parse(response.body)
    # Should not include other program members
    get :auto_complete_for_name, xhr: true, params: { format: :json, "filter"=>{"filters"=>{"0"=>{"field"=>"last_name", "operator"=>"startswith", "value"=>"Vija"}}}}
    assert JSON.parse(response.body).blank?

    get :auto_complete_for_name, xhr: true, params: { format: :json, "filter"=>{"filters"=>{"0"=>{"field"=>"password", "operator"=>"startswith", "value"=>"pend"}}}}
    assert JSON.parse(response.body).blank?
  end

  def test_access_to_secure_domain_with_parent_session_redirects_to_home_program
    current_subdomain_is SECURE_SUBDOMAIN
    mock_parent_session(:org_custom_domain, 'abcd')
    get :index
    assert_redirected_to "http://mentor.customtest.com/users"
  end

  def test_hide_item_with_nested_key
    current_user_is :f_student
    @request.session[UsersController::SessionHidingKey::MENTORING_PERIOD_NOTICE] = {}

    assert !@request.session[UsersController::SessionHidingKey::MENTORING_PERIOD_NOTICE]["#{groups(:mygroup).id}"]
    post :hide_item, xhr: true, params: { item_key: UsersController::SessionHidingKey::MENTORING_PERIOD_NOTICE, nested_item_key: groups(:mygroup).id}
    assert @request.session[UsersController::SessionHidingKey::MENTORING_PERIOD_NOTICE]["#{groups(:mygroup).id}"]
  end

  def test_hide_item_forever
    current_user_is :f_student

    assert_false users(:f_student).hide_profile_completion_bar?
    post :hide_item, xhr: true, params: { item_key: UsersController::SessionHidingKey::PROFILE_COMPLETE_SIDEBAR, hide_forever: true}
    assert users(:f_student).reload.hide_profile_completion_bar?
  end

  def test_work_on_behalf_without_permissions
    current_user_is :f_mentor
    assert !users(:f_mentor).can_work_on_behalf?
    assert_permission_denied do
      post :work_on_behalf, params: { id: users(:f_mentor).id}
    end
  end

  def test_work_on_behalf_with_feature_enabled
    programs(:org_primary).enable_feature(FeatureName::WORK_ON_BEHALF)
    current_user_is :f_student
    add_role_permission(fetch_role(:albers, :student), 'work_on_behalf')
    assert users(:f_student).can_work_on_behalf?

    post :work_on_behalf, params: { id: users(:f_mentor).id}
    assert_equal users(:f_mentor), assigns(:current_user)
    assert_equal members(:f_student), assigns(:current_member)
    assert_equal users(:f_mentor).member_id, @request.session[:work_on_behalf_member]
    assert_equal users(:f_mentor).id, @request.session[:work_on_behalf_user]
    assert_redirected_to root_path
  end

  def test_exit_work_on_behalf
    current_user_is :robert
    add_role_permission(fetch_role(:albers, :mentor), 'work_on_behalf')
    assert users(:robert).can_work_on_behalf?
    programs(:org_primary).enable_feature(FeatureName::WORK_ON_BEHALF)

    post :work_on_behalf, params: { id: users(:f_mentor).id}
    # Chronus user alone should be robert. Member and User should be f_mentor.
    assert_equal users(:f_mentor), assigns(:current_user)
    assert_equal members(:robert), assigns(:current_member)
    assert_equal users(:f_mentor).member_id, @request.session[:work_on_behalf_member]
    assert_equal users(:f_mentor).id, @request.session[:work_on_behalf_user]
    assert_redirected_to root_path

    post :exit_wob
    assert_equal users(:robert), assigns(:current_user)
    assert_equal members(:robert), assigns(:current_member)
    assert_nil @request.session[:work_on_behalf_member]
    assert_nil @request.session[:work_on_behalf_user]
    assert_redirected_to root_path
  end

  def test_exit_work_on_behalf_for_pending_user
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::WORK_ON_BEHALF)
    @request.session[:work_on_behalf_member]  = users(:pending_user).member.id
    @request.session[:work_on_behalf_user]  = users(:pending_user).id
    current_member_is :f_admin
    post :exit_wob
    assert_equal users(:f_admin), assigns(:current_user)
    assert_nil @request.session[:work_on_behalf_member]
    assert_nil @request.session[:work_on_behalf_user]
    assert_redirected_to root_path
  end

  def test_work_on_behalf_for_pending_user
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::WORK_ON_BEHALF)
    user = users(:pending_user)
    member = user.member
    member.terms_and_conditions_accepted = nil
    member.save!
    @request.session[:work_on_behalf_member]  = member.id
    @request.session[:work_on_behalf_user]  = user.id
    post :work_on_behalf, params: { id: user.id}
    assert_equal user, assigns(:current_user)
    assert_equal members(:f_admin), assigns(:current_member)
    assert_redirected_to edit_member_path(member, first_visit: true, landing_directly: 'true', ei_src: EngagementIndex::Src::EditProfile::PROFILE_PENDING)
  end

  def test_admin_clicks_program_overview_in_wob_mode
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::WORK_ON_BEHALF)
    @request.session[:work_on_behalf_user]  = users(:f_mentor).id
    @request.session[:work_on_behalf_member]  = users(:f_mentor).member_id
    post :exit_wob, params: { src: "pages"}
    assert_redirected_to root_organization_path
  end

  def test_change_user_state_permission_denied
    user = users(:f_student)

    current_user_is :f_mentor
    assert_permission_denied do
      post :change_user_state, params: { id: user.id, new_state: User::Status::SUSPENDED, state_change_reason: "Reason"}
    end
    assert_false user.reload.suspended?
  end

  def test_change_user_state_to_suspended_invalid_params
    user = users(:f_mentor)

    current_user_is :f_admin
    post :change_user_state, params: { id: user.id, new_state: User::Status::SUSPENDED, state_change_reason: ""}
    assert_false user.reload.suspended?
  end

  def test_change_user_state_to_suspended_expects_can_remove_or_suspend
    user = users(:f_mentor)

    User.any_instance.expects(:can_remove_or_suspend?).returns(false)
    current_user_is :f_admin
    assert_permission_denied do
      post :change_user_state, params: { id: user.id, new_state: User::Status::SUSPENDED, state_change_reason: "Reason"}
    end
    assert_false user.reload.suspended?
  end

  def test_change_user_state_to_suspended
    user = users(:f_mentor)
    admin = users(:f_admin)
    User.any_instance.expects(:close_pending_received_requests_and_offers).once

    current_user_is :f_admin
    assert_emails 1 do
      post :change_user_state, params: { id: user.id, new_state: User::Status::SUSPENDED, state_change_reason: "Reason"}
    end
    assert_redirected_to member_path(user.member)
    assert_equal "#{user.name}'s membership has been deactivated from this program.", flash[:notice]
    assert user.reload.suspended?
    assert_equal admin, user.state_changer
    assert_equal "Reason", user.state_change_reason
  end

  def test_change_user_state_reactivation
    user = users(:f_mentor)
    admin_1 = users(:f_admin)
    admin_2 = users(:ram)
    user.suspend_from_program!(admin_2, "Reason")
    assert_equal admin_2, user.state_changer

    current_user_is admin_1
    post :change_user_state, params: { id: user.id, new_state: User::Status::ACTIVE}
    assert_redirected_to member_path(user.member)
    assert_equal "#{user.name}'s membership has been reactivated in this program.", flash[:notice]
    assert user.reload.active?
    assert_equal admin_1, user.state_changer
  end

  def test_destroy_permission_denied
    current_user_is :f_mentor
    assert_no_difference "User.count" do
      assert_permission_denied do
        post :destroy, params: { id: users(:f_student).id}
      end
    end
  end

  def test_destroy_cannot_remove_self
    admin = users(:f_admin)

    current_user_is admin
    assert_no_difference "User.count" do
      assert_permission_denied do
        post :destroy, params: { id: admin.id}
      end
    end
  end

  def test_destroy_expects_can_remove_or_suspend
    admin = users(:f_admin)
    mentoring_connections_term = admin.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase

    User.any_instance.expects(:can_remove_or_suspend?).returns(true)
    current_user_is admin
    assert_difference "User.count", -1 do
      post :destroy, params: { id: admin.id}
    end
    assert_equal "#{admin.name}'s profile, any #{mentoring_connections_term} and other contributions have been removed", flash[:notice]
    assert_redirected_to root_path
  end

  def test_change_role_by_non_admin
    current_user_is :f_mentor

    assert_permission_denied do
      post :change_roles, params: { id: users(:f_mentor).id}
    end
  end

  def test_change_role_succeeds
    current_user_is :f_admin

    mentor = users(:f_mentor)
    assert_emails 2 do
      post :change_roles, params: { id: mentor.id, role_names_str: RoleConstants::STUDENT_NAME}
    end
    assert_redirected_to member_path(mentor.member)
    assert_match "The roles have been successfully updated", flash[:notice]
    assert mentor.reload.is_student?
    assert_nil RecentActivity.last.message
  end

  def test_change_role_with_message_succeeds
    current_user_is :f_admin

    mentor = users(:f_mentor)
    assert_emails 1 do
      assert_difference('RecentActivity.count') do
        post :change_roles, params: { id: mentor.id, role_names_str: RoleConstants::MENTOR_NAME+','+RoleConstants::STUDENT_NAME, role_change_reason: 'Test Reason'}
      end
    end
    assert_redirected_to member_path(mentor.member)
    assert_match "The roles have been successfully updated", flash[:notice]
    assert mentor.reload.is_student?
    assert_equal "Test Reason", RecentActivity.last.message
  end

  def test_change_role_fails
    current_user_is :f_admin

    mentor = users(:f_mentor)
    assert_emails 0 do
      post :change_roles, params: { id: mentor.id, role_names_str: RoleConstants::MENTOR_NAME}
    end
    assert_redirected_to member_path(mentor.member)
    assert_match "There were problems updating the role. Please refresh the page and try again.", flash[:error]
    assert mentor.reload.is_mentor_only?
  end

  def test_student_should_not_see_mentees_count_in_matching_by_admin_alone
    current_user_is :no_mreq_student
    program = programs(:no_mentor_request_program)
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::NONE)

    src = EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, items_per_page: 30}
    assert_response :success
    assert_no_select ".ct_mentees_count"
  end

  def test_student_should_not_mentees_count_if_program_is_not_matching_by_admin_alone
    current_user_is :f_student
    program = programs(:albers)

    get :index, xhr: true, params: { items_per_page: 30, filter: [UserSearch::SHOW_NO_MATCH_FILTER]}
    assert_response :success
    assert_equal response.body.scan(/.ct_mentees_count/).size, 22
  end

  def test_mentor_should_see_mentors_count_on_students_listing_page_if_offer_mentoring_is_enabled
    current_user_is :f_mentor
    mentor= users(:f_mentor)
    assert_false mentor.can_offer_mentoring?

    programs(:albers).organization.enable_feature(FeatureName::OFFER_MENTORING)
    assert_equal RoleConstants::MENTOR_NAME, RolePermission.last.role.name
    assert_equal "offer_mentoring", RolePermission.last.permission.name
    assert mentor.reload.can_offer_mentoring?

    src = EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).never

    get :index, params: { src: src, items_per_page: 30, view: RoleConstants::STUDENTS_NAME}
    assert_response :success
    assert_select ".ct_mentors_count", {count: 21}

    assert_equal mentor.students, assigns(:mentee_groups_map).keys
    assert_equal mentor.groups, assigns(:mentee_groups_map).values.flatten
    assert_equal mentor.groups, assigns(:existing_connections_of_mentor)
    assert_equal programs(:albers).role_questions_last_update_timestamp(RoleConstants::STUDENT_NAME), assigns(:profile_last_updated_at)

    assert assigns(:viewer_can_offer)
    assert_false assigns(:viewer_can_find_mentor)
    assert_false assigns(:offer_pending).present?
    assert_false assigns(:student_draft_count).present?
    assert_false assigns(:mentors_list).present?

    assert assigns(:mentors_count).present?
    student_user = users(:student_2)
    assert_equal student_user.mentors.size, assigns(:mentors_count)[student_user.id]
    assert_false assigns(:students_with_no_limit).present?
    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::STUDENT_NAME), assigns(:student_required_questions)
  end

  def test_mentor_on_students_listing_page_with_offer_mentoring_enabled_and_needs_acceptance
    current_user_is :f_mentor
    mentor = users(:f_mentor)
    mentee = users(:student_2)
    program = programs(:albers)
    assert_false mentor.can_offer_mentoring?

    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attributes(mentor_offer_needs_acceptance: true)

    assert_equal RoleConstants::MENTOR_NAME, RolePermission.last.role.name
    assert_equal "offer_mentoring", RolePermission.last.permission.name
    assert mentor.reload.can_offer_mentoring?
    mentor_offer = create_mentor_offer(mentor: mentor, student: mentee)

    src = EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).never

    get :index, params: { src: src, items_per_page: 30, view: RoleConstants::STUDENTS_NAME}
    assert_response :success

    assert_equal mentor.students, assigns(:mentee_groups_map).keys
    assert_equal mentor.groups, assigns(:mentee_groups_map).values.flatten
    assert_equal mentor.groups, assigns(:existing_connections_of_mentor)
    assert_equal programs(:albers).role_questions_last_update_timestamp(RoleConstants::STUDENT_NAME), assigns(:profile_last_updated_at)

    assert assigns(:viewer_can_offer)
    assert_false assigns(:viewer_can_find_mentor)
    assert_false assigns(:student_draft_count).present?
    assert_false assigns(:mentors_list).present?
    assert_equal [mentee.id], assigns(:offer_pending).keys

    assert assigns(:mentors_count).present?
    student_user = users(:student_2)
    assert_equal student_user.mentors.size, assigns(:mentors_count)[student_user.id]
    assert_false assigns(:students_with_no_limit).present?
    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::STUDENT_NAME), assigns(:student_required_questions)
  end

  def test_admin_on_students_listing_page_with_offer_mentoring_enabled_and_needs_acceptance
    current_user_is :f_admin
    program = programs(:albers)

    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attributes({mentor_offer_needs_acceptance: true, max_connections_for_mentee: 1})

    assert_equal RoleConstants::MENTOR_NAME, RolePermission.last.role.name
    assert_equal "offer_mentoring", RolePermission.last.permission.name

    get :index, params: { items_per_page: 30, view: RoleConstants::STUDENTS_NAME}
    assert_response :success

    assert_false assigns(:mentee_groups_map).present?
    assert_false assigns(:existing_connections_of_mentor).present?
    assert_equal programs(:albers).role_questions_last_update_timestamp(RoleConstants::STUDENT_NAME), assigns(:profile_last_updated_at)

    assert assigns(:viewer_can_find_mentor)
    assert_false assigns(:viewer_can_offer)
    assert_false assigns(:offer_pending).present?
    assert_false assigns(:mentors_count).present?

    assert_equal program.groups.drafted.collect(&:students).flatten.collect(&:id), assigns(:student_draft_count).keys
    assert_equal [1], assigns(:student_draft_count).values.flatten.uniq # every one has 1 draft connections

    assert assigns(:mentors_list).present?
    student_user = users(:student_2)
    assert_equal_unordered student_user.mentors.collect(&:id), assigns(:mentors_list)[student_user.id].collect(&:id)
    assert assigns(:students_with_no_limit).present?

    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::STUDENT_NAME), assigns(:student_required_questions)
  end

  def test_student_on_students_listing_page_with_offer_mentoring_enabled_and_needs_acceptance
    current_user_is :f_student
    program = programs(:albers)

    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attributes({mentor_offer_needs_acceptance: true, max_connections_for_mentee: 100})

    assert_equal RoleConstants::MENTOR_NAME, RolePermission.last.role.name
    assert_equal "offer_mentoring", RolePermission.last.permission.name

    get :index, params: { items_per_page: 30, view: RoleConstants::STUDENTS_NAME}
    assert_response :success

    assert_false assigns(:mentee_groups_map).present?
    assert_false assigns(:existing_connections_of_mentor).present?
    assert_equal programs(:albers).role_questions_last_update_timestamp(RoleConstants::STUDENT_NAME), assigns(:profile_last_updated_at)

    assert_false assigns(:viewer_can_find_mentor)
    assert_false assigns(:viewer_can_offer)
    assert_false assigns(:offer_pending).present?
    assert_false assigns(:mentors_count).present?

    assert_false assigns(:student_draft_count).present?
    assert_false assigns(:mentors_list).present?
    assert_false assigns(:students_with_no_limit).present?
    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::STUDENT_NAME), assigns(:student_required_questions)
  end

  def test_mentor_should_not_see_mentors_count_on_students_listing_page_if_offer_mentoring_is_disabled
    current_user_is :f_mentor
    mentor= users(:f_mentor)
    assert_false mentor.can_offer_mentoring?

    get :index, params: { items_per_page: 30}
    assert_response :success
    assert_no_select ".ct_mentors_count"

    assert_false assigns(:mentee_groups_map).present?
    assert_false assigns(:existing_connections_of_mentor).present?
    assert_equal programs(:albers).role_questions_last_update_timestamp(RoleConstants::MENTOR_NAME), assigns(:profile_last_updated_at)

    mentor_user = users(:f_mentor)
    not_requestable_mentor = users(:not_requestable_mentor)
    mentor_1 = users(:mentor_1)
    assert_false assigns(:can_render_calendar_ui)
    assert_equal_unordered assigns(:user_ids)-[not_requestable_mentor.id, mentor_user.id, users(:robert).id], assigns(:mentors_with_slots).keys
    assert_equal mentor_1.students(:active_or_drafted).size, assigns(:active_or_drafted_students_count)[mentor_1.id]
    assert_false assigns(:sent_mentor_offers_pending).present?

    assert_nil assigns(:mentor_draft_count)
    assert_nil assigns(:students_count)
    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::MENTOR_NAME), assigns(:mentor_required_questions)
  end

  def test_admin_should_not_see_mentors_count_on_students_listing_page
    current_user_is :f_admin

    get :index, params: { items_per_page: 30}
    assert_response :success
    assert_no_select ".ct_mentors_count"

    assert_false assigns(:mentee_groups_map).present?
    assert_false assigns(:existing_connections_of_mentor).present?
    assert_equal programs(:albers).role_questions_last_update_timestamp(RoleConstants::MENTOR_NAME), assigns(:profile_last_updated_at)

    mentor_user = users(:f_mentor)
    not_requestable_mentor = users(:not_requestable_mentor)
    mentor_1 = users(:mentor_1)
    assert_false assigns(:can_render_calendar_ui)
    assert_equal_unordered assigns(:user_ids)-[not_requestable_mentor.id, mentor_user.id, users(:robert).id], assigns(:mentors_with_slots).keys
    assert_equal mentor_1.students(:active_or_drafted).size, assigns(:active_or_drafted_students_count)[mentor_1.id]
    assert_false assigns(:sent_mentor_offers_pending).present?

    assert_not_nil assigns(:mentor_draft_count)
    assert_nil assigns(:students_count)
    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::MENTOR_NAME), assigns(:mentor_required_questions)
  end

  def test_sorting_by_name_in_the_user_index_page
    assert_equal  Program::SortUsersBy::FULL_NAME, programs(:ceg).sort_users_by
    current_user_is users(:ceg_admin)
    m1 = users(:f_mentor_ceg)
    m2 = users(:sarat_mentor_ceg)
    m3 = users(:ceg_mentor)
    get :index, params: { filter: "all"}
    users_4 = assigns(:users)
    assert_equal [m1, m3, m2].collect(&:id), users_4.collect(&:id)

    get :index, params: { filter: "all", sort: "name", order: "desc"}
    users_4 = assigns(:users)
    assert_equal [m2, m3, m1].collect(&:id), users_4.collect(&:id)
  end

  def test_sorting_by_name_in_the_user_index_page_with_calendar_filters
    assert_equal  Program::SortUsersBy::FULL_NAME, programs(:moderated_program).sort_users_by
    programs(:moderated_program).enable_feature(FeatureName::CALENDAR)
    m1 = users(:moderated_mentor)
    m2 = users(:f_onetime_mode_mentor)
    pq = profile_questions(:profile_questions_3)
    current_program_is :moderated_program
    current_user_is :moderated_student

    src = EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once

  get :index, params: { src: src,filter: ["available", UsersIndexFilters::Values::CALENDAR_AVAILABILITY], sort: "name", order: "desc"}
    assert_response :success
    users_2 = assigns(:users)
    assert_equal [m1, m2].collect(&:id), users_2.collect(&:id)


    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, filter: ["available", UsersIndexFilters::Values::CALENDAR_AVAILABILITY], sort: "name", order: "asc"}
    assert_response :success
    users_2 = assigns(:users)
    assert_equal [m2, m1].collect(&:id), users_2.collect(&:id)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::BROWSE_MENTORS, {context_place: src}).once
    get :index, params: { src: src, filter: ["available", UsersIndexFilters::Values::CALENDAR_AVAILABILITY], items_per_page: 50, sf: {pq: {pq.id.to_s => "some text that is not in locations"}}}
    assert_response :success
    assert_equal [], assigns(:users)
    assert_false assigns(:program_only_has_general_availabilty_meeting_filter)
  end

  def test_sorting_by_created_at_in_the_user_index_page
    current_user_is users(:ceg_admin)

    @controller.expects(:users_sort_order_string).with("created_at", "asc", users(:ceg_admin).program).returns("created_at", "asc")
    get :index, params: { filter: "all", sort: "created_at", order: "asc"}
    assert_response :success

    @controller.expects(:users_sort_order_string).with("created_at", "desc", users(:ceg_admin).program).returns("created_at", "desc")
    get :index, params: { filter: "all", sort: "created_at", order: "desc"}
    assert_response :success
  end

  def test_sorting_by_last_seen_at_in_the_user_index_page
    current_user_is users(:ceg_admin)

    @controller.expects(:users_sort_order_string).with("last_seen_at", "asc", users(:ceg_admin).program).returns("last_seen_at", "asc")
    get :index, params: { filter: "all", sort: "last_seen_at", order: "asc"}
    assert_response :success

    @controller.expects(:users_sort_order_string).with("last_seen_at", "desc", users(:ceg_admin).program).returns("last_seen_at", "desc")
    get :index, params: { filter: "all", sort: "last_seen_at", order: "desc"}
    assert_response :success
  end

  def test_number_of_items_per_page_5
    current_user_is users(:ram)
    get :index, params: { filter: "all", items_per_page: 5}
    users_1 = assigns(:users)
    assert_equal users_1.size, 5
  end

  def test_number_of_items_per_page_10
    current_user_is users(:ram)
    get :index, params: { filter: "all", items_per_page: 10, view: RoleConstants::STUDENTS_NAME}
    users_2 = assigns(:users)
    assert_equal users_2.size, 10
  end

  def test_number_of_items_per_page_20
    current_user_is users(:ram)
    get :index, params: { filter: "all", items_per_page: 20, view: RoleConstants::STUDENTS_NAME}
    users_3 = assigns(:users)
    assert_equal users_3.size, 20
  end

  def test_admin_can_set_items_per_page_of_students_list
    current_user_is users(:f_admin)
    get :index, params: { filter: "all", view: RoleConstants::STUDENTS_NAME}
    assert_select "div.items_per_page"
  end

  def test_mentor_cannot_set_items_per_page_of_students_list
    current_user_is users(:f_mentor)
    get :index, params: { filter: "all", view: RoleConstants::STUDENTS_NAME}
    assert_no_select "div.items_per_page"
  end

  def test_student_cannot_set_items_per_page_of_students_list
    current_user_is users(:f_student)
    get :index, params: { filter: "all", view: RoleConstants::STUDENTS_NAME}
    assert_no_select "div.items_per_page"
  end

  def test_admin_can_set_items_per_page_of_mentors_list
    current_user_is users(:f_admin)
    get :index, params: { filter: "all"}
    assert_select "div.items_per_page"
  end

  def test_mentor_cannot_set_items_per_page_of_mentors_list
    current_user_is users(:f_mentor)
    get :index, params: { filter: "all"}
    assert_no_select "div.items_per_page"
  end

  def test_student_cannot_set_items_per_page_of_mentors_list
    current_user_is users(:f_student)
    get :index, params: { filter: "all"}
    assert_no_select "div.items_per_page"
  end

  def test_listing_page_with_explicit_user_preferences
    user = users(:f_mentor_student)
    current_user_is user
    get :index, params: {filter: "all", items_per_page: 40}
    assert_equal 21, assigns(:users).size

    qc1 = question_choices(:single_choice_q_1)
    explicit_preference = QueryHelper::Filter.simple_bool_should([{constant_score: {filter: {terms: {profile_answer_choices: [qc1.id]}}, boost: 3}}])
    User.any_instance.stubs(:explicit_preferences_configured?).returns(true)
    User.any_instance.stubs(:get_explicit_user_preferences_should_query).returns(explicit_preference)
    get :index, params: {filter: "all", items_per_page: 40}
    assert_equal 1, assigns(:users).size
    assert_equal UserSearch::SortParam::PREFERENCE, assigns(:sort_field)
    assert assigns(:is_sort_by_preference)
    assert_equal [users(:f_mentor)].collect(&:id), assigns(:users).collect(&:id)

    qc2 = question_choices(:single_choice_q_3)
    explicit_preference = QueryHelper::Filter.simple_bool_should([{constant_score: {filter: {terms: {profile_answer_choices: [qc1.id]}}, boost: 3}}, {constant_score: {filter: {terms: {profile_answer_choices: [qc2.id]}}, boost: 1}}])
    User.any_instance.stubs(:get_explicit_user_preferences_should_query).returns(explicit_preference)
    get :index, params: {filter: "all", items_per_page: 40}
    assert_equal 2, assigns(:users).size
    assert_equal users(:f_mentor, :robert).collect(&:id), assigns(:users).collect(&:id)

    get :index, params: {filter: "all", items_per_page: 40, sort: "name", order: "desc"}
    assert_equal users(:robert, :f_mentor).collect(&:id), assigns(:users).collect(&:id)

    get :index, params: {filter: "all", items_per_page: 40, sf: {quick_search: "robert"}, sort: UserSearch::SortParam::RELEVANCE, order: "desc"}
    assert_equal [users(:robert)].collect(&:id), assigns(:users).collect(&:id)
  end

  #-----------------------------------------------------------------------------
  # ORGANIZATION view
  #-----------------------------------------------------------------------------

  def test_mentors_listing_for_organization_admin
    current_member_is members(:f_admin)
    assert members(:f_admin).admin?
    get :index
    assert_redirected_to programs_list_path
  end

  def test_students_listing_for_organization_admin
    current_member_is members(:f_admin)
    assert members(:f_admin).admin?
    get :index, params: { view: 'students'}
    assert_redirected_to programs_list_path
  end

  def test_show_add_mentees_directly_for_user_who_can_add_student_profiles_directly
    current_user_is users(:f_admin)
    assert users(:f_admin).can_add_non_admin_profiles?
    get :index, params: { view: "students"}
    assert_response :success

    assert_select 'div.btn-group' do
      assert_select 'a[href=?]', new_user_path(role: RoleConstants::STUDENT_NAME)
    end
  end

  def test_should_not_show_add_mentees_directly_for_mentor_who_cannot_add_student_profiles_directly
    current_user_is users(:f_mentor)
    assert_false users(:f_mentor).can_add_non_admin_profiles?
    get :index, params: { view: "students"}
    assert_response :success
    assert_select 'div#inner_content' do
      assert_select 'a[href=?]', new_user_path(role: RoleConstants::STUDENT_NAME), count: 0
    end
  end

  def test_should_not_show_add_mentees_directly_for_user_who_cannot_add_student_profiles_directly
    current_user_is users(:f_student)
    assert_false users(:f_student).can_add_non_admin_profiles?
    get :index, params: { view: "students"}
    assert_response :success
    assert_select 'div#inner_content' do
      assert_select 'div#action_2', count: 0
    end
  end

  def test_matches_for_student_permissions
    current_user_is :f_mentor

    assert_permission_denied do
      get :matches_for_student
    end
  end

  def test_matches_for_student_with_no_params
    current_user_is :f_admin

    get :matches_for_student
    assert_response :success
    assert_equal users(:f_admin), assigns(:current_user)
    assert_nil assigns(:student)
    assert_nil assigns(:student_name_with_email)
    assert_no_select "div#mentors_filters"
  end

  def test_matches_for_student_with_invalid_params
    current_user_is :f_admin

    get :matches_for_student, params: { student_name: "abc"}
    assert_response :success
    assert_nil assigns(:student)
    assert_equal "abc", assigns(:student_name_with_email)
    assert_equal "The #{assigns(:_mentee)} with the given name does not exist. Please enter a valid #{assigns(:_mentee)} name", flash[:error]
    assert_no_select "div#mentors_filters"
  end

  def test_matches_for_student_with_valid_params
    current_user_is :f_admin
    student = users(:mkr_student)
    organization = programs(:org_primary)
    program = programs(:albers)
    mentor_profile_question = create_profile_question(organization: organization)
    student_profile_question = create_profile_question(organization: organization)
    mentor_role_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: mentor_profile_question, in_summary: true)
    student_role_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: student_profile_question, in_summary: true)
    student_role_question.update_attribute(:updated_at, Time.now + 10.hours)

    get :matches_for_student, params: { student_name: student.name_with_email}
    assert_response :success
    assert_equal users(:f_admin), assigns(:current_user)
    assert_equal student, assigns(:student)
    assert_equal student.name_with_email, assigns(:student_name_with_email)
    assert assigns(:filter_field).include? UsersIndexFilters::Values::AVAILABLE
    assert_equal RoleConstants::MENTOR_NAME, assigns(:role)
    assert_equal RoleConstants::ADMIN_NAME, assigns(:viewer_role)
    assert_false assigns(:users).empty?
    assert_false (assigns(:users) & student.mentors).any?
    assert_equal 1, assigns(:pagination_options)[:page]
    assert_equal 10, assigns(:pagination_options)[:per_page]
    assert assigns(:in_summary_questions).include?(mentor_role_question)
    assert_false assigns(:in_summary_questions).include?(student_role_question)
    assert assigns(:student_in_summary_questions).include?(student_role_question)
    assert_false assigns(:student_in_summary_questions).include?(mentor_role_question)
    assert_equal mentor_role_question.updated_at.to_i, assigns(:mentor_profile_last_updated_at)
    assert_equal student_role_question.updated_at.to_i, assigns(:student_profile_last_updated_at)
    assert_select "div#mentors_filters", count: 1
  end

  def test_mentees_connection_status_filter_for_program_with_enabled_ongoing_mentoring
    # mentee f_student which is not connected will not come in the result as ongoing mentoring is enabled

    # changing engagement type of program to career and ongoing based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)

    current_user_is :f_admin
    current_program_is :albers

    get :index, params: { view: RoleConstants::STUDENTS_NAME, filter: UsersIndexFilters::Values::CONNECTED}
    assert_false assigns(:users).include?(users(:f_student))
  end

  def test_mentees_connection_status_filter_for_program_with_disabled_ongoing_mentoring
    # mentee f_student which is not connected will also come in the result as ongoing mentoring is disabled
    current_user_is :f_admin
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    current_program_is :albers

    get :index, params: { view: RoleConstants::STUDENTS_NAME, filter: UsersIndexFilters::Values::CONNECTED}
    assert assigns(:users).include?(users(:f_student))
  end

  def test_mentors_available_filter_for_program_with_enabled_ongoing_mentoring
    # changing engagement type of program to career and ongoing based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)

    current_user_is :f_student
    current_program_is :albers

    users(:robert).update_attribute(:max_connections_limit, 1)

    get :index, params: { calendar_availability_default: false, filter: [UsersIndexFilters::Values::AVAILABLE]}
    assert_false assigns(:users).include?(users(:robert))
  end

  def test_matches_for_student_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_admin
    student = users(:mkr_student)
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_raise Authorization::PermissionDenied do
      get :matches_for_student, params: { student_name: student.name_with_email}
    end
  end

  def test_preset_defaults_search_and_filter_options_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_student
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    current_program_is :albers

    get :index
    assert_response :success
    assert_false assigns(:filter_field).include? UsersIndexFilters::Values::AVAILABLE
  end

  def test_preset_defaults_search_and_filter_options_for_program_with_enabled_ongoing_mentoring
    # changing engagement type of program to career and ongoing based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)

    current_user_is :f_student
    current_program_is :albers

    get :index
    assert_response :success
    assert assigns(:filter_field).include? UsersIndexFilters::Values::AVAILABLE
  end

  def test_matches_for_student_with_valid_params_js
    current_user_is :f_admin
    student = users(:mkr_student)

    get :matches_for_student, xhr: true, params: { student_name: student.name_with_email, page: 6, items_per_page: 5}
    assert_response :success
    assert_equal student, assigns(:student)
    assert_equal student.name_with_email, assigns(:student_name_with_email)
    assert_equal UsersIndexFilters::Values::ALL, assigns(:filter_field)

    assert_equal 5, assigns(:users).total_pages
    assert assigns(:users).empty?
    assert_equal '6', assigns(:pagination_options)[:page]
    assert_equal 5, assigns(:pagination_options)[:per_page]
  end

  #
  # As an admin when I try to find a match for a mentee(who is also a mentor),
  # I should not show the mentee(who is also the mentor) in the search results.
  #
  def test_matches_for_student_should_not_show_student_in_results
    current_user_is :f_admin

    student = users(:f_mentor_student)

    get :matches_for_student, params: { student_name: student.name_with_email, items_per_page: 50}
    assert_response :success
    assert_select "a#mentor_#{student.id}.nickname", text: student.name, count: 0
  end

  def test_matches_for_student_should_not_show_current_mentors_of_student
    current_user_is :f_admin

    student = users(:mkr_student)
    assert student.mentors.include?(users(:f_mentor))
    assert_false student.mentors.include?(users(:mentor_0))

    get :matches_for_student, params: { student_name: student.name_with_email, items_per_page: 50}
    assert_response :success
    assert_false assigns(:users).include?(users(:f_mentor))
    assert assigns(:users).include?(users(:mentor_0))
  end

  def test_matches_for_student_sorting
    current_user_is users(:f_admin)
    student = users(:f_student)
    get :matches_for_student, params: { student_name: student.name_with_email}
    assert_false assigns(:users).first == users(:requestable_mentor)
    assert_equal 'match', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
    get :matches_for_student, params: { student_name: student.name_with_email, sort: "name", order: "desc"}
    assert_equal users(:requestable_mentor), assigns(:users).first
    get :matches_for_student, params: { student_name: student.name_with_email, sort: "name", order: "asc"}
    assert_equal users(:ram), assigns(:users).first
  end

  def test_matches_for_student_status_filter
    current_user_is users(:f_admin)
    student = users(:f_student)
    get :matches_for_student, params: { student_name: student.name_with_email, filter: "all", items_per_page: 50}
    assert assigns(:users).include?(users(:not_requestable_mentor))

    get :matches_for_student, params: { student_name: student.name_with_email, filter: "available", items_per_page: 50}
    assert_false assigns(:users).include?(users(:not_requestable_mentor))
  end

  def test_matches_for_student_with_default_filter
    current_user_is :f_student
    get :index
    assert assigns(:filter_field).include? UsersIndexFilters::Values::AVAILABLE
    assert assigns(:my_filters).include?({label: 'Availability Status', reset_suffix: 'availability_status'})
    assert_false assigns(:users).include?(users(:not_requestable_mentor))
  end

  def test_matches_for_student_with_default_filter_when_calendar_feature_enabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    student = users(:f_student)
    mentor = users(:f_mentor_student)
    mentor.member.update_attributes!(will_set_availability_slots: true)
    current_user_is student
    mentor.member.mentoring_slots.destroy_all
    mentor.update_attribute(:max_connections_limit, 100)
    assert mentor.reload.cached_available_and_can_accept_request?
    program = mentor.program
    assert_false mentor.member.has_availability_between?(program, (Time.now).beginning_of_day, (Time.now + 30.days).end_of_day, student, {mentor_user: mentor})
    reindex_documents(updated: [student, mentor])
    get :index
    assert assigns(:filter_field).include? UsersIndexFilters::Values::AVAILABLE
    assert_false assigns(:filter_field).include? UsersIndexFilters::Values::CALENDAR_AVAILABILITY
    assert assigns(:my_filters).include?({label: 'Availability Status', reset_suffix: 'availability_status'})
    assert assigns(:users).include?(mentor)
  end

  def test_matches_for_student_search_name
    current_user_is users(:f_admin)
    student = users(:f_student)

    get :matches_for_student, params: { student_name: student.name_with_email, filter: ["all", UserSearch::SHOW_NO_MATCH_FILTER], items_per_page: 50, sf: {quick_search: "good unique"}}
    assert_equal [users(:f_mentor)], assigns(:users)

    get :matches_for_student, params: { student_name: student.name_with_email, filter: ["all", UserSearch::SHOW_NO_MATCH_FILTER], items_per_page: 50, sf: {quick_search: "svdaggzas"}}
    assert_equal [], assigns(:users)
  end

  def test_matches_for_student_profile_questions_filter
    current_user_is users(:f_admin)
    student = users(:f_student)
    pq = profile_questions(:experience_q)
    get :matches_for_student, params: { student_name: student.name_with_email, filter: ["all", UserSearch::SHOW_NO_MATCH_FILTER], items_per_page: 50, sf: {pq: {pq.id.to_s => "microsoft"}}}
    assert_equal [users(:f_mentor)], assigns(:users)

    get :matches_for_student, params: { student_name: student.name_with_email, filter: ["all", UserSearch::SHOW_NO_MATCH_FILTER], items_per_page: 50, sf: {pq: {pq.id.to_s => "some text that is not an experience"}}}
    assert_equal [], assigns(:users)
  end

  def test_matches_for_student_should_show_mentoring_connections_count_of_mentors
    current_user_is :f_admin
    student = users(:mkr_student)

    assert User.respond_to?(:get_availability_slots_for)
    User.expects(:get_availability_slots_for).returns({users(:mentor_0).id => 10, users(:mentor_1).id => 10})

    get :matches_for_student, params: { student_name: student.name_with_email}
    assert_response :success

    assert_equal 0, users(:mentor_0).mentoring_groups.active.count
    assert_equal 2, users(:mentor_1).mentoring_groups.active.count

    assert_select "div.user_#{users(:mentor_0).id}" do
      assert_select "span", text: "0 Ongoing Mentoring Connections"
    end
    assert_select "div.user_#{users(:mentor_1).id}" do
      assert_select "a", text: "2 Ongoing Mentoring Connections"
    end
  end

  def test_check_user_has_permission
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    assert_false users(:f_mentor).can_view_mentoring_calendar?

    current_user_is :f_mentor
    assert_permission_denied do
      get :mentoring_calendar
    end
  end

  def test_mentoring_calendar
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    assert users(:f_student).can_view_mentoring_calendar?

    st = (mentoring_slots(:f_mentor).start_time - 2.days)
    en = (mentoring_slots(:f_mentor).end_time + 2.days)

    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: st + 1.day, end_time: en-1.day)#general availability meeting
    current_user_is :f_student
    get :mentoring_calendar, xhr: true, params: { start: st.to_i, end: en.to_i}
    parmas = {"start"=>st.to_i.to_s, "end"=>en.to_i.to_s, "controller"=>"users", "action"=>"mentoring_calendar", "root"=>nil}
    assert_equal  parmas, assigns(:params)
    assert_false assigns(:filter_questions).collect(&:id).include?(programs(:org_primary).name_question.id)
    assert_mentoring_slots assigns(:availability).flatten, add_urls(members(:f_mentor).get_availability_slots(st, en, users(:f_student).program, true, 90, true, users(:f_student)))

    meets = []
    [members(:f_mentor), members(:not_requestable_mentor)].each do |m|
      meets << m.get_meeting_slots(Meeting.recurrent_meetings(m.meetings, {get_merged_list: true, start_time: st, end_time: en, get_occurrences_between_time: true}), members(:f_student).meetings.pluck(:id), members(:f_student))
    end
    assert_equal "Mentors", assigns(:user_reference_plural)
    assert_equal "Mentor",  assigns(:user_reference)
    assert_equal "mentors", assigns(:user_references_downcase)
    assert_equal RoleConstants::MENTOR_NAME, assigns(:role)
    assert_mentoring_slots meets.flatten, assigns(:meetings).flatten
    assert assigns(:can_apply_explicit_preferences)
  end

  def test_mentoring_calendar_for_dual_role
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    users(:f_mentor).add_role(RoleConstants::STUDENT_NAME)
    assert users(:f_mentor).can_view_mentoring_calendar?

    st = (mentoring_slots(:f_mentor).start_time - 2.days)
    en = (mentoring_slots(:f_mentor).end_time + 2.days)

    current_user_is :f_mentor

    get :mentoring_calendar, xhr: true, params: { start: st.to_i, end: en.to_i}
    assert_false assigns(:filter_questions).collect(&:id).include?(programs(:org_primary).name_question.id)
    assert_mentoring_slots assigns(:availability).flatten, add_urls(members(:f_mentor).get_availability_slots(st, en, users(:f_student).program, true, 90, true, users(:f_student)))

    mentor = members(:not_requestable_mentor)
    meets = [mentor.get_meeting_slots(Meeting.recurrent_meetings(mentor.meetings, {get_merged_list: true, start_time: st, end_time: en, get_occurrences_between_time: true}), members(:f_mentor).meetings.pluck(:id), members(:f_mentor))]
    assert_mentoring_slots meets.flatten, assigns(:meetings).flatten
  end

  def test_mentoring_calendar_with_allow_mentoring_mode_change
    Timecop.freeze do
      programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
      assert users(:f_student).can_view_mentoring_calendar?

      st = (mentoring_slots(:f_mentor).start_time - 2.days)
      en = (mentoring_slots(:f_mentor).end_time + 2.days)
      current_user_is :f_student
      programs(:albers).update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
      programs(:albers).mentor_users.update_all(mentoring_mode: User::MentoringMode::ONGOING)
      get :mentoring_calendar, xhr: true, params: { start: st.to_i, end: en.to_i}
      assert_false assigns(:filter_questions).collect(&:id).include?(programs(:org_primary).name_question.id)
      assert_mentoring_slots assigns(:availability).flatten, add_urls(members(:f_mentor).get_availability_slots(st, en, users(:f_student).program, true, 90, true, users(:f_student)))
      meets = []
      [members(:f_mentor), members(:not_requestable_mentor)].each do |m|
        meets << m.get_meeting_slots(Meeting.recurrent_meetings(m.meetings, {get_merged_list: true, start_time: st, end_time: en, get_occurrences_between_time: true}), members(:f_student).meetings.pluck(:id), members(:f_student))
      end
      assert_equal "Mentors", assigns(:user_reference_plural)
      assert_equal "Mentor",  assigns(:user_reference)
      assert_equal "mentors", assigns(:user_references_downcase)
      assert_equal RoleConstants::MENTOR_NAME, assigns(:role)
      assert_mentoring_slots meets.flatten, assigns(:meetings).flatten
    end
  end

  def test_mentoring_calendar_availability_respecting_max_capacity
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    st = mentoring_slots(:f_mentor).start_time
    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), (st - 100.minutes), (st - 20.minutes), {duration: 80.minutes})

    st = (mentoring_slots(:f_mentor).start_time - 2.days)
    en = (mentoring_slots(:f_mentor).end_time + 2.days)

    current_user_is :f_student
    get :mentoring_calendar, xhr: true, params: { start: st.to_i, end: en.to_i}
    assert_false assigns(:filter_questions).collect(&:id).include?(programs(:org_primary).name_question.id)

    #while there mentor might have assigned availability slots in the interval, mentee should not see them once max capacity limit reached
    assert_false (members(:f_mentor).get_member_availability_after_meetings(members(:f_mentor).get_mentoring_slots(st, en, true, 90, true), st, en, programs(:org_primary))).blank?
    assert_mentoring_slots assigns(:availability).flatten, []

    meets = []
    [members(:f_mentor), members(:not_requestable_mentor)].each do |m|
      meets << m.get_meeting_slots(Meeting.recurrent_meetings(m.meetings, {get_merged_list: true, start_time: st, end_time: en, get_occurrences_between_time: true}), members(:f_student).meetings.pluck(:id), members(:f_student))
    end
    assert_mentoring_slots assigns(:meetings).flatten, meets.flatten
    assert_false assigns(:can_current_user_create_meeting) #current_user is not a mentor
  end

  def test_mentoring_calendar_with_side_pane_filters_invalid_quick_search
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    assert users(:f_student).can_view_mentoring_calendar?

    st = (mentoring_slots(:f_mentor).start_time - 2.days)
    en = (mentoring_slots(:f_mentor).end_time + 2.days)

    current_user_is :f_student
    get :mentoring_calendar, xhr: true, params: { start: st.to_i, end: en.to_i, sf: {quick_search: "samptyule"}}
    assert_false assigns(:filter_questions).collect(&:id).include?(programs(:org_primary).name_question.id)
    assert_equal [], assigns(:calendar_objects)
  end

  def test_mentoring_calendar_with_side_pane_filters_valid_filter_params
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    assert users(:f_student).can_view_mentoring_calendar?

    mentoring_slot = mentoring_slots(:f_mentor)

    st = mentoring_slot.start_time - 2.days
    en = mentoring_slot.end_time + 2.days
    pq = profile_questions(:experience_q)

    current_user_is :f_student

    get :mentoring_calendar, xhr: true, params: { start: st.to_i, end: en.to_i, sf: {quick_search: "good unique", pq: {pq.id.to_s => "microsoft"}}}
    assert_false assigns(:filter_questions).collect(&:id).include?(programs(:org_primary).name_question.id)
    assert_mentoring_slots assigns(:availability).flatten, add_urls(members(:f_mentor).get_availability_slots(st, en, users(:f_student).program, true, 90, true, users(:f_student)))

    meets = members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).meetings, {get_merged_list: true, start_time: st, end_time: en, get_occurrences_between_time: true}), members(:f_student).meetings.pluck(:id), members(:f_student))
    assert_mentoring_slots [assigns(:availability), meets].flatten, assigns(:calendar_objects)

    # move mentoring_slot to future
    mentoring_slot.update_attributes(
      start_time: mentoring_slot.start_time + 4.days,
      end_time: mentoring_slot.end_time + 4.days)

    get :mentoring_calendar, xhr: true, params: { start: st.to_i, end: en.to_i, sf: {quick_search: "good unique", pq: {pq.id.to_s => "microsoft"}}}
    assert assigns(:availability).flatten.empty?
  end

  def test_mentoring_calendar_should_not_slots_of_suspended_mentors
    programs(:org_anna_univ).enable_feature(FeatureName::CALENDAR, true)
    assert users(:psg_student1).can_view_mentoring_calendar?
    user = users(:inactive_user)
    member = users(:inactive_user).member

    create_mentoring_slot(member: member)

    st = (member.mentoring_slots.first.start_time - 2.days)
    en = (member.mentoring_slots.first.end_time + 2.days)

    current_user_is :psg_student1
    get :mentoring_calendar, xhr: true, params: { start: st.to_i, end: en.to_i}
    assert assigns(:availability).flatten.empty?
  end

  def test_mentoring_calendar_rejected_meeting
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    invalidate_albers_calendar_meetings
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    st = (mentoring_slots(:f_mentor).start_time - 2.days)
    en = (mentoring_slots(:f_mentor).end_time + 2.days)
    meetings(:f_mentor_mkr_student).update_meeting_time(Time.now.utc.beginning_of_month + 2.days, 1800.00)
    meetings(:f_mentor_mkr_student).update_attributes(owner_id: members(:mkr_student).id)
    members(:f_mentor).mark_attending!(meetings(:f_mentor_mkr_student).reload, attending: false)
    meetings(:f_mentor_mkr_student).reload
    current_user_is :f_student
    get :mentoring_calendar, xhr: true, params: { start: st.to_i, end: en.to_i}

    assert_mentoring_slots assigns(:availability).flatten, add_urls(members(:f_mentor).get_availability_slots(st, en, programs(:albers), true, nil, false, nil, false, nil))

    meets = []
    [members(:not_requestable_mentor)].each do |m|
      meets << m.get_meeting_slots(Meeting.recurrent_meetings(m.meetings, {get_merged_list: true, start_time: st, end_time: en, get_occurrences_between_time: true}), members(:f_student).meetings.pluck(:id), members(:f_student))
    end
    assert_mentoring_slots assigns(:meetings).flatten, meets.flatten
  end

  def test_mentoring_calendar_feature_disabled
    current_user_is :f_student

    assert_raise Authorization::PermissionDenied do
      get :mentoring_calendar
    end
  end

  def test_index_assigns
    current_user_is :f_admin
    current_organization_is :org_primary

    get :index, params: { filter: "all"}
    assert_equal RoleConstants::MENTOR_NAME, assigns(:role)
    assert_false assigns(:filter_questions).collect(&:id).include?(programs(:org_primary).name_question.id)
    assert_equal 3, assigns(:profile_questions).count # only default profile fields for mentor
  end

  def test_index_for_user_role
    current_user_is :f_admin
    current_organization_is :org_primary

    get :index, params: { view: "user"}
    assert_equal "user", assigns(:role)
    assert_equal "Users", assigns(:user_reference_plural)
    assert_equal "User", assigns(:user_reference)
    assert_equal "users", assigns(:user_references_downcase)
    assert_equal [users(:f_user)], assigns(:users).to_a
    assert_false assigns(:filter_questions).collect(&:id).include?(programs(:org_primary).name_question.id)
  end

  def test_index_pending_requests
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    MentorRequest.where(receiver_id: users(:f_mentor).id).delete_all
    MeetingRequest.where(receiver_id: users(:f_mentor).id).delete_all
    m1 = create_mentor_request(student: users(:rahim),
      mentor: users(:f_mentor), message: 'good')
    m2 = create_meeting_request(student: users(:rahim),
      mentor: users(:f_mentor))
    get :index, params: { view: "students"}
    assert_equal [7], assigns(:received_requests_sender_ids).uniq
  end

  def test_contact_admin_help_message_not_displayed_for_students
    current_member_is :f_student
    get :index, params: { view: "students", search: "arbit"}
    assert_no_select "#search_contact_admin"
  end

  def test_contact_admin_help_message_not_displayed_for_mentors
    current_member_is :f_student
    get :index, params: { search: "arbit"}
    assert_no_select "#search_contact_admin"
  end

  def test_contact_admin_help_message_displayed_for_mentors
    current_user_is :f_student
    get :index, params: { search: "arbit"}
    assert_select "#search_contact_admin" do
      assert_select "a[href=?]", contact_admin_url
    end
  end

  def test_available_filter
    current_user_is :f_student
    get :index, xhr: true, params: { filter: "available"}
    assert_equal UsersIndexFilters::Values::AVAILABLE, assigns(:filter_field)
    assert assigns(:my_filters).include?({label: 'Availability Status', reset_suffix: 'availability_status'})
  end

  def test_allow_mentoring_mode_change_set_to_editable
    programs(:albers).update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    current_user_is :f_student

    get :index, xhr: true, params: { filter: "available"}
    assert_equal UsersIndexFilters::Values::AVAILABLE, assigns(:filter_field)
    assert assigns(:my_filters).include?({label: 'Availability Status', reset_suffix: 'availability_status'})
    assert_equal [User::MentoringMode::ONE_TIME_AND_ONGOING], assigns(:users).collect(&:mentoring_mode).uniq
  end

  def test_preferred_mentors
    current_program_is :moderated_program
    users(:moderated_student).user_favorites.create!({favorite_id: users(:moderated_mentor).id})
    users(:moderated_student).reload
    current_user_is :moderated_student

    get :index
    assert_equal [users(:moderated_mentor)], assigns(:preferred_mentors)
    assert_select "div.cjs_preferred_mentors_box" do
      assert_select "h5", value: "Preferred Mentors"
      assert_select "ul" do
        assert_select "li" do
          assert_select "a", text: "Moderated Mentor"
        end
      end
    end
  end

  def test_unpublished_preferred_mentors_for_mentee
    setup_for_unpublished_mentor_test
    get :index
    assert_equal [users(:psg_mentor1)], assigns(:preferred_mentors)
    assert_select "div.cjs_preferred_mentors_box" do
      assert_select "h5", value: "Preferred Mentors"
      assert_select "ul" do
        assert_select "li", count: 2 # mobile and web
      end
    end
  end

  def test_unpublished_preferred_mentors_for_admin
     # add admin role to the student, he should be able to see both the mentors now
    users(:psg_student1).add_role(RoleConstants::ADMIN_NAME)
    setup_for_unpublished_mentor_test

    pm = [users(:psg_mentor1)]
    pm += [users(:psg_mentor2)]
    get :index
    assert_equal pm, assigns(:preferred_mentors)
    assert_select "div.cjs_preferred_mentors_box" do
      assert_select "h5", value: "Preferred Mentors"
      assert_select "ul" do
        assert_select "li", count: 4 # mobile and web
      end
    end
  end

  def test_update_tags_feature_denied
    current_user_is :f_admin
    assert_permission_denied do
      post :update_tags, params: { id: users(:f_mentor).id, user: {tag_list: "a,b,c"}}
    end
  end

  def test_update_tags_permission_denied
    programs(:org_primary).enable_feature(FeatureName::MEMBER_TAGGING)
    current_user_is :f_mentor

    assert_permission_denied do
      post :update_tags, params: { id: users(:f_mentor).id, user: {tag_list: "a,b,c"}}
    end
  end

  def test_update_tags
    programs(:org_primary).enable_feature(FeatureName::MEMBER_TAGGING)
    current_user_is :f_admin
    assert_difference "users(:mentor_0).tags.count", 3 do
      post :update_tags, xhr: true, params: { id: users(:mentor_0).id, user: {tag_list: "a,b,c"}}
    end
  end

  def test_favorite_mentors_success_for_meeting_request_student
    user = users(:f_student)

    current_user_is user
    get :favorite_mentors, xhr: true, params: { id: user.id, request_type: UserPreferenceService::RequestType::MEETING, favorite_user_ids: [users(:f_mentor).id, users(:robert).id] }
    assert_equal UserPreferenceService::RequestType::MEETING, assigns(:request_type)
    assert_equal [users(:f_mentor), users(:robert)], assigns(:favorite_users)
    assert_equal_hash( {
      users(:f_mentor).id => abstract_preferences(:favorite_1).id,
      users(:robert).id => abstract_preferences(:favorite_3).id
    }, assigns(:favorite_preferences_hash))
  end

  def test_favorite_mentors_success_for_mentoring_request_student
    user = users(:f_student)

    current_user_is user
    get :favorite_mentors, xhr: true, params: { id: user.id, request_type: UserPreferenceService::RequestType::GROUP, favorite_user_ids: [users(:f_mentor).id, users(:robert).id] }
    assert_equal UserPreferenceService::RequestType::GROUP, assigns(:request_type)
    assert_equal [users(:f_mentor), users(:robert)], assigns(:favorite_users)
    assert_equal_hash( {
      users(:f_mentor).id => abstract_preferences(:favorite_1).id,
      users(:robert).id => abstract_preferences(:favorite_3).id
    }, assigns(:favorite_preferences_hash))
  end

  def test_filtering_mentor_available_for_mentoring_or_allowed_time_slot_for_both_conditions_fail
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    student = users(:f_student)
    mentor = users(:f_mentor)
    mentor.member.update_attributes!(will_set_availability_slots: true)
    current_user_is student
    mentor.member.mentoring_slots.destroy_all
    mentor.update_attribute(:max_connections_limit, 0)
    Rails.cache.delete([mentor, "available_and_can_accept_request?"])
    assert_false mentor.reload.cached_available_and_can_accept_request?
    program = mentor.program
    assert_false mentor.member.has_availability_between?(program, (Time.now).beginning_of_day, (Time.now + 7.days).end_of_day, student, {mentor_user: mentor})
    get :index, xhr: true, params: { filter: [UsersIndexFilters::Values::CALENDAR_AVAILABILITY, UsersIndexFilters::Values::AVAILABLE, UserSearch::SHOW_NO_MATCH_FILTER], page: 1, items_per_page: 10000}
    assert_response :success
    assert_false assigns(:users).include?(mentor)
  end

  def test_filtering_mentor_available_for_mentoring_but_no_allowed_time_slot
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    student = users(:f_student)
    mentor = users(:f_mentor_student)
    current_user_is student
    mentor.member.mentoring_slots.destroy_all
    mentor.update_attribute(:max_connections_limit, 100)
    mentor.member.update_attributes!(will_set_availability_slots: true)
    Rails.cache.delete([mentor, "available_and_can_accept_request?"])
    assert mentor.reload.cached_available_and_can_accept_request?
    program = mentor.program
    assert_false mentor.member.has_availability_between?(program, (Time.now).beginning_of_day, (Time.now + 7.days).end_of_day, student, {mentor_user: mentor})
    get :index, xhr: true, params: { filter: [UsersIndexFilters::Values::CALENDAR_AVAILABILITY, UsersIndexFilters::Values::AVAILABLE], page: 1, items_per_page: 10000}
    assert_response :success
    assert assigns(:users).include?(mentor)
  end

  def test_filtering_mentor_not_available_for_mentoring_but_has_allowed_time_slot
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    student = users(:f_student)
    mentor = users(:f_mentor_student)
    mentor.member.update_attributes!(will_set_availability_slots: true)
    current_user_is student
    slot_start_time = Time.now + 3.days + 1.hour
    slot_end_time = slot_start_time + 1.hour
    mentoring_slot = create_mentoring_slot(member: mentor.member, location: "Bangalore", start_time: slot_start_time, end_time: slot_end_time, repeats: MentoringSlot::Repeats::NONE, repeats_on_week: nil)
    mentor.update_attribute(:max_connections_limit, 0)
    Rails.cache.delete([mentor, "available_and_can_accept_request?"])
    assert_false mentor.reload.cached_available_and_can_accept_request?
    program = mentor.program
    assert mentor.member.has_availability_between?(program, (Time.now).beginning_of_day, (Time.now + 7.days).end_of_day, student, {mentor_user: mentor})
    get :index, xhr: true, params: { filter: [UsersIndexFilters::Values::CALENDAR_AVAILABILITY, UsersIndexFilters::Values::AVAILABLE], page: 1, items_per_page: 10000}
    assert_response :success
    assert assigns(:users).include?(mentor)
  end

  def test_autocomplete_user_name_for_meeting
    current_user_is users(:f_mentor)

    get :auto_complete_user_name_for_meeting, xhr: true, params: { search: "Mentor Studenter", format: :json}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [{"label"=>"Mentor Studenter", "user-id"=>users(:f_mentor_student).id, "member-link"=>"/p/albers/members/#{users(:f_mentor_student).id}"}], JSON.parse(@response.body)
  end

  def test_autocomplete_user_name_for_students_for_meeting
    current_user_is users(:f_mentor)

    get :auto_complete_user_name_for_meeting, xhr: true, params: { search: "Mentor Studenter", role: RoleConstants::STUDENT_NAME, format: :json}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [{"label"=>"Mentor Studenter", "user-id"=>users(:f_mentor_student).id, "member-link"=>"/p/albers/members/#{users(:f_mentor_student).id}"}], JSON.parse(@response.body)
  end

  def test_autocomplete_user_name_for_students_no_result_case_for_meeting
    current_user_is users(:f_mentor)

    get :auto_complete_user_name_for_meeting, xhr: true, params: { search: "#{users(:f_mentor).name}", role: RoleConstants::STUDENT_NAME, format: :json}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal_unordered [], JSON.parse(@response.body)
  end

  def test_autocomplete_user_name_for_meeting_check_limit
    current_user_is users(:f_mentor)

    get :auto_complete_user_name_for_meeting, xhr: true, params: { search: "M", format: :json}
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    assert_equal 5, JSON.parse(@response.body).count
  end

  def test_autocomplete_user_name_for_students_for_meeting_permission_denied
    current_user_is users(:f_student)
    assert_permission_denied do
      get :auto_complete_user_name_for_meeting, xhr: true, params: { search: "Mentor Studenter", role: RoleConstants::STUDENT_NAME, format: :json}
    end
  end

  def test_new_preference
    student = users(:rahim)
    current_user_is :rahim
    mentor_user = users(:f_mentor_student)
    get :new_preference, xhr: true, params: { user_id: mentor_user.id}
    assert_equal mentor_user, assigns(:preferred_user)
    assert_equal student.student_cache_normalized, assigns(:match_array)
  end

  def test_mentors_listing_should_not_apply_filters_when_calendar_disabled
    current_user_is users(:f_student)
    users1 = users(:f_mentor)

    mentoring_slot = users1.member.mentoring_slots.first
    slot_start_time = Time.now + 3.days + 1.hour
    slot_end_time = slot_start_time + 1.hour
    mentoring_slot.update_attributes!(start_time: slot_start_time, end_time: slot_end_time)

    new_slot_time = slot_start_time + 10.days
    create_mentoring_slot(member: members(:f_mentor_student), location: "Bangalore",
      start_time: new_slot_time, end_time: new_slot_time + 2.hours,
      repeats: MentoringSlot::Repeats::NONE, repeats_on_week: nil)

    get :index, xhr: true, params: { filter: [UsersIndexFilters::Values::CALENDAR_AVAILABILITY, UserSearch::SHOW_NO_MATCH_FILTER],
      items_per_page: 30}
    assert_response :success

    assert_equal "Availability Status", assigns(:status_filter_label)
    assert assigns(:users).include?(users(:f_mentor))
    assert assigns(:users).include?(users(:f_mentor_student))
  end

  def test_match_scores_not_available
    abstract_preferences(:ignore_1).destroy!
    abstract_preferences(:ignore_3).destroy!
    current_user_is :f_student
    user_id = users(:f_mentor).id

    clear_mentor_cache(users(:f_student).id, user_id)
    get :index, params: { sf: {quick_search: "Good unique"}, filter: [UserSearch::SHOW_NO_MATCH_FILTER]}
    assert_response :success

    assert_equal 1, assigns(:users).size
    assert_equal user_id, assigns(:users).first.id

    assert_select "#mentor_#{user_id}" do
      assert_select "h4", text: "display_string.NA".translate
    end
    set_mentor_cache(users(:f_student).id, user_id, 0.0)
  end

  def test_show_no_match
    current_program_is :albers
    current_user_is :f_student
    hsh = users(:f_student).student_cache_normalized
    mentor = users(:f_mentor)
    hsh[mentor.id] = 0
    User.any_instance.expects(:student_cache_normalized).returns(hsh)
    get :index, params: { items_per_page: 50, filter: ["show_no_match"]}
    assert assigns(:user_ids).include?(mentor.id)
    assert assigns(:show_no_match_filter_value)
    assert_false assigns(:hide_no_match_users)
    assert_equal [{label: "Match Score", reset_suffix: "match_score"}], assigns(:my_filters)
  end

  def test_hide_no_match
    current_program_is :albers
    current_user_is :f_student
    hsh = users(:f_student).student_cache_normalized
    mentor = users(:f_mentor)
    hsh[mentor.id] = 0
    User.any_instance.expects(:student_cache_normalized).returns(hsh)
    get :index, params: { items_per_page: 50, filter: ["available"]}
    assert_false assigns(:user_ids).include?(mentor.id)
    assert_false assigns(:show_no_match_filter_value)
    assert assigns(:hide_no_match_users)
    assert_equal [{label: "Availability Status", reset_suffix: "availability_status"}], assigns(:my_filters)
  end

  def test_no_mentor_request_program_should_not_show_match_score_in_listing_if_calendar_diabled
    current_program_is :no_mentor_request_program
    current_user_is :no_mreq_student
    user_id = users(:no_mreq_mentor).id
    get :index, params: { items_per_page: 30}
    assert_response :success
    assert_select "div.listing" do
      assert_select "div#mentor_#{user_id}"
    end
  end

  def test_no_mentor_request_program_should_show_match_score_in_listing_if_calendar_enabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    current_program_is :no_mentor_request_program
    current_user_is :no_mreq_student
    user_id = users(:no_mreq_mentor).id

    get :index, xhr: true, params: { items_per_page: 30}
    assert_response :success
    assert_match /div class=\\\"listing/, response.body
    assert_match /h4.*span.*90%.*match/, response.body
  end

  def test_select_all_ids_non_admin_permission_denied
    current_user_is :moderated_mentor
    assert_permission_denied { get :select_all_ids }
  end

  def test_select_all_ids_permission_denied
    current_user_is :f_admin
    assert_permission_denied { get :select_all_ids }
  end

  def test_select_all_ids_no_filter_params
    current_user_is :f_admin_nwen
    current_program_is :nwen

    programs(:nwen).update_attribute(:allow_track_admins_to_access_all_users, true)

    member_ids = programs(:org_primary).members.all.collect(&:id) - programs(:nwen).all_users.collect(&:member_id).uniq

    get :select_all_ids, params: { items_per_page: 1_000_000}
    assert_response :success

    assert_nil assigns(:listing_options)[:filters][:search]
    assert_nil assigns(:listing_options)[:filters][:role]
    assert_nil assigns(:listing_options)[:filters][:program_id]
    assert_equal_unordered member_ids.map(&:to_s), JSON.parse(response.body)["member_ids"]
  end

  def test_select_all_ids_with_filter_params
    current_user_is :f_admin_nwen
    current_program_is :nwen

    programs(:nwen).update_attribute(:allow_track_admins_to_access_all_users, true)

    member_ids = programs(:albers).all_users.mentors.collect(&:member_id) - programs(:nwen).all_users.collect(&:member_id)
    mentor_role_id = [programs(:albers).roles.where(name: "mentor").first.id.to_s]
    get :select_all_ids, params: { filter_program_id: programs(:albers).id, filter_role: mentor_role_id}
    assert_response :success, items_per_page: 1_000_000

    assert_nil assigns(:listing_options)[:filters][:search]
    assert_equal mentor_role_id, assigns(:listing_options)[:filters][:role]
    assert_equal programs(:albers).id, assigns(:listing_options)[:filters][:program_id]

    assert_equal_unordered member_ids.map(&:to_s), JSON.parse(response.body)["member_ids"]
  end

  def test_bulk_confirmation_view
    current_user_is :f_admin
    current_program_is :albers

    programs(:albers).update_attribute(:allow_track_admins_to_access_all_users, true)

    post :bulk_confirmation_view, xhr: true, params: { bulk_action_confirmation: {users: ["37","38"], title: "Add to Program"}}
    assert_response :success

    assert_equal "Add to Program", assigns(:bulk_action_title)
    assert assigns(:member_ids).present?
    assert_equal programs(:albers).roles.collect(&:name), assigns(:roles).collect(&:name)
  end

  def test_bulk_confirmation_view_for_portal
    current_user_is :portal_admin
    current_program_is :primary_portal

    programs(:primary_portal).update_attribute(:allow_track_admins_to_access_all_users, true)

    post :bulk_confirmation_view, xhr: true, params: { bulk_action_confirmation: {users: ["37","38"], title: "Add to Program"}}
    assert_response :success

    assert_equal "Add to Program", assigns(:bulk_action_title)
    assert assigns(:member_ids).present?
    assert_equal programs(:primary_portal).roles.collect(&:name), assigns(:roles).collect(&:name)
  end


  def test_no_users_selected_for_bulk_action
    current_user_is :f_admin
    current_program_is :albers

    programs(:albers).update_attribute(:allow_track_admins_to_access_all_users, true)

    post :create_from_other_program, xhr: true, params: { member_ids: "", roles: ["mentor"]}
    assert_redirected_to new_from_other_program_users_path
  end

  def test_hovercard
    current_user_is :f_admin
    user = users(:f_mentor_student)
    user.program.enable_feature(FeatureName::CALENDAR)

    get :hovercard, xhr: true, params: { id: user.id}
    assert_match /fa-calendar/, response.body
    assert_match /fa-user-plus/, response.body
    assert_equal assigns(:user), user
    assert_equal assigns(:user_roles), "Mentor and Student"
    assert assigns(:show_email)
    assert_equal 6, assigns(:in_summary_questions).count
  end

  def test_hovercard_for_private_password
    current_user_is :mkr_student
    user = users(:f_mentor)

    mentor_role = user.roles.first
    email_question = mentor_role.role_questions.find_by(profile_question_id: programs(:org_primary).email_question.id)
    email_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)

    get :hovercard, xhr: true, params: { id: user.id}
    assert_false assigns(:show_email)
    assert_equal 3, assigns(:in_summary_questions).count

    assert_false user.program.project_based?
    assert user.groups.global.open_connections.present?
    assert_nil assigns(:groups)
    assert_false assigns(:viewing_group)
    assert_equal assigns(:user_roles), RoleConstants.to_program_role_names(user.program, user.role_names).to_sentence
  end

  def test_hovercard_for_groups_in_project_based_program
    current_user_is :f_admin_pbe
    user = users(:f_mentor_pbe)
    group = user.groups.first

    get :hovercard, xhr: true, params: { id: user.id, group_view_id: group.id}

    assert user.program.project_based?
    assert user.groups.global.open_connections.present?
    assert_equal assigns(:groups), user.groups.global.open_connections
    assert_equal assigns(:viewing_group), group
    assert_equal assigns(:user_roles), RoleConstants.to_program_role_names(user.program, [group.membership_of(user).role.name]).to_sentence
  end

  def test_new_actions_question
    current_user_is :f_admin
    current_program_is :albers
    pq = create_profile_question
    rq = create_role_question(profile_question: pq, program: programs(:albers), role_names: [RoleConstants::STUDENT_NAME])
    get :new, xhr: true, params: { role: RoleConstants::MENTOR_NAME + ", " + RoleConstants::STUDENT_NAME}
    assert_response :success
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:roles)
    assert assigns(:grouped_role_questions).values.flatten.include?(rq)

    get :new, xhr: true, params: { role: RoleConstants::MENTOR_NAME}
    assert_response :success
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:roles)
    assert_false assigns(:grouped_role_questions).include?(rq)
  end

  def test_reviews_feature_disabled
    assert_false programs(:albers).coach_rating_enabled?
    current_user_is :f_admin
    assert_permission_denied do
      get :reviews, params: { id: users(:f_mentor).id}
    end
  end

  def test_reviews_no_permission
    programs(:albers).enable_feature(FeatureName::COACH_RATING)
    current_user_is :f_student
    assert_permission_denied do
      get :reviews, params: { id: users(:f_mentor).id}
    end
  end

  def test_reviews_success
    programs(:albers).enable_feature(FeatureName::COACH_RATING)
    current_user_is :f_admin
    get :reviews, params: { id: users(:f_mentor).id}
    assert_equal users(:f_mentor), assigns(:user)
    assert_response :success
    assert_equal [], assigns(:reviews)
    feedback_form = programs(:albers).feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
    response = Feedback::Response.create_from_answers(
        users(:mkr_student), users(:f_mentor), 5, groups(:mygroup), feedback_form, {feedback_form.questions.first.id => 'some text'})
    get :reviews, params: { id: users(:f_mentor).id}
    assert_response :success
    assert_equal [response], assigns(:reviews)
  end

  def test_aa_mentors_available_filter_for_program_with_disabled_ongoing_mentoring
    # irrespective of connection limit of robert, it will come in the result as ongoing mentoring is not enabled
    current_user_is :f_student
    users(:f_mentor_student).update_attribute(:max_connections_limit, 1)
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    get :index, params: { calendar_availability_default: false, filter: [UsersIndexFilters::Values::AVAILABLE], items_per_page: 20}
    assert assigns(:users).include?(users(:f_mentor_student))
  end

  def test_available_filter_for_onetime_preferring_mentor_and_program_considering_mentoring_mode
    # making moderated program consider mentoring mode
    programs(:moderated_program).update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    programs(:moderated_program).enable_feature(FeatureName::CALENDAR)
    current_program_is :moderated_program
    current_user_is :moderated_admin

    get :index, params: { filter: "available"}
    assert !assigns(:users).include?(users(:f_onetime_mode_mentor))
  end

  def test_both_available_filters_applied_and_program_considering_mentoring_mode
    # making moderated program consider mentoring mode
    programs(:moderated_program).update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    programs(:moderated_program).enable_feature(FeatureName::CALENDAR)
    current_program_is :moderated_program
    current_user_is :moderated_student

    get :index, params: { filter: ["available", UsersIndexFilters::Values::CALENDAR_AVAILABILITY]}
    assert assigns(:users).include?(users(:f_onetime_mode_mentor))
    assert assigns(:users).include?(users(:moderated_mentor))
  end

  def test_create_mentor_success_for_global_domain
    setup_up_for_add_user
    prog = programs(:albers)
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION)
    prog_d = prog.organization.default_program_domain
    prog_d.save!
    skype_q = programs(:org_primary).profile_questions.skype_question.first
    phone_q = programs(:org_primary).profile_questions.find_by(question_text: "Phone")

    current_user_is @add_mentor_user

    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    post :create, params: { email: 'mentor@bridges.global', user: {
      member: {
        first_name: 'some',
        last_name: 'user',
        profile_picture: {image: "", image_url: ""}
      },
      max_connections_limit: 2,
      program_id: programs(:albers).id
    },
      profile_answers: { profile_questions(:string_q).id.to_s => "First Answer",
                    profile_questions(:single_choice_q).id.to_s => "opt_2",
                    profile_questions(:multi_choice_q).id.to_s => "Walk",
                    skype_q.id.to_s => "api",
                    phone_q.id.to_s => "123"},
      role: RoleConstants::MENTOR_NAME
    }

    assert_redirected_to program_root_path

    assert_not_nil assigns(:user)
    assert_equal "<a href='#{member_path(assigns(:user).member)}'>#{assigns(:user).name}</a> has been added as #{@controller._a_Mentor}.", flash[:notice]

    assert assigns(:user).is_mentor?
    assert_equal 'some user', assigns(:user).name
    assert_equal 'mentor@bridges.global', assigns(:user).email
  end

  def test_add_user_options_popup_permission_denied
    current_user_is :f_mentor

    assert_permission_denied do
      get :add_user_options_popup, xhr: true
    end
  end

  def test_add_user_options_popup
    current_user_is :f_admin

    get :add_user_options_popup, xhr: true

    assert_response :success
    assert_equal assigns(:can_add_existing_member), programs(:albers).allow_track_admins_to_access_all_users
    assert_equal assigns(:can_import_users_from_csv), programs(:albers).user_csv_import_enabled?
  end

  def test_add_user_options_popup_standlone_org
    current_user_is :foster_admin

    programs(:org_foster).update_attribute(:allow_track_admins_to_access_all_users, true)

    get :add_user_options_popup, xhr: true

    assert_response :success
    assert_false assigns(:can_add_existing_member)
  end

  def test_add_user_options_popup_for_adding_dormant_users_for_non_standalone_org
    current_user_is :f_admin

    program = programs(:albers)
    organization = programs(:org_primary)

    program.enable_feature(FeatureName::USER_CSV_IMPORT, true)
    organization.enable_feature(FeatureName::ORGANIZATION_PROFILES, true)

    get :add_user_options_popup, xhr: true

    assert_false organization.standalone?
    assert program.user_csv_import_enabled?
    assert organization.org_profiles_enabled?

    assert_response :success
    assert_false assigns(:can_import_dormant_users)
  end

  def test_add_user_options_popup_for_adding_dormant_users_for_standalone_org
    current_user_is :f_admin

    program = programs(:albers)
    organization = programs(:org_primary)

    Organization.any_instance.stubs(:standalone?).returns(true)

    program.enable_feature(FeatureName::USER_CSV_IMPORT, true)
    organization.enable_feature(FeatureName::ORGANIZATION_PROFILES, true)

    get :add_user_options_popup, xhr: true

    assert organization.standalone?
    assert program.user_csv_import_enabled?
    assert organization.org_profiles_enabled?

    assert_response :success
    assert assigns(:can_import_dormant_users)
  end

  def test_add_user_options_popup_for_adding_dormant_users_for_standalone_org_with_org_profiles_disabled
    current_user_is :f_admin

    program = programs(:albers)
    organization = programs(:org_primary)

    Organization.any_instance.stubs(:standalone?).returns(true)

    program.enable_feature(FeatureName::USER_CSV_IMPORT, true)
    organization.enable_feature(FeatureName::ORGANIZATION_PROFILES, false)

    get :add_user_options_popup, xhr: true

    assert organization.standalone?
    assert program.user_csv_import_enabled?
    assert_false organization.org_profiles_enabled?

    assert_response :success
    assert_false assigns(:can_import_dormant_users)
  end

  def test_add_user_options_popup_for_adding_dormant_users_for_standalone_org_with_csv_feature_disabled
    current_user_is :f_admin

    program = programs(:albers)
    organization = programs(:org_primary)

    Organization.any_instance.stubs(:standalone?).returns(true)

    get :add_user_options_popup, xhr: true

    assert organization.standalone?
    assert_false program.user_csv_import_enabled?
    assert organization.org_profiles_enabled?

    assert_response :success
    assert_false assigns(:can_import_dormant_users)
  end

  def test_pending_requests_popup
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    m1 = create_mentor_request(student: users(:rahim),
      mentor: users(:f_mentor), message: 'good')
    m2 = create_meeting_request(student: users(:rahim),
      mentor: users(:f_mentor))
    get :pending_requests_popup, params: { id: users(:rahim).id}
    assert [m1, m2], assigns(:pending_requests)
  end

  def test_match_details
    abstract_preferences(:ignore_1).destroy!
    abstract_preferences(:ignore_3).destroy!
    current_user_is :f_student
    user = users(:f_student)
    mentor = users(:f_mentor)
    details = [{answers: ["option1","option2"], question_text: "question_text"}]
    profile_questions = mentor.roles.first.role_questions.collect(&:profile_question)
    User.any_instance.expects(:get_visibile_match_config_profile_questions_for).once.with(mentor).returns(profile_questions)
    User.any_instance.expects(:get_match_details_of).once.with(mentor, profile_questions, false).returns(details)
    User.any_instance.stubs(:allowed_to_ignore_and_mark_favorite?).returns(false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_MATCH_DETAILS, {context_place: 'something', context_object: mentor.id.to_s}).once

    get :match_details, params: { id: mentor.id, src: 'something'}
    assert_response :success

    assert_select "div.detail_container" do
      assert_select "div.p-b-xxs.font-bold", text: /question_text/
    end

    assert_select "div.summary_container" do
      assert_select "span.label.small.label-info.status_icon", text: /option1/
      assert_no_select "span.mentor_favorite_#{mentor.id}"
    end

    assert_select "div.summary_container" do
      assert_select "span.label.small.label-info.status_icon", text: /option2/
      assert_no_select "span.mentor_favorite_#{mentor.id}"
    end

    assert_select "div.summary_container" do
      assert_select "div.p-b-xs.small.muted", text: /You match with Good unique name on the following criteria/
      assert_no_select "span.mentor_favorite_#{mentor.id}"
    end

    assert_equal mentor, assigns(:mentor)
    assert_equal 90, assigns(:mentors_score)[mentor.id]
    assert_equal_unordered profile_questions, assigns(:questions_with_email)
    assert_nil assigns(:favorite_preferences_hash)
  end

  def test_match_details_with_no_details
    abstract_preferences(:ignore_1).destroy!
    abstract_preferences(:ignore_3).destroy!
    current_user_is :f_student
    mentor = users(:f_mentor)
    details = []
    profile_questions = mentor.roles.first.role_questions.collect(&:profile_question)
    User.any_instance.expects(:get_visibile_match_config_profile_questions_for).once.with(mentor).returns(profile_questions)
    User.any_instance.expects(:get_match_details_of).once.with(mentor, profile_questions, false).returns(details)
    User.any_instance.stubs(:allowed_to_ignore_and_mark_favorite?).returns(false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_MATCH_DETAILS, {context_place: 'something', context_object: mentor.id.to_s}).once

    get :match_details, params: { id: mentor.id, src: 'something'}
    assert_response :success

    assert_equal mentor, assigns(:mentor)
    assert_equal 90, assigns(:mentors_score)[mentor.id]
    assert_select "div.summary_container" do
      assert_select "div.p-b-sm.p-t-sm", text: /We are unable to retrieve your matching details with Good unique name. Contact Administrator for more details/
      assert_no_select "span.mentor_favorite_#{mentor.id}"
    end
    assert_equal_unordered profile_questions, assigns(:questions_with_email)
    assert_nil assigns(:favorite_preferences_hash)
  end

  def test_match_details_with_favorite_star
    abstract_preferences(:ignore_1).destroy!
    abstract_preferences(:ignore_3).destroy!
    current_user_is :f_student
    mentor = users(:f_mentor)
    details = []
    profile_questions = mentor.roles.first.role_questions.collect(&:profile_question)
    User.any_instance.expects(:get_visibile_match_config_profile_questions_for).once.with(mentor).returns(profile_questions)
    User.any_instance.expects(:get_match_details_of).once.with(mentor, profile_questions, false).returns(details)
    User.any_instance.stubs(:allowed_to_ignore_and_mark_favorite?).returns(true)

    get :match_details, params: { id: mentor.id }
    assert_response :success

    assert_equal mentor, assigns(:mentor)
    assert_equal 90, assigns(:mentors_score)[mentor.id]
    assert_select "div.summary_container" do
      assert_select "span.mentor_favorite_#{mentor.id}"
    end
    assert_equal_unordered profile_questions, assigns(:questions_with_email)
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:favorite_1).id, users(:robert).id=>abstract_preferences(:favorite_3).id}, assigns(:favorite_preferences_hash))
  end

  def test_match_details_with_some_details
    abstract_preferences(:ignore_1).destroy!
    abstract_preferences(:ignore_3).destroy!
    current_user_is :f_student
    user = users(:f_student)
    mentor = users(:f_mentor)
    details = [{answers: ["option1","option2"], question_text: "question_text"}, {answers: [], question_text: "question2_text"}]
    profile_questions = mentor.roles.first.role_questions.collect(&:profile_question)
    User.any_instance.expects(:get_visibile_match_config_profile_questions_for).once.with(mentor).returns(profile_questions)
    User.any_instance.expects(:get_match_details_of).once.with(mentor, profile_questions, false).returns(details)
    User.any_instance.stubs(:allowed_to_ignore_and_mark_favorite?).returns(false)

    get :match_details, params: { id: mentor.id}
    assert_response :success

    assert_select "div.detail_container" do
      assert_select "div.p-b-xxs.font-bold", text:  "question_text", count: 1
    end

    assert_select "div.detail_container" do
    assert_select "div.p-b-xxs.font-bold", text: "question2_text", count: 0
    end

    assert_select "div.summary_container" do
      assert_select "span.label.small.label-info.status_icon", text: /option1/
      assert_no_select "span.mentor_favorite_#{mentor.id}"
    end

    assert_select "div.summary_container" do
      assert_select "span.label.small.label-info.status_icon", text: /option2/
      assert_no_select "span.mentor_favorite_#{mentor.id}"
    end

    assert_select "div.summary_container" do
      assert_select "div.p-b-xs.small.muted", text: /You match with Good unique name on the following criteria/
      assert_no_select "span.mentor_favorite_#{mentor.id}"
    end

    assert_equal mentor, assigns(:mentor)
    assert_equal 90, assigns(:mentors_score)[mentor.id]
    assert_equal_unordered profile_questions, assigns(:questions_with_email)
    assert_nil assigns(:favorite_preferences_hash)
  end

  def test_cannot_view_unallowed_roles
    current_user_is :f_mentor_student
    current_user = users(:f_mentor_student)
    src = EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION
    User.any_instance.stubs(:can_view_role?).returns(false)
     assert_permission_denied do
      get :index, params: { src: src, items_per_page: 50}
    end
  end

  def test_add_role_for_mentee
    current_user_is :f_student
    user = users(:f_student)
    program = programs(:albers)
    mentor_role = roles("#{program.id}_mentor")
    assert_equal ["student"], user.role_names
    User.any_instance.stubs(:get_applicable_role_to_add_without_approval).returns(mentor_role)
    assert_no_emails do
      assert_difference "RecentActivity.count" do
        post :add_role, params: {id: user.id}
      end
    end
    assert_equal mentor_role, assigns(:to_add_role)
    assert_equal ["student", "mentor"], user.reload.role_names
    assert_equal "Mentor role has been successfully added", flash[:notice]
  end

  def test_add_role_for_mentor
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    mentee_role = roles("#{program.id}_student")
    assert_equal ["mentor"], user.role_names
    User.any_instance.stubs(:get_applicable_role_to_add_without_approval).returns(mentee_role)
    assert_no_emails do
      assert_difference "RecentActivity.count" do
        post :add_role, params: {id: user.id}
      end
    end
    assert_equal mentee_role, assigns(:to_add_role)
    assert_equal ["mentor", "student"], user.reload.role_names
    assert_equal "Student role has been successfully added", flash[:notice]
  end

  def test_add_role_failure
    current_user_is :f_mentor
    user = users(:f_mentor)
    assert_equal ["mentor"], user.role_names
    User.any_instance.stubs(:get_applicable_role_to_add_without_approval).returns(nil)
    assert_no_emails do
      assert_no_difference "RecentActivity.count" do
        post :add_role, params: {id: user.id}
      end
    end
    assert_nil assigns(:to_add_role)
    assert_equal "There were problems updating the role. Please refresh the page and try again.", assigns(:error_flash)
    assert_equal ["mentor"], user.reload.role_names
  end

  def test_add_role_popup
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    mentee_role = roles("#{program.id}_student")
    User.any_instance.stubs(:get_applicable_role_to_add_without_approval).returns(mentee_role)
    get :add_role_popup, xhr: true, params: {id: user.id}
    assert_equal mentee_role, assigns(:to_add_role)
  end

  def test_add_role_popup_failure
    current_user_is :f_mentor
    user = users(:f_mentor)
    User.any_instance.stubs(:get_applicable_role_to_add_without_approval).returns(nil)
    get :add_role_popup, xhr:true, params: {id: user.id}
    assert_nil assigns(:to_add_role)
    assert_equal "There were problems updating the role. Please refresh the page and try again.", assigns(:error_flash)
  end
  private

  def get_html_part_from(email)
    multipart_alternative = email.parts.find{|part| part.content_type =~ /alternative/} || email
    multipart_alternative.parts.find{|part| part.content_type =~ /html/}.body.to_s
  end

  def date_formatter(time_object)
    time_object.strftime(MeetingsHelper::DateRangeFormat.call)
  end

  def setup_up_for_add_user
    User.any_instance.expects(:visible_to?).at_least(0).returns(true)
    add_mentor_role = create_role(name: 'add_mentor_role')
    add_student_role = create_role(name: 'add_student_role')
    add_role_permission(add_mentor_role, 'add_non_admin_profiles')
    add_role_permission(add_student_role, 'add_non_admin_profiles')
    @add_mentor_user = create_user(name: 'add_mentor_name', role_names: ['add_mentor_role'])
    @add_student_user = create_user(name: 'add_student_name', role_names: ['add_student_role'])
  end

  def setup_for_unpublished_mentor_test
    student = users(:psg_student1)
    student.user_favorites.create!(favorite_id: users(:psg_mentor1).id)
    student.user_favorites.create!(favorite_id: users(:psg_mentor2).id)
    users(:psg_mentor2).update_attribute(:state, User::Status::PENDING)

    current_user_is student
  end

  def assert_invalid_new_user_followup(redirect_path = nil, message = nil)
    assert_redirected_to redirect_path || program_root_path
    assert_nil session[:reset_code]
    assert_equal(message, flash[:notice]) if message.present?
  end

  def assert_valid_new_user_followup(auth_config = nil)
    assert assigns(:only_login)
    assert_equal @member, assigns(:member)
    assert_equal @password, assigns(:password)
    assert_equal @password.reset_code, session[:reset_code]

    assert_dynamic_expected_nil_or_equal auth_config, assigns(:auth_config)
    assert_nil assigns(:profile_answers_map) if session[:new_user_import_data].try(:[], @organization.id).try(:[], "ProfileAnswer").blank?
    if auth_config.present?
      assert_nil assigns(:login_sections)
    else
      @controller.expects(:initialize_login_sections).never
      assert_not_nil assigns(:login_sections)
    end
  end

  def test_work_on_behalf_with_feature_disabled
    current_user_is :f_student
    add_role_permission(fetch_role(:albers, :student), 'work_on_behalf')
    programs(:org_primary).enable_feature(FeatureName::WORK_ON_BEHALF, false)
    assert users(:f_student).can_work_on_behalf?
    assert_permission_denied do
      post :work_on_behalf, id: users(:f_mentor).id
    end
  end
end