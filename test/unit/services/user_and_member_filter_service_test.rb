require_relative './../../test_helper.rb'

class UserAndMemberFilterServiceTest < ActiveSupport::TestCase

  def test_filter_members_based_on_user_status
    dormant_member_ids = [members(:dormant_member).id]
    mentor = members(:f_mentor)
    member_with_pending_profile = members(:foster_mentor1)
    mentor.users.update_all(state: User::Status::SUSPENDED)
    suspended_member_ids = [mentor.id, members(:inactive_user).id]
    assert members(:f_mentor).active?
    assert_equal [User::Status::SUSPENDED], members(:f_mentor).users.collect(&:state).uniq
    assert_equal [User::Status::PENDING], member_with_pending_profile.users.collect(&:state).uniq
    assert member_with_pending_profile.active?
    active_member_ids = [members(:rahim).id, members(:f_user).id]
    all_ids = dormant_member_ids + suspended_member_ids + active_member_ids + [member_with_pending_profile.id]
    filter_params = {:member_status => {:user_state =>"#{AdminView::UserState::MEMBER_WITHOUT_ACTIVE_USER}"}, :profile => {:questions => {:questions_1=> {:question => "", :operator => "", :value => ""}}}}
    assert_equal_unordered suspended_member_ids + dormant_member_ids + [member_with_pending_profile.id], UserAndMemberFilterService.filter_members_based_on_user_status(all_ids, filter_params)
    filter_params = {:member_status => {:user_state =>"#{AdminView::UserState::MEMBER_WITH_ACTIVE_USER}"}, :profile => {:questions => {:questions_1=> {:question => "", :operator => "", :value => ""}}}}
    assert_equal_unordered active_member_ids, UserAndMemberFilterService.filter_members_based_on_user_status(all_ids, filter_params)
    filter_params = {:member_status => {:user_state =>"#{AdminView::UserState::IGNORE_USER_STATUS}"}, :profile => {:questions => {:questions_1=> {:question => "", :operator => "", :value => ""}}}}
    assert_equal_unordered all_ids, UserAndMemberFilterService.filter_members_based_on_user_status(all_ids, filter_params)
  end

  def test_apply_profile_filtering_for_education_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_student.profile_answers.map(&:destroy)
    question = profile_questions(:profile_questions_6)

    default_education_options = {
      school_name: 'A',
      degree: 'A',
      major: 'Mech',
      graduation_year: 2010
    }

    create_education_answers(f_admin, question, [
      default_education_options.merge(school_name: 'bu', degree: 'A')
    ])
    create_education_answers(f_mentor, question, [
      default_education_options.merge(school_name: 'A', degree: 'A', graduation_year: 2005),
      default_education_options.merge(school_name: 'bz', degree: 'B')
    ])

    assert_equal [f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"bz"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"bz"}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})
    assert_equal [f_admin.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"bz", "operator"=>SurveyResponsesDataService::Operators::NOT_CONTAINS}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
  end

  def test_apply_profile_filtering_for_scoped_location_question
    program = programs(:albers)
    admin_view = program.admin_views.first
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    user_ids = [f_admin.id, f_mentor.id, f_student.id]

    question = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], {skype: false, default: false}).select{|pq| pq.location?}.first
    admin_view_column = admin_view.admin_view_columns.create!(profile_question: question, column_sub_key: "state")
    locations = Location.reliable.all

    f_admin.save_answer!(question, locations[0].full_address)
    f_mentor.save_answer!(question, locations[1].full_address)
    f_student.save_answer!(question, locations[2].full_address)

    assert_equal [f_admin.id], UserAndMemberFilterService.apply_profile_filtering(user_ids, [{"field"=>"column#{admin_view_column.id}", "value"=>"tamil"}], {:is_program_view => true, :program_id => program.id})
    assert_equal [f_admin.id, f_mentor.id], UserAndMemberFilterService.apply_profile_filtering(user_ids, [{"field"=>"column#{admin_view_column.id}", "value"=>"l", "operator"=>SurveyResponsesDataService::Operators::CONTAINS}], {:is_program_view => true, :program_id => program.id})
  end

  def test_apply_profile_filtering_for_education_question_quoted_values
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_student.profile_answers.map(&:destroy)
    question = profile_questions(:profile_questions_6)

    default_education_options = {
      school_name: 'A',
      degree: 'A',
      major: 'Mech',
      graduation_year: 2010
    }

    create_education_answers(f_admin, question, [
      default_education_options.merge(school_name: 'bu', degree: 'A')
    ])
    create_education_answers(f_mentor, question, [
      default_education_options.merge(school_name: 'A', degree: 'A', graduation_year: 2005),
      default_education_options.merge(school_name: "b'z", degree: 'B')
    ])

    assert_equal [f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"b'z"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_admin.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"b'z", "operator"=>SurveyResponsesDataService::Operators::NOT_CONTAINS}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
  end

  def test_apply_profile_filtering_for_file_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_mentor.profile_answers.map(&:destroy)
    question = profile_questions(:mentor_file_upload_q)

    f_admin.save_answer!(question, fixture_file_upload(File.join('files', 'test_file.css')))

    assert_equal [f_admin.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id], [{"field"=>"column#{question.id}", "value"=>"true"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id], [{"field"=>"column#{question.id}", "value"=>"false"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id], [{"field"=>"column#{question.id}", "value"=>"anything", "operator"=>SurveyResponsesDataService::Operators::NOT_FILLED}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
  end

  def test_apply_profile_filtering_for_manager_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_student.profile_answers.map(&:destroy)
    f_mentor.member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy
    question = programs(:org_primary).profile_questions.manager_questions.first

    default_manager_options = {
      first_name: 'A',
      last_name: 'B',
      email: 'cemail@example.com'
    }

    create_manager(f_admin, question, default_manager_options)
    create_manager(f_mentor, question, default_manager_options.merge(:first_name => 'A', :last_name => 'b', :email => 'aemail@example.com'))
    filter_options = {get_removed_user_or_member_ids: true}

    assert_equal [f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"aemail@example.com"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_admin.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"aemail@example.com", "operator"=>SurveyResponsesDataService::Operators::NOT_CONTAINS}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true, filter_options: filter_options})
    assert_equal_unordered [f_mentor.id], filter_options[:removed_user_or_member_ids]
  end

  def test_apply_profile_filtering_for_multi_choice_question_and_ordered_options_type_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)

    question = create_question(:question_choices => ["Test", "Tes", "Testing"], :question_type => ProfileQuestion::Type::MULTI_CHOICE)
    ordered_question = create_question(:question_choices => ["Test", "Tes", "Testing"], :question_type => ProfileQuestion::Type::ORDERED_OPTIONS, options_count: 3)
    qc_ids_hash = {}
    question.question_choices.each {|qc| qc_ids_hash[qc.text] = qc.id.to_s}
    ordered_qc_ids_hash = {}
    ordered_question.question_choices.each {|qc| ordered_qc_ids_hash[qc.text] = qc.id.to_s}
    filter_options = {get_removed_user_or_member_ids: true}

    # Multichoice
    f_admin.save_answer!(question, ["Test", "Tes"])
    f_mentor.save_answer!(question, ["Test"])
    f_student.save_answer!(question, ["Test","Tes","Testing"])
    
    assert_equal [f_admin.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>qc_ids_hash["Tes"]}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_admin.id, f_mentor.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>qc_ids_hash["Test"]}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>qc_ids_hash["Testing"]}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})

    assert_equal [], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>qc_ids_hash["Test"], "operator"=>SurveyResponsesDataService::Operators::NOT_CONTAINS}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true, filter_options: filter_options})
    assert_equal_unordered [f_admin.id, f_mentor.id, f_student.id], filter_options[:removed_user_or_member_ids]
    assert_equal_unordered [f_admin.id, f_mentor.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>qc_ids_hash["Test"], "operator"=>SurveyResponsesDataService::Operators::FILLED}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>qc_ids_hash["Test"], "operator"=>SurveyResponsesDataService::Operators::NOT_FILLED}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})


    assert_equal [f_admin.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "choice"=>qc_ids_hash["Tes"]}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})
    assert_equal [f_admin.id, f_mentor.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "choice"=>qc_ids_hash["Test"]}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})
    assert_equal [f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "choice"=>qc_ids_hash["Testing"]}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})

    assert_equal [], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "choice"=>qc_ids_hash["Test"], "operator"=>SurveyResponsesDataService::Operators::NOT_CONTAINS}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})

    f_admin.member.profile_answers.delete_all
    assert_equal [f_admin.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>qc_ids_hash["Test"], "operator"=>SurveyResponsesDataService::Operators::NOT_FILLED}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})

    # Ordered options
    f_admin.save_answer!(ordered_question, {"0"=>"Test", "1"=>"Tes"})
    f_mentor.save_answer!(ordered_question, {"0"=>"Test"})
    f_student.save_answer!(ordered_question, {"0"=>"Test", "1"=>"Tes", "2"=>"Testing"})

    assert_equal [f_admin.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "value"=>ordered_qc_ids_hash["Tes"]}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_admin.id, f_mentor.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "value"=>ordered_qc_ids_hash["Test"]}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "value"=>ordered_qc_ids_hash["Testing"]}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})

    assert_equal [f_admin.id, f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "value"=>ordered_qc_ids_hash["Testing"], "operator"=>SurveyResponsesDataService::Operators::NOT_CONTAINS}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "value"=>"#{ordered_qc_ids_hash['Testing']},#{ordered_qc_ids_hash['Tes']}", "operator"=>SurveyResponsesDataService::Operators::NOT_CONTAINS}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})

     assert_equal [f_admin.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "choice"=>ordered_qc_ids_hash["Tes"]}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})
    assert_equal [f_admin.id, f_mentor.id, f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "choice"=>ordered_qc_ids_hash["Test"]}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})
    assert_equal [f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "choice"=>ordered_qc_ids_hash["Testing"]}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})

    assert_equal [f_admin.id, f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "choice"=>ordered_qc_ids_hash["Testing"], "operator"=>SurveyResponsesDataService::Operators::NOT_CONTAINS}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})
  end

  def test_apply_profile_filtering_for_multi_choice_question_and_ordered_options_type_question_quoted_choices
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)

    question = create_question(:question_choices => ["Test", "Tes", "Tes'ting"], :question_type => ProfileQuestion::Type::MULTI_CHOICE)
    ordered_question = create_question(:question_choices => ["Test", "Tes", "Tes'ting"], :question_type => ProfileQuestion::Type::ORDERED_OPTIONS, options_count: 3)
    qc_ids_hash = {}
    question.question_choices.each {|qc| qc_ids_hash[qc.text] = qc.id.to_s}
    ordered_qc_ids_hash = {}
    ordered_question.question_choices.each {|qc| ordered_qc_ids_hash[qc.text] = qc.id.to_s}
    f_admin.save_answer!(question, ["Test", "Tes"])
    f_mentor.save_answer!(question, ["Test"])
    f_student.save_answer!(question, ["Test","Tes","Tes'ting"])

    f_admin.save_answer!(ordered_question, {"0"=>"Test", "1"=>"Tes"})
    f_mentor.save_answer!(ordered_question, {"0"=>"Test"})
    f_student.save_answer!(ordered_question, {"0"=>"Test", "1"=>"Tes", "2"=>"Tes'ting"})
    # Multichoice
    assert_equal [f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=> qc_ids_hash["Tes'ting"]}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    # Ordered options
    assert_equal [f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "value"=> ordered_qc_ids_hash["Tes'ting"]}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})

    assert_equal [f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "choice"=>qc_ids_hash["Tes'ting"]}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})
    # Ordered options
    assert_equal [f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{ordered_question.id}", "choice"=>ordered_qc_ids_hash["Tes'ting"]}], {:is_program_view => true, :program_id => program.id, :for_report_filter => true})
  end

  def test_apply_profile_filtering_for_publication_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_student.profile_answers.map(&:destroy)
    question = create_question(:question_type => ProfileQuestion::Type::PUBLICATION, :question_text => "Publication", :organization => programs(:org_primary))

    default_publication_options = {
      title: 'A',
      authors: 'A',
      publisher: 'Mech',
      year: 2010,
      month: 1,
      day: 1
    }

    create_publication_answers(f_admin, question, [
      default_publication_options.merge(title: 'bu', authors: 'A')
    ])
    create_publication_answers(f_mentor, question, [
      default_publication_options.merge(title: 'A', authors: 'A', year: 2005),
      default_publication_options.merge(title: 'bz', authors: 'B')
    ])

    assert_equal [f_admin.id, f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"A"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"A", "operator"=>SurveyResponsesDataService::Operators::NOT_CONTAINS}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
  end

  def test_apply_profile_filtering_for_text_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)

    question = profile_questions(:profile_questions_4)

    f_admin.save_answer!(question, 'Bu')
    f_mentor.save_answer!(question, 'Bz')
    f_student.save_answer!(question, 'ba')

    assert_equal [f_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"ba"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_admin.id, f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question.id}", "value"=>"ba", "operator"=>SurveyResponsesDataService::Operators::NOT_CONTAINS}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
  end

  def test_apply_profile_filtering_for_date_question
    program = programs(:albers)

    f_mentor  = users(:f_mentor)
    f_admin   = users(:f_admin)
    f_mentor_student = users(:f_mentor_student)

    question = profile_questions(:date_question)

    assert_equal [f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_mentor_student.id], [{"field"=>"column#{question.id}", "value"=>"06/22/2017 - 06/24/2017"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_mentor_student.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_mentor_student.id], [{"field"=>"column#{question.id}", "value"=>"06/25/2017"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [f_mentor.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_mentor_student.id], [{"field"=>"column#{question.id}", "value"=>" - 06/23/2017"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
    assert_equal [], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_mentor_student.id], [{"field"=>"column#{question.id}", "value"=>"01/01/2018 - 02/02/2018"}], {:is_program_view => true, :program_id => program.id, :for_survey_response_filter => true})
  end

  def test_should_filter_profile_question
    question = profile_questions(:date_question)
    assert_false UserAndMemberFilterService.should_filter_profile_question?(nil, [], {"field" => 1})
    assert UserAndMemberFilterService.should_filter_profile_question?(question, [], {"field" => 1})
    assert_false UserAndMemberFilterService.should_filter_profile_question?(question, [1, 2], {"field" => 1})
  end

  def test_date_profile_filter_from_admin_view
    assert UserAndMemberFilterService.date_profile_filter_from_admin_view?({"operator" => "eq"})
    assert_false UserAndMemberFilterService.date_profile_filter_from_admin_view?({"operator" => "no"})
  end

  def test_apply_profile_filtering_for_work_question
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_student.profile_answers.map(&:destroy)
    question = profile_questions(:profile_questions_7)
    prog_admin_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    prog_admin_view.admin_view_columns.create!(profile_question: question)
    question_column = prog_admin_view.admin_view_columns.where(:profile_question_id => question.id).first

    default_education_options = {
      job_title: 'A',
      start_year: 1990,
      end_year: 1995,
      company: 'B'
    }

    create_experience_answers(f_admin, question, [
      default_education_options.merge(job_title: 'Bu', end_year:2001)
    ])
    create_experience_answers(f_mentor, question, [
      default_education_options.merge(job_title: 'A', end_year:2001),
      default_education_options.merge(job_title: 'Bz', end_year:2002)
    ])

    assert_equal [f_admin.id], UserAndMemberFilterService.apply_profile_filtering([f_admin.id, f_mentor.id, f_student.id], [{"field"=>"column#{question_column.id}", "value"=>"Bu"}], {:is_program_view => true, :program_id => program.id})
  end
end