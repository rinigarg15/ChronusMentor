require_relative './../../test_helper.rb'

class ProfileQuestionObserverTest < ActiveSupport::TestCase
  def test_question_type_filterable
    q = create_question(:question_type => CommonQuestion::Type::FILE, :question_text => "Upload your Resume", :role_names => [:mentor], :program => programs(:albers), :filterable => false)
    assert_false q.reload.role_questions.first.filterable?
  end

  def test_question_type_private
    q = create_question(:question_type => CommonQuestion::Type::FILE, :question_text => "Upload your Resume", :role_names => [:mentor], :program => programs(:albers), :filterable => false, :private => RoleQuestion::PRIVACY_SETTING::RESTRICTED, :privacy_settings => [RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS])
    assert_equal q.reload.role_questions.first.private, RoleQuestion::PRIVACY_SETTING::RESTRICTED
  end

  def test_update_profile_question_type_and_match_configs
    program = programs(:albers)
    q1 = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Choice Field1", :question_choices => "Choice 1,Choice 2", :role_names => [:mentor], :program => program, :filterable => false)
    q1.save!
    assert_equal ["Choice 1","Choice 2"], q1.question_choices.collect(&:text)
    prof_q1 = ProfileQuestion.last
    mentor_q1 = prof_q1.role_questions.first
    assert_difference 'MatchConfig.count' do
      stud_q1 = prof_q1.role_questions.new()
      stud_q1.role = program.get_role(RoleConstants::STUDENT_NAME)
      stud_q1.save!
      MatchConfig.create!(:program => program, :mentor_question => mentor_q1, :student_question => stud_q1)
    end

    # Changing profile question type from a matchable type to another matchable type should not result in match-config changes
    prof_q1 = ProfileQuestion.last
    prof_q1.question_type = ProfileQuestion::Type::MULTI_CHOICE
    assert_no_difference 'MatchConfig.count' do
      prof_q1.save!
    end

    q2 = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Choice Field2", :question_choices => "Choice 1,Choice 2", :role_names => [:student], :program => program, :filterable => false)
    q2.save!
    assert_equal ["Choice 1","Choice 2"], q1.question_choices.collect(&:text)
    prof_q2 = ProfileQuestion.last
    student_q2 = prof_q2.role_questions.first
    assert_difference 'MatchConfig.count' do
      program.match_configs.create!(
          :mentor_question => mentor_q1,
          :student_question => student_q2)
    end

    # Changing profile question type from a matchable type to a un-matchable type should result in deletion of match-config changes
