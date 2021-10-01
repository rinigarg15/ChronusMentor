require_relative './../test_helper.rb'

class RoleQuestionsControllerTest < ActionController::TestCase
  def test_only_admin_can_access
    current_user_is :f_mentor

    assert_permission_denied do
      get :index, params: { :role => RoleConstants::MENTOR_NAME}
    end
  end

  def test_index_for_role_questions
    current_user_is :f_admin

    programs(:org_primary).profile_questions.destroy_all
    email_question = programs(:org_primary).profile_questions_with_email_and_name.email_question.first
    name_question = programs(:org_primary).profile_questions_with_email_and_name.name_question.first
    mentor_email_question = email_question.role_questions.select{|r| r.role ==programs(:albers).get_role(RoleConstants::MENTOR_NAME)}[0]
    mentee_email_question = email_question.role_questions.select{|r| r.role ==programs(:albers).get_role(RoleConstants::STUDENT_NAME)}[0]

    mentor_name_question = name_question.role_questions.select{|r| r.role ==programs(:albers).get_role(RoleConstants::MENTOR_NAME)}[0]
    mentee_name_question = name_question.role_questions.select{|r| r.role ==programs(:albers).get_role(RoleConstants::STUDENT_NAME)}[0]
    q = create_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME])
    mentor_q = q.role_questions.reload.first
    get :index, params: { :role => RoleConstants::MENTOR_NAME}
    assert_redirected_to profile_questions_path
  end

  def test_index_for_role_questions_standalone_program
    current_user_is :foster_admin    
    get :index    
    assert_redirected_to profile_questions_path
  end

  def test_update_role_question_success
    current_user_is :f_admin

    q = create_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME])
    role_q = q.reload.role_questions.first

    assert !role_q.required
    assert role_q.filterable
    User.expects(:es_reindex_for_profile_score).with(any_parameters).once
     put :update, params: { :id => "#{q.id}", :programs => {"#{programs(:albers).id}" => ["#{programs(:albers).get_role(RoleConstants::MENTOR_NAME).id}"]},
      :role_questions => {
        "#{programs(:albers).get_role(RoleConstants::MENTOR_NAME).id}" => {
        :required => true,
        :filterable => true,
        :available_for => {:profile => RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS},
        :privacy_settings => {"#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}" => '1'}
      }
    }}

    assert role_q.reload.required
    assert !role_q.filterable
    assert_equal RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS, role_q.available_for
    assert_response :success
  end

  def test_update_role_question_success_email_question
    current_user_is :f_admin

    q = programs(:org_primary).profile_questions_with_email_and_name.email_question.first
    role_q_privacy_options = (programs(:albers).role_questions & q.role_questions).collect(&:private)
    assert_equal [RoleQuestion::PRIVACY_SETTING::RESTRICTED], role_q_privacy_options.uniq

     User.expects(:es_reindex_for_profile_score).with(any_parameters).once
     put :update, params: { :id => "#{q.id}",
      :role_questions => {
        "#{programs(:albers).get_role(RoleConstants::MENTOR_NAME).id}" => {:required => true,:filterable => true, :privacy_settings => {"#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}" => '1'}},
        "#{programs(:albers).get_role(RoleConstants::STUDENT_NAME).id}" => {:required => true,:filterable => true, :privacy_settings => {"#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}" => '1'}}
      }
    }

    role_q_privacy_options = (programs(:albers).reload.role_questions & q.role_questions).collect(&:private)
    assert_equal [RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY], role_q_privacy_options.uniq
    assert_response :success
  end

  def test_update_role_question_remove_both_role
    current_user_is :f_admin

    q = create_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME])
    role_q = q.reload.role_questions.first

    assert !role_q.required
    assert role_q.filterable

     User.expects(:es_reindex_for_profile_score).with(any_parameters).once
     put :update, params: { :id => "#{q.id}",
      :role_questions => { "#{programs(:albers).get_role(RoleConstants::MENTOR_NAME).id}" => {
      :required => true,
      :filterable => true,
      :privacy_settings => {"#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}" => '1'}
      }}}
    
    assert_response :success
    assert_equal 0, (q.role_questions & programs(:albers).role_questions).size
  end

  def test_update_role_question_change_role
    current_user_is :f_admin

    q = create_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME])
    role_q = q.reload.role_questions.first

    assert_equal RoleConstants::MENTOR_NAME, role_q.role.name
    assert !role_q.required
    assert role_q.filterable
    assert_equal 1, q.role_questions.count

    put :update, params: { :id => "#{q.id}", :programs => {"#{programs(:albers).id}" => ["#{programs(:albers).get_role(RoleConstants::STUDENT_NAME).id}"]},
      :role_questions => { "#{programs(:albers).get_role(RoleConstants::MENTOR_NAME).id}" => { :required => true, :filterable => true, :privacy_settings => {"#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}" => '1'}},
                           "#{programs(:albers).get_role(RoleConstants::STUDENT_NAME).id}" => { :required => true, :filterable => true, :privacy_settings => {"#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}" => '1'}}
      }
    }

    role_q = q.reload.role_questions.first
    assert_equal RoleConstants::STUDENT_NAME, role_q.role.name
    assert role_q.required
    assert !role_q.filterable
    assert_equal RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, role_q.private
    assert_equal false, role_q.admin_only_editable
    assert_equal 1, q.role_questions.count
    assert_response :success
  end

  def test_update_role_question_admin_only_editable_setting
    current_user_is :f_admin

    student_role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)

    q = create_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME])
    q.reload
    mentor_role_q = q.role_questions.where(:role_id => mentor_role.id).first

    assert_equal 1, q.role_questions.count
    assert_equal [false, true, RoleQuestion::PRIVACY_SETTING::ALL, false], [mentor_role_q.required, mentor_role_q.filterable, mentor_role_q.private, mentor_role_q.admin_only_editable]

    put :update, params: { :id => "#{q.id}", :programs => {"#{programs(:albers).id}" => [student_role.id, mentor_role.id]},
      :role_questions => { "#{mentor_role.id}" => { :required => false, :filterable => false },
                           "#{student_role.id}" => { :required => true, :filterable => false, :privacy_settings => {"#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}" => '1'} }
      }
    }
    q.reload
    mentor_role_q = q.role_questions.where(:role_id => mentor_role.id).first
    student_role_q = q.role_questions.where(:role_id => student_role.id).first

    assert_equal 2, q.role_questions.count
    assert_equal [false, false, RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, true], [mentor_role_q.required, mentor_role_q.filterable, mentor_role_q.private, mentor_role_q.admin_only_editable]
    assert_equal [true, false, RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, false], [student_role_q.required, student_role_q.filterable, student_role_q.private, student_role_q.admin_only_editable]
    assert_response :success
  end
  
  def test_update_profile_summary_fields
    current_user_is :f_admin
    assert_equal 4, programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).shown_in_summary.size
    assert_equal 4, programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).shown_in_summary.size
    post :update_profile_summary_fields, params: { :role => RoleConstants::MENTOR_NAME, :fields =>[role_questions(:string_role_q).id, role_questions(:single_choice_role_q).id, role_questions(:multi_choice_role_q).id]}

    assert_equal 3, programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).shown_in_summary.size
    assert_equal 0, programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).shown_in_summary.size
    assert_equal [role_questions(:string_role_q).id, role_questions(:single_choice_role_q).id, role_questions(:multi_choice_role_q).id], programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).shown_in_summary.collect(&:id)
    assert_redirected_to role_questions_path
  end

  def test_update_profile_summary_fields_with_various_parameters
    current_user_is :f_admin

    assert_equal 4, programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).shown_in_summary.size
    post :update_profile_summary_fields, params: { :role => RoleConstants::MENTOR_NAME, :fields =>[role_questions(:string_role_q).id, role_questions(:single_choice_role_q).id, role_questions(:multi_choice_role_q).id]}
    assert_equal 3, programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).shown_in_summary.size
    assert_redirected_to role_questions_path
    post :update_profile_summary_fields, params: { :role => RoleConstants::MENTOR_NAME}
    assert_equal 0, programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).shown_in_summary.size
    assert_redirected_to role_questions_path
  end

  def test_update_profile_summary_fields_permissions
    current_user_is :f_mentor

    assert_permission_denied do
      post :update_profile_summary_fields, params: { :role => RoleConstants::MENTOR_NAME}
    end
  end

  def test_update_email_question
    current_user_is :f_admin
    eq = programs(:org_primary).profile_questions_with_email_and_name.email_question.first
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    mentor_email_question = eq.role_questions.select{|r| r.role == mentor_role}[0]
    put :update, params: { :id => "#{eq.id}",
      :role_questions => { "#{mentor_role.id}" => {
      :required => true,
      :filterable => true,
      :privacy_settings => {"#{RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY}" => '1'}}
      }
    }

    assert_equal ProfileQuestion::Type::EMAIL, eq.question_type
    assert mentor_email_question.private?
    assert_false mentor_email_question.filterable?
    assert_response :success
  end

  def test_update_success_rolequestion_private_value
    current_user_is :f_admin

    q = profile_questions(:profile_questions_8)

    role_q = q.reload.role_questions.first

    assert_equal RoleQuestion::PRIVACY_SETTING::ALL, role_q.reload.private 

    assert !role_q.required
    assert role_q.filterable

    put :update, params: { :id => "#{q.id}", :programs => {"#{programs(:albers).id}" => ["#{programs(:albers).get_role(RoleConstants::MENTOR_NAME).id}"]},
      :role_questions => { "#{programs(:albers).get_role(RoleConstants::MENTOR_NAME).id}" => {
      :required => false,
      :filterable => true,
      :available_for => {:profile => RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS}},
      "#{q.id}" => {"#{programs(:albers).get_role(RoleConstants::MENTOR_NAME).id}" => {}}
      }
    }

    assert_equal RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS, role_q.available_for
    assert_equal RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, role_q.reload.private
    assert_response :success
  end
end