#    prof_q1 = ProfileQuestion.last
    prof_q1.question_type = ProfileQuestion::Type::FILE
    assert_difference 'MatchConfig.count', -2 do
      prof_q1.save!
    end

  end

  def test_allow_empty_profile_question_text
    user = users(:f_student)
    program = user.program
    question = create_question(question_type: ProfileQuestion::Type::MULTI_EDUCATION, question_text: "Education", role_names: [:student], program: program)
    run_in_another_locale(:'fr-CA') do
      question.update_attributes!(question_text: nil)
    end
    assert_equal "Education", question.question_text(:'fr-CA')
    assert_nil question.translation_for(:'fr-CA').question_text
  end

  def test_destroy_remove_diversity_reports_after_type_update
    organization = programs(:org_primary)
    admin_view = organization.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS)
    profile_question = profile_questions(:single_choice_q)
    diversity_report = organization.diversity_reports.new({admin_view: admin_view, profile_question: profile_question, comparison_type: DiversityReport::ComparisonType::TIME_PERIOD})
    diversity_report.save!
    assert_difference "DiversityReport.count", -1 do
      profile_question.question_type = ProfileQuestion::Type::TEXT
      profile_question.save!
    end
    assert_nil DiversityReport.find_by(id: diversity_report.id)
  end

  def test_change_multiple_edu_to_edu_should_keep_newest_answer
    program = programs(:albers)
    user = users(:f_student)
    edu_question = create_question(:question_type => ProfileQuestion::Type::MULTI_EDUCATION, :question_text => "Educatiion", :role_names => [:student], :program => program)
    edu3 = create_education(
      user, edu_question, :school_name => 'NIT', :degree => 'MCA', :major => "CSE", :graduation_year => 2012)
    edu1 = create_education(
      user, edu_question, :school_name => 'St.Marys', :degree => '12th', :major => "CS", :graduation_year => 2006)
    edu2 = create_education(
      user, edu_question, :school_name => 'Delhi University', :degree => 'B.Sc.', :major => "CSE", :graduation_year => 2009)
    assert_equal 3, members(:f_student).educations.count
    prof_q = ProfileQuestion.last
    prof_q.question_type = ProfileQuestion::Type::EDUCATION
    prof_q.save!
    assert_equal 1, members(:f_student).educations.count
    assert_equal edu3, members(:f_student).educations.first
  end

  def test_change_multiple_exp_to_exp_should_keep_newest_answer
    program = programs(:albers)
    user = users(:f_student)
    exp_question = create_question(:question_type => ProfileQuestion::Type::MULTI_EXPERIENCE, :question_text => "Experiience", :role_names => [:student], :program => program)
    e1 = create_experience(user, exp_question, :start_year => 1999, :end_year => 2000)
    e2 = create_experience(user, exp_question, :start_year => 2004, :end_year => nil,  :current_job => true)
    e3 = create_experience(user, exp_question, :start_year => 2001, :end_year => 2003)
    assert_equal 3, members(:f_student).experiences.count
    prof_q = ProfileQuestion.last
    prof_q.question_type = ProfileQuestion::Type::EXPERIENCE
    prof_q.save!
    assert_equal 1, members(:f_student).experiences.count
    assert_equal e2, members(:f_student).experiences.first
  end

  def test_change_multiple_publication_to_publication_should_keep_newest_answer
    program = programs(:albers)
    user = users(:f_student)
    pub_question = create_question(:question_type => ProfileQuestion::Type::MULTI_PUBLICATION, :question_text => "Publication", :organization => programs(:org_primary))
    pub1 = create_publication(user, pub_question)
    pub2 = create_publication(user, pub_question)
    pub3 = create_publication(user, pub_question)
    pub1.update_column(:created_at, '2005-01-01')
    pub2.update_column(:created_at, '2008-01-01')
    pub3.update_column(:created_at, '2010-01-01')
    assert_equal 3, members(:f_student).publications.count
    prof_q = ProfileQuestion.last
    prof_q.question_type = ProfileQuestion::Type::PUBLICATION
    prof_q.save!
    assert_equal 1, members(:f_student).publications.count
    assert_equal pub3, members(:f_student).publications.first
  end

  # Added for AP-9532
  def test_update_french_attributes_should_just_update_the_required_french_translations_and_not_everything
    question = create_question(question_type: ProfileQuestion::Type::MULTI_CHOICE, question_text: "Select Preference", question_choices: "alpha,beta,gamma", help_text: "Help Text")

    assert_equal "Select Preference", question.question_text
    assert_equal "Select Preference", question.question_text(:'fr-CA') #fallback
    assert_nil question.translation_for(:'fr-CA').question_text #without fallback
    assert_equal "Help Text", question.help_text(:'fr-CA') #fallback
    assert_nil question.translation_for(:'fr-CA').help_text #without fallback


    run_in_another_locale(:'fr-CA') do
      question.update_attributes!(:question_text => "Select Preference in French")
    end

    assert_equal "Select Preference", question.question_text
    assert_equal "Select Preference in French", question.question_text(:'fr-CA') #fallback
    assert_equal "Select Preference in French", question.translation_for(:'fr-CA').question_text #without fallback
    assert_nil question.translation_for(:'fr-CA').help_text #without fallback
  end

  def test_allow_other_option_and_strip_question_text_before_saving
    profile_question = ProfileQuestion.first
    profile_question.question_text = "  Question with Spacing  "
    profile_question.allow_other_option = true
    profile_question.save!
    assert_equal "Question with Spacing", profile_question.reload.question_text
    assert_equal false, profile_question.allow_other_option
  end

  def test_change_question_type_destroy_answers
    profile_question = profile_questions(:string_q)
    profile_answers = profile_question.profile_answers
    profile_answers_count = profile_answers.count
    assert (profile_answers_count > 0)

    ProfileQuestionExtension.stubs(:destroy_all_answers?).returns(true)
    ProfileQuestionExtension.stubs(:compact_ordered_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_answers?).returns(false)
    ProfileQuestionExtension.stubs(:keep_first_answer?).returns(false)

    profile_question.expects(:handle_ordered_options_to_choice_type_conversion).never
    profile_question.expects(:compact_multi_choice_answers).never
    profile_question.expects(:handle_choices_update).never
    assert_difference "ProfileAnswer.count", -profile_answers_count do
      profile_question.question_type = ProfileQuestion::Type::TEXT
      profile_question.save!
    end
  end

  def test_change_question_type_compact_ordered_answers
    profile_question = profile_questions(:string_q)
    profile_answers = profile_question.profile_answers
    profile_answers_count = profile_answers.count
    assert (profile_answers_count > 0)

    ProfileQuestionExtension.stubs(:destroy_all_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_ordered_answers?).returns(true)
    ProfileQuestionExtension.stubs(:compact_answers?).returns(false)
    ProfileQuestionExtension.stubs(:keep_first_answer?).returns(false)

    profile_question.expects(:handle_ordered_options_to_choice_type_conversion).once
    profile_question.expects(:compact_multi_choice_answer_choices).never
    profile_question.expects(:handle_choices_update).never
    assert_no_difference "ProfileAnswer.count" do
      profile_question.question_type = ProfileQuestion::Type::TEXT
      profile_question.save!
    end
  end

  def test_change_question_type_compact_answers
    profile_question = profile_questions(:string_q)
    profile_answers = profile_question.profile_answers
    profile_answers_count = profile_answers.count
    assert (profile_answers_count > 0)

    ProfileQuestionExtension.stubs(:destroy_all_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_ordered_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_answers?).returns(true)
    ProfileQuestionExtension.stubs(:keep_first_answer?).returns(false)

    profile_question.expects(:handle_ordered_options_to_choice_type_conversion).never
    profile_question.expects(:compact_multi_choice_answer_choices).with(profile_answers).once
    profile_question.expects(:handle_choices_update).never
    assert_no_difference "ProfileAnswer.count" do
      profile_question.question_type = ProfileQuestion::Type::TEXT
      profile_question.save!
    end
  end

  def test_change_allow_other_option_to_enabled_does_not_trigger_answers_update
    profile_question = profile_questions(:string_q)
    profile_answers = profile_question.profile_answers
    profile_answers_count = profile_answers.count
    assert (profile_answers_count > 0)
    assert_false profile_question.allow_other_option

    ProfileQuestionExtension.stubs(:destroy_all_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_ordered_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_answers?).returns(false)
    ProfileQuestionExtension.stubs(:keep_first_answer?).returns(false)

    profile_question.expects(:handle_ordered_options_to_choice_type_conversion).never
    profile_question.expects(:compact_multi_choice_answer_choices).never
    profile_question.expects(:handle_choices_update).never
    assert_no_difference "ProfileAnswer.count" do
      profile_question.allow_other_option = true
      profile_question.save!
    end
  end

  def test_change_allow_other_option_to_disabled_triggers_answers_update
    profile_question = profile_questions(:string_q)
    profile_answers = profile_question.profile_answers
    profile_answers_count = profile_answers.count
    assert (profile_answers_count > 0)
    profile_question.update_column(:allow_other_option, true)

    ProfileQuestionExtension.stubs(:destroy_all_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_ordered_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_answers?).returns(false)
    ProfileQuestionExtension.stubs(:keep_first_answer?).returns(false)

    profile_question.expects(:handle_ordered_options_to_choice_type_conversion).never
    profile_question.expects(:compact_multi_choice_answer_choices).never
    profile_question.expects(:handle_choices_update).once
    assert_no_difference "ProfileAnswer.count" do
      profile_question.allow_other_option = false
      profile_question.save!
    end
  end

  def test_decrease_in_options_count
    profile_question = create_profile_question(question_type: ProfileQuestion::Type::ORDERED_OPTIONS, options_count: 3, question_choices: "A,B,C,D,E")

    ProfileQuestionExtension.stubs(:destroy_all_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_ordered_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_answers?).returns(false)
    ProfileQuestionExtension.stubs(:keep_first_answer?).returns(false)

    profile_question.expects(:handle_ordered_options_to_choice_type_conversion).never
    profile_question.expects(:compact_multi_choice_answer_choices).never
    profile_question.expects(:handle_choices_update).once
    profile_question.options_count = 1
    profile_question.save!
  end

  def test_increase_in_options_count
    profile_question = create_profile_question(question_type: ProfileQuestion::Type::ORDERED_OPTIONS, options_count: 1, question_choices: "A,B,C,D,E")

    ProfileQuestionExtension.stubs(:destroy_all_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_ordered_answers?).returns(false)
    ProfileQuestionExtension.stubs(:compact_answers?).returns(false)
    ProfileQuestionExtension.stubs(:keep_first_answer?).returns(false)

    profile_question.expects(:handle_ordered_options_to_choice_type_conversion).never
    profile_question.expects(:compact_multi_choice_answer_choices).never
    profile_question.expects(:handle_choices_update).never
    profile_question.options_count = 2
    profile_question.save!
  end

  def test_enqueue_matching_indexer_when_question_type_changed
    profile_question = profile_questions(:single_choice_q)
    profile_question.stubs(:has_match_configs?).returns(true)

    Matching.expects(:perform_program_delta_index_and_refresh).times(profile_question.organization.programs.active.size)
    profile_question.question_type = ProfileQuestion::Type::MULTI_CHOICE
    profile_question.save!
  end

  def test_change_question_type_from_choice_based_to_non_choice_based
    profile_question = profile_questions(:single_choice_q)
    expected_text = profile_question.profile_answers.first.answer_text
    assert_difference "QuestionChoice.count", - profile_question.question_choices.size do
      assert_difference "AnswerChoice.count", - AnswerChoice.where(question_choice_id: profile_question.question_choices.pluck(:id)).size do
        assert_no_difference "ProfileAnswer.count" do
          profile_question.update_attributes!(question_type: ProfileQuestion::Type::TEXT)
        end
      end
    end
    assert_equal expected_text, profile_question.profile_answers.first.answer_text
  end

  def test_reset_match_configs
    program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    config = MatchConfig.create!(
        program: programs(:albers),
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")

    assert_equal [config.reload], MatchConfig.with_label
    assert_equal "abc", config.prefix
    assert config.show_match_label

    prof_q.update_attributes!(question_type: ProfileQuestion::Type::TEXT)
    assert_equal [], MatchConfig.with_label
    config.reload
    assert_equal "", config.prefix
    assert_false config.show_match_label
  end

  def test_no_reset_match_configs
    program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    config = MatchConfig.create!(
        program: programs(:albers),
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")

    assert_equal [config.reload], MatchConfig.with_label
    assert_equal "abc", config.prefix
    assert config.show_match_label

    prof_q.update_attributes!(question_type: ProfileQuestion::Type::MULTI_CHOICE)
    assert_equal [config], MatchConfig.with_label
    config.reload
    assert_equal "abc", config.prefix
    assert config.show_match_label
  end

  def test_cleanup_explicit_user_preferences
    program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    ExplicitUserPreference.create!(
      { user: users(:f_student),
        role_question: prog_mentor_question,
        question_choices: [prof_q.question_choices.first]
      })
    assert prog_mentor_question.explicit_user_preferences.present?
    prof_q.update_attributes!(question_type: ProfileQuestion::Type::TEXT)
    assert prog_mentor_question.reload.explicit_user_preferences.empty?
  end

end