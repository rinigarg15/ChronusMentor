require_relative './../test_helper.rb'

class RoleQuestionTest < ActiveSupport::TestCase
  def test_required_fields
    prof_q =  create_question
    e = assert_raise(ActiveRecord::RecordInvalid) do
      RoleQuestion.create!(:profile_question => prof_q)
    end

    assert_match(/Role can't be blank/, e.message)
  end

  def test_admin_only_editable_scope
    program = programs(:albers)
    role_question = role_questions(:role_questions_1)
    assert_empty program.role_questions.admin_only_editable
    role_question.update_attributes!(admin_only_editable: true)
    assert role_question.admin_only_editable?
    assert program.reload.role_questions.admin_only_editable.include?(role_question)
    assert_equal 1, program.role_questions.admin_only_editable.size
  end

  def test_should_create_question
    assert_difference 'RoleQuestion.count' do
      create_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?", :role_names => [RoleConstants::STUDENT_NAME], :private => RoleQuestion::PRIVACY_SETTING::RESTRICTED, :privacy_settings => [RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS])
    end
    q = RoleQuestion.last
    assert_equal "Whats your age?", q.question_text
    assert q.private?
    assert q.extra_private?
    assert_false q.filterable?
  end

  def test_should_have_filterable_false_private_false
    assert_difference 'RoleQuestion.count' do
      create_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?", :role_names => [RoleConstants::STUDENT_NAME], :filterable => false)
    end
    q = RoleQuestion.last
    assert_false q.filterable?
    assert_false q.private?
    assert_false q.extra_private?
  end

  def test_when_filterable_private_true_hack_protection
    assert_difference 'RoleQuestion.count' do
      create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?", :role_names => [RoleConstants::STUDENT_NAME], :filterable => true, :private => RoleQuestion::PRIVACY_SETTING::RESTRICTED, :privacy_settings => [RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS])
    end
    q = RoleQuestion.last
    assert_false q.filterable?
    assert q.private?
    assert q.extra_private?
  end

  def test_for_role_for_mentor_for_student_named_scope
    programs(:albers).role_questions.all.collect(&:destroy)
    mentor_q = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    mentor_role_q = mentor_q.role_questions.first
    student_q = create_question(:role_names => [RoleConstants::STUDENT_NAME])
    student_role_q = student_q.role_questions.first

    assert_equal_unordered([mentor_role_q, student_role_q], programs(:albers).role_questions.reload)
    assert_equal([mentor_role_q], programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME))
    assert_equal([student_role_q], programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME))
  end

  def test_for_membership_profile_role_questions_named_scope
    programs(:albers).role_questions.all.collect(&:destroy)
    mentor_q = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    mentor_role_q = mentor_q.role_questions.first

    mentor_role_q.update_attributes(:available_for => RoleQuestion::AVAILABLE_FOR::BOTH)
    assert_equal [mentor_role_q], programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).role_profile_questions
    assert_equal [mentor_role_q], programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).membership_questions
    assert mentor_role_q.membership_question?
    assert mentor_role_q.role_profile_question?
    assert mentor_role_q.publicly_accessible?

    mentor_role_q.update_attributes(:available_for => RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    assert_equal [], programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).role_profile_questions
    assert_equal [mentor_role_q], programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).membership_questions
    assert mentor_role_q.membership_question?
    assert mentor_role_q.publicly_accessible?
    assert_false mentor_role_q.role_profile_question?

    mentor_role_q.update_attributes(:available_for => RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS)
    assert_equal [mentor_role_q], programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).role_profile_questions
    assert_equal [], programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).membership_questions
    assert_false mentor_role_q.membership_question?
    assert_false mentor_role_q.publicly_accessible?
    assert mentor_role_q.role_profile_question?
  end

  def test_matchable_type
    assert role_questions(:string_role_q).matchable_type?
    assert role_questions(:single_choice_role_q).matchable_type?
    assert role_questions(:multi_choice_role_q).matchable_type?

    text_q = create_question(:question_type => ProfileQuestion::Type::TEXT)
    text_role_q = text_q.role_questions.first
    assert text_role_q.matchable_type?

    file_q = create_question(:question_type => ProfileQuestion::Type::FILE, :filterable => false)
    file_role_q = file_q.role_questions.reload.first
    assert_false file_role_q.matchable_type?

    rating_q = create_question(
      question_type: ProfileQuestion::Type::RATING_SCALE,
      question_choices: "1,2,3"
    )

    rating_role_q = rating_q.role_questions.first
    assert_false rating_role_q.matchable_type?
  end

  def test_no_question_notification_if_not_production_or_test
    ENV["RAILS_ENV"] = "staging"

    assert_no_emails do
      assert_difference 'RoleQuestion.count' do
        @question = create_question(:role_names => [RoleConstants::STUDENT_NAME])
      end
    end

    assert_no_emails do
      assert(@question.update_attribute(:question_text, "New text"))
    end

    ENV["RAILS_ENV"] = "test"
  end

  def test_disable_for_advanced_search
    role_question = role_questions(:role_questions_1)

    assert role_question.profile_question.name_type?
    assert role_question.disable_for_advanced_search?

    role_question = role_questions(:mentor_file_upload_role_q)

    assert_false role_question.profile_question.name_type?
    assert role_question.profile_question.file_type?
    assert role_question.disable_for_advanced_search?

    role_question = role_questions(:role_questions_2)

    assert_false role_question.profile_question.name_type?
    assert_false role_question.profile_question.file_type?

    role_question.expects(:private?).returns(true)
    assert role_question.disable_for_advanced_search?

    role_question.expects(:private?).returns(false)
    assert_false role_question.disable_for_advanced_search?
  end

  def test_disable_for_users_listing
    role_question = role_questions(:role_questions_1)

    assert role_question.profile_question.name_type?
    assert role_question.disable_for_users_listing?

    role_question = role_questions(:role_questions_2)

    assert_false role_question.profile_question.name_type?

    role_question.expects(:extra_private?).returns(true)
    assert role_question.disable_for_users_listing?

    role_question.expects(:extra_private?).returns(false)
    assert_false role_question.disable_for_users_listing?
  end

  def test_is_visible_for_accecpted_meeting
    chronus_s3_utils_stub
    q = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    role_q = q.role_questions.first
    assert_false role_q.private?
    assert role_q.filterable?
    assert role_q.visible_for?(nil, users(:f_mentor))

    role_q.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    role_q.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    assert role_q.private?
    assert role_q.extra_private?
    assert_false role_q.filterable? # Making sure that the flag is set to false
    assert_false role_q.in_summary? # In-summary should be false of connected members only visible role question

    assert_false role_q.visible_for?(users(:f_student), users(:f_mentor))
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, members: [members(:f_student), members(:f_mentor)], :requesting_student => users(:f_student))
    assert_false role_q.visible_for?(users(:f_student), users(:f_mentor))
    meeting.member_meetings.each do |mm|
      mm.update_attributes(attending: MemberMeeting::ATTENDING::YES)
    end
    assert role_q.visible_for?(users(:f_student), users(:f_mentor))
  end

  def test_is_visible    
    q = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    role_q = q.role_questions.first
    assert_false role_q.private?
    assert role_q.filterable?
    assert role_q.visible_for?(nil, users(:f_mentor))

    role_q.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    role_q.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    assert role_q.private?
    assert role_q.extra_private?
    assert_false role_q.filterable? # Making sure that the flag is set to false
    assert_false role_q.in_summary? # In-summary should be false of connected members only visible role question

    # When current user is nil
    assert_false role_q.visible_for?(nil, users(:f_mentor))
    # When users(:f_mentor_student) is viewing the profile of users(:f_mentor)
    assert_false  role_q.visible_for?(users(:f_mentor_student), users(:f_mentor))
    # When owner of the profile is seeing his own profile
    assert role_q.visible_for?(users(:f_mentor), users(:f_mentor))
    # When admin is seeing the profile of users(:f_mentor)
    assert role_q.visible_for?(users(:f_admin), users(:f_mentor))
    # When student is seeing the profile of his mentor
    assert role_q.visible_for?(users(:mkr_student), users(:f_mentor))    

    role_q.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
    assert role_q.private?
    assert role_q.extra_private?

    # When current user is nil
    assert_false role_q.visible_for?(nil, users(:f_mentor))
    # When users(:f_mentor_student) is viewing the profile of users(:f_mentor)
    assert_false  role_q.visible_for?(users(:f_mentor_student), users(:f_mentor))
    # When owner of the profile is seeing his own profile
    assert role_q.visible_for?(users(:f_mentor), users(:f_mentor))
    # When admin is seeing the profile of users(:f_mentor)
    assert role_q.visible_for?(users(:f_admin), users(:f_mentor))
    # When student is seeing the profile of his mentor
    assert_false role_q.visible_for?(users(:mkr_student), users(:f_mentor))
    # In-summary should be false of admin_only visible role question
    assert_false role_q.in_summary

    role_q.privacy_settings.destroy_all
    role_q.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    role_q.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME).id)
    assert role_q.private?
    assert_false role_q.extra_private?

    # When current user is nil
    assert_false role_q.visible_for?(nil, users(:f_mentor))
    # When users(:f_student) is viewing the profile of users(:f_mentor)
    assert_false role_q.visible_for?(nil, users(:f_student))
    # When users(:f_mentor_student) is viewing the profile of users(:f_mentor)
    assert role_q.visible_for?(users(:f_mentor_student), users(:f_mentor))
    # When owner of the profile is seeing his own profile
    assert role_q.visible_for?(users(:f_mentor), users(:f_mentor))
    # When admin is seeing the profile of users(:f_mentor)
    assert role_q.visible_for?(users(:f_admin), users(:f_mentor))
    # When student is seeing the profile of his mentor
    assert_false role_q.visible_for?(users(:mkr_student), users(:f_mentor))

    assert_false role_q.restricted_to_admin_alone?

    role_q.privacy_settings.destroy_all
    role_q.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME).id)
    assert role_q.private?
    assert_false role_q.extra_private?

    # When current user is nil
    assert_false role_q.visible_for?(nil, users(:f_student))
    # When users(:f_mentor) is viewing the profile of users (:f_student)
    assert_false role_q.visible_for?(nil, users(:f_mentor))
    # When users(:f_mentor_student) is viewing the profile of users(:f_student)
    assert role_q.visible_for?(users(:f_mentor_student), users(:f_student))
    # When owner of the profile is seeing his own profile
    assert role_q.visible_for?(users(:f_student), users(:f_student))
    # When admin is seeing the profile of users(:f_student)
    assert role_q.visible_for?(users(:f_admin), users(:f_student))
    # When mentor is seeing the profile of his student
    assert_false role_q.visible_for?(users(:f_mentor), users(:mkr_student))

    assert_false role_q.restricted_to_admin_alone?

    role_q.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    role_q.reload
    assert role_q.restricted_to_admin_alone?
    assert role_q.private?
    assert role_q.extra_private?

    # When current user is nil
    assert_false role_q.visible_for?(nil, users(:f_mentor))
    # When users(:f_mentor_student) is viewing the profile of users(:f_mentor)
    assert_false  role_q.visible_for?(users(:f_mentor_student), users(:f_mentor))
    # When owner of the profile is seeing his own profile
    assert_false role_q.visible_for?(users(:f_mentor), users(:f_mentor))
    # When admin is seeing the profile of users(:f_mentor)
    assert role_q.visible_for?(users(:f_admin), users(:f_mentor))
    # When student is seeing the profile of his mentor
    assert_false role_q.visible_for?(users(:mkr_student), users(:f_mentor))
    # In-summary should be false of admin_only visible role question
    assert_false role_q.in_summary
  end

  def test_visible_listing_page
    q = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    role_q = q.role_questions.first
    assert_false role_q.private?
    assert role_q.filterable?
    assert role_q.visible_listing_page?(nil, users(:f_mentor))

    role_q.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    role_q.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    assert role_q.private?
    assert role_q.extra_private?
    assert_false role_q.filterable? # Making sure that the flag is set to false
    assert_false role_q.in_summary? # In-summary should be false of connected members only visible role question

    # When current user is nil
    assert_false role_q.visible_listing_page?(nil, users(:f_mentor))
    # When users(:f_mentor_student) is viewing the profile of users(:f_mentor)
    assert_false  role_q.visible_listing_page?(users(:f_mentor_student), users(:f_mentor))
    # When owner of the profile is seeing his own profile
    assert role_q.visible_listing_page?(users(:f_mentor), users(:f_mentor))
    # When admin is seeing the profile of users(:f_mentor)
    assert role_q.visible_listing_page?(users(:f_admin), users(:f_mentor))
    # When student is seeing the profile of his mentor
    assert role_q.visible_listing_page?(users(:mkr_student), users(:f_mentor))

    role_q.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
    assert role_q.private?
    assert role_q.extra_private?

    # When current user is nil
    assert_false role_q.visible_listing_page?(nil, users(:f_mentor))
    # When users(:f_mentor_student) is viewing the profile of users(:f_mentor)
    assert_false  role_q.visible_listing_page?(users(:f_mentor_student), users(:f_mentor))
    # When admin is seeing the profile of users(:f_mentor)
    assert role_q.visible_listing_page?(users(:f_admin), users(:f_mentor))
    # When student is seeing the profile of his mentor
    assert_false role_q.visible_listing_page?(users(:mkr_student), users(:f_mentor))
    # In-summary should be false of admin_only visible role question
    assert_false role_q.in_summary

    role_q.privacy_settings.destroy_all
    role_q.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    role_q.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME).id)
    assert role_q.private?
    assert_false role_q.extra_private?

    # When current user is nil
    assert_false role_q.visible_listing_page?(nil, users(:f_mentor))
    # When users(:f_student) is viewing the profile of users(:f_mentor)
    assert_false role_q.visible_listing_page?(nil, users(:f_student))
    # When users(:f_mentor_student) is viewing the profile of users(:f_mentor)
    assert role_q.visible_listing_page?(users(:f_mentor_student), users(:f_mentor))
    # When owner of the profile is seeing his own profile
    assert role_q.visible_listing_page?(users(:f_mentor), users(:f_mentor))
    # When admin is seeing the profile of users(:f_mentor)
    assert role_q.visible_listing_page?(users(:f_admin), users(:f_mentor))
    # When student is seeing the profile of his mentor
    assert_false role_q.visible_listing_page?(users(:mkr_student), users(:f_mentor))

    assert_false role_q.restricted_to_admin_alone?

    role_q.privacy_settings.destroy_all
    role_q.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME).id)
    assert role_q.private?
    assert_false role_q.extra_private?

    # When current user is nil
    assert_false role_q.visible_listing_page?(nil, users(:f_student))
    # When users(:f_mentor) is viewing the profile of users (:f_student)
    assert_false role_q.visible_listing_page?(nil, users(:f_mentor))
    # When users(:f_mentor_student) is viewing the profile of users(:f_student)
    assert role_q.visible_listing_page?(users(:f_mentor_student), users(:f_student))
    # When admin is seeing the profile of users(:f_student)
    assert role_q.visible_listing_page?(users(:f_admin), users(:f_student))
    # When mentor is seeing the profile of his student
    assert_false role_q.visible_listing_page?(users(:f_mentor), users(:mkr_student))

    assert_false role_q.restricted_to_admin_alone?

    role_q.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    role_q.reload
    assert role_q.restricted_to_admin_alone?
    assert role_q.private?
    assert role_q.extra_private?

    # When current user is nil
    assert_false role_q.visible_listing_page?(nil, users(:f_mentor))
    # When users(:f_mentor_student) is viewing the profile of users(:f_mentor)
    assert_false  role_q.visible_listing_page?(users(:f_mentor_student), users(:f_mentor))
    # When admin is seeing the profile of users(:f_mentor)
    assert role_q.visible_listing_page?(users(:f_admin), users(:f_mentor))
    # When student is seeing the profile of his mentor
    assert_false role_q.visible_listing_page?(users(:mkr_student), users(:f_mentor))
    # In-summary should be false of admin_only visible role question
    assert_false role_q.in_summary
  end

  def test_required_named_scope
    p = programs(:albers)
    assert_equal(28, p.reload.role_questions_for(RoleConstants::MENTOR_NAME).size)
    assert_equal(2, p.role_questions_for(RoleConstants::MENTOR_NAME).required.size) # Email Question and Name Question
    email_mentor_q = p.role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question.email_type?}.first
    name_mentor_q = p.role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question.name_type?}.first

    role_questions(:string_role_q).update_attributes!(:required => true)
    role_questions(:single_choice_role_q).update_attributes!(:required => true)
    assert_equal([name_mentor_q, email_mentor_q, role_questions(:string_role_q), role_questions(:single_choice_role_q)], p.reload.role_questions_for(RoleConstants::MENTOR_NAME).required)
  end

  def test_program
    assert_equal programs(:albers), role_questions(:string_role_q).program
  end

  def test_should_not_create_match_config_for_file_and_rating_types
    program = programs(:albers)
    # No pair yet. Cant create match.
    assert_no_difference 'MatchConfig.count' do
      create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::RATING_SCALE, :question_info => "1,2,3", :question_text => "Blah Blah Blah")
    end
    prof_q = ProfileQuestion.last

    # Should not create match.
    assert_no_difference 'MatchConfig.count' do
      stud_q = prof_q.role_questions.new()
      stud_q.role = program.get_role(RoleConstants::STUDENT_NAME)
      stud_q.save!
    end

    # For file type.
    assert_no_difference 'MatchConfig.count' do
      create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::FILE, :question_text => "Blah Blah Blah", :filterable => false)
    end
    prof_q = ProfileQuestion.last

    # Should not create match.
    assert_no_difference 'MatchConfig.count' do
      stud_q = prof_q.role_questions.new(:filterable => false)
      stud_q.role = program.get_role(RoleConstants::STUDENT_NAME)
      stud_q.save!
    end
  end

  # MatchConfig should be destroyed while destroying a question.
  def test_has_many_match_configs_should_dependent_destroy_match_config
    matching_setup
    assert_difference 'MatchConfig.count', 1 do
      matching_setup
    end

    match_config = MatchConfig.last
    assert_equal [match_config], @student_question.matching_questions
    assert_equal [match_config], @mentor_question.matching_questions

    assert_difference 'MatchConfig.count', -1 do
      @student_question.destroy
    end

    programs(:albers).reload
    prof_q = @mentor_question.profile_question
    assert_difference 'MatchConfig.count' do
      @student_question = prof_q.role_questions.new
      @student_question.role = @program.get_role(RoleConstants::STUDENT_NAME)
      @student_question.save!
      MatchConfig.create!(:program_id => programs(:albers).id, :mentor_question => @mentor_question,
        :student_question => @student_question)
    end

    assert_difference 'MatchConfig.count', -1 do
      @mentor_question.reload.destroy
    end
  end

  def test_refresh_role_questions_match_config_cache
    @program = programs(:albers)
    prof_q = create_question(:program => programs(:albers),:role_names => [RoleConstants::MENTOR_NAME], :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A", "B", "C", "E", "F"], :required => true)
    @mentor_question = prof_q.role_questions.reload.first
    @student_question = prof_q.role_questions.new
    @student_question.role = @program.get_role(RoleConstants::STUDENT_NAME)
    @student_question.save!
    MatchConfig.create!(:program => @program, :mentor_question => @mentor_question, :student_question => @student_question)
    MatchConfig.any_instance.expects(:refresh_match_config_discrepancy_cache).once
    @student_question.refresh_role_questions_match_config_cache

    matching_setup
    MatchConfig.any_instance.expects(:refresh_match_config_discrepancy_cache).never
    @student_question.refresh_role_questions_match_config_cache
  end

  def test_match_config_creation_for_program_question
    assert_difference 'MatchConfig.count', 1 do
      matching_setup
    end

    program = programs(:albers)
    match_config = program.match_configs.last
    assert_equal @mentor_question, match_config.mentor_question
    assert_equal @student_question, match_config.student_question

  end

  def test_question_type_validation
    ques = role_questions(:mentor_file_upload_role_q)
    ques.update_attribute(:filterable, true)
    assert_false ques.valid?
    assert_equal ques.errors[:filterable], [RoleQuestion::QUESTION_FILTERABLE_ERROR]
  end

  def test_uniqueness_of_role_question
    prof_q = create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_text => "Check Uniqueness")
    assert_equal 1, prof_q.role_questions.count

    #Create Student Role Question
    stud_q = prof_q.role_questions.new()
    stud_q.role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    stud_q.save!
    assert_equal 2, prof_q.role_questions.count

    #Create Mentor Role Question again raises error
    e = assert_raise(ActiveRecord::RecordInvalid) do
      ment_q = prof_q.role_questions.new()
      ment_q.role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
      ment_q.save!
    end
    assert_match(/Role has already been taken/, e.message)

    #Create Mentor Role Question for Other Program should not raise error
    ment_q = prof_q.role_questions.new()
    ment_q.role = programs(:nwen).get_role(RoleConstants::MENTOR_NAME)
    ment_q.save!
    assert_equal 3, prof_q.role_questions.count
  end

  def test_for_user
    q_view = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    role_q_view = q_view.role_questions.first
    role_q_view.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    role_q_view.reload

    q_edit = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    role_q_edit = q_edit.role_questions.first
    role_q_edit.update_attributes!(:admin_only_editable => true)
    role_q_edit.reload

    program = programs(:albers)
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)

    assert program.role_questions.for_user(user: admin_user).include?(role_q_view)
    assert RoleQuestion.for_user_from_loaded_role_questions(program.role_questions, user: admin_user).include?(role_q_view)
    assert program.role_questions.for_user(user: admin_user).include?(role_q_edit)
    assert RoleQuestion.for_user_from_loaded_role_questions(program.role_questions, user: admin_user).include?(role_q_edit)
    assert_false program.role_questions.for_user(user: mentor_user).include?(role_q_view)
    assert_false RoleQuestion.for_user_from_loaded_role_questions(program.role_questions, user: mentor_user).include?(role_q_view)
    assert program.role_questions.for_user(user: mentor_user).include?(role_q_edit)
    assert RoleQuestion.for_user_from_loaded_role_questions(program.role_questions, user: mentor_user).include?(role_q_edit)
    assert program.role_questions.for_user(user: mentor_user, edit: false).include?(role_q_edit)
    assert RoleQuestion.for_user_from_loaded_role_questions(program.role_questions, user: mentor_user, edit: false).include?(role_q_edit)
    assert_false program.role_questions.for_user(user: mentor_user, edit: true).include?(role_q_edit)
    assert_false RoleQuestion.for_user_from_loaded_role_questions(program.role_questions, user: mentor_user, edit: true).include?(role_q_edit)
    assert program.role_questions.for_user(user: mentor_user, fetch_all: true).include?(role_q_view)
    assert RoleQuestion.for_user_from_loaded_role_questions(program.role_questions, user: mentor_user, fetch_all: true).include?(role_q_view)
    assert program.role_questions.for_user(user: mentor_user, fetch_all: true, edit: true).include?(role_q_edit)
    assert RoleQuestion.for_user_from_loaded_role_questions(program.role_questions, user: mentor_user, fetch_all: true , edit: true).include?(role_q_edit)
    assert program.role_questions.for_user(user: nil, fetch_all: true).include?(role_q_view)
    assert RoleQuestion.for_user_from_loaded_role_questions(program.role_questions, user: nil, fetch_all: true).include?(role_q_edit)
    assert program.role_questions.for_user(user: nil, fetch_all: true, edit: true).include?(role_q_edit)
    assert RoleQuestion.for_user_from_loaded_role_questions(program.role_questions, user: nil, fetch_all: true, edit: true).include?(role_q_edit)
  end


  def test_available_for_role_profile_question
  end

  def test_available_for_membership_question
  end

  def test_for_viewing_by
    q_view = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    role_q_view = q_view.role_questions.first
    role_q_view.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    role_q_view.reload
    program = programs(:albers)
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)

    assert program.role_questions.for_viewing_by(admin_user).include?(role_q_view)
    assert_false program.role_questions.for_viewing_by(mentor_user).include?(role_q_view)
    assert program.role_questions.for_viewing_by(mentor_user, true).include?(role_q_view)
    assert program.role_questions.for_viewing_by(nil, true).include?(role_q_view)
  end

  def test_for_editing_by
    q_edit = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    role_q_edit = q_edit.role_questions.first
    role_q_edit.update_attributes!(:admin_only_editable => true)
    role_q_edit.reload
    program = programs(:albers)
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)

    assert program.role_questions.for_editing_by(admin_user).include?(role_q_edit)
    assert_false program.role_questions.for_editing_by(mentor_user).include?(role_q_edit)
    assert program.role_questions.for_editing_by(mentor_user, true).include?(role_q_edit)
    assert program.role_questions.for_editing_by(nil, true).include?(role_q_edit)
  end

  def test_can_be_membership_question
    q = RoleQuestion.last
    assert_false q.admin_only_editable?
    assert_false q.restricted_to_admin_alone?
    assert q.can_be_membership_question?
    q.update_attributes!(:admin_only_editable => true)
    assert q.admin_only_editable?
    assert_false q.can_be_membership_question?
    q.update_attributes!(:admin_only_editable => false, :private => RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert q.restricted_to_admin_alone?
    assert_false q.can_be_membership_question?
  end

  def test_not_applicable_answer_updating_if_question_become_required
    member = members(:f_student)
    gender_question = programs(:org_primary).profile_questions_with_email_and_name.find_by(question_text: "Gender")
    mentor_gender_question = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question == gender_question}[0]
    answer = ProfileAnswer.create!(:profile_question => gender_question, :ref_obj => member, :not_applicable => true)
    assert answer.not_applicable
    assert_equal [answer], member.profile_answers

    assert_difference "ProfileAnswer.count", -1 do
      mentor_gender_question.update_attributes(:required => true)
    end
    assert_blank member.reload.profile_answers
  end

  def test_publicize_ckassets
    role_question = role_questions(:string_role_q)
    profile_question = role_question.profile_question
    asset = create_ckasset
    assert asset.login_required?

    profile_question.update_attributes(help_text: "Attachment: #{asset.url_content}")
    assert_false role_question.publicly_accessible?
    assert asset.reload.login_required?

    role_question.update_attributes(available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    assert role_question.publicly_accessible?
    assert_false asset.reload.login_required?
  end

  def test_show_all
    role_question = role_questions(:string_role_q)
    assert role_question.show_all?

    role_question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    assert_false role_question.show_all?

    role_question.private = RoleQuestion::PRIVACY_SETTING::ALL
    assert role_question.show_all?
  end

  def test_restricted
    role_question = role_questions(:string_role_q)
    assert_false role_question.restricted?

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    assert role_question.restricted?

    role_question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    assert_false role_question.restricted?
  end

  def test_restricted_to_admin_alone
    role_question = role_questions(:string_role_q)
    assert_false role_question.restricted_to_admin_alone?

    role_question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    assert role_question.restricted_to_admin_alone?

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    assert_false role_question.restricted_to_admin_alone?
  end

  def test_show_user
    role_question = role_questions(:string_role_q)
    assert role_question.show_user?

    role_question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    assert_false role_question.show_user?

    role_question.private = RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
    assert role_question.show_user?

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    assert role_question.show_user?
  end

  def test_show_connected_members
    role_question = role_questions(:string_role_q)
    assert role_question.show_connected_members?

    role_question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    assert_false role_question.show_connected_members?

    role_question.private = RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
    assert_false role_question.show_connected_members?

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    assert_false role_question.show_connected_members?

    role_question.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: role_question.program.roles.non_administrative.first.id)
    assert_false role_question.show_connected_members?

    role_question.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    assert role_question.show_connected_members?
  end

  def test_show_for_roles
    role_question = role_questions(:string_role_q)
    roles = role_question.program.roles.non_administrative
    mentor_role = roles.where(name: RoleConstants::MENTOR_NAME).first
    mentee_role = roles.where(name: RoleConstants::STUDENT_NAME).first

    assert role_question.show_for_roles?
    assert role_question.show_for_roles?(roles)

    role_question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    assert_false role_question.show_for_roles?(roles)

    role_question.private = RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
    assert_false role_question.show_for_roles?(roles)

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    assert_false role_question.show_for_roles?(roles)

    role_question.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    assert_false role_question.show_for_roles?(roles)

    role_question.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id)
    assert role_question.show_for_roles?(roles)
    assert role_question.show_for_roles?([mentor_role])
    assert_false role_question.show_for_roles?([mentee_role])
    assert_false role_question.show_for_roles?

    role_question.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentee_role.id)
    assert role_question.show_for_roles?(roles)
    assert role_question.show_for_roles?([mentor_role])
    assert role_question.show_for_roles?([mentee_role])
    assert_false role_question.show_for_roles?
  end

  def test_show_for
    role_question = role_questions(:string_role_q)
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::ALL)
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED)

    role_question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::ALL)
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED)

    role_question.private = RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::ALL)
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED)

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::ALL)
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED)

    roles = role_question.program.roles.non_administrative
    mentor_role = roles.where(name: RoleConstants::MENTOR_NAME).first
    mentee_role = roles.where(name: RoleConstants::STUDENT_NAME).first

    role_question.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED, {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS})
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED, {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id})
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED, {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentee_role.id})

    role_question.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id)
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED, {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS})
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED, {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id})
    assert_false role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED, {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentee_role.id})

    role_question.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentee_role.id)
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED, {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS})
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED, {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id})
    assert role_question.show_for?(RoleQuestion::PRIVACY_SETTING::RESTRICTED, {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentee_role.id})
  end

  def test_extra_private
    role_question = role_questions(:string_role_q)
    assert_false role_question.extra_private?

    role_question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    assert role_question.extra_private?

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    assert role_question.extra_private?

    role_question.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    assert role_question.extra_private?

    role_question.privacy_settings.create!(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: role_question.program.roles.non_administrative.first.id)
    assert_false role_question.extra_private?
  end

  def test_extra_private_for_new_record
    role_question = RoleQuestion.new
    assert_false role_question.extra_private?

    role_question.private = RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    assert role_question.extra_private?

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    assert role_question.extra_private?

    role_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    assert role_question.extra_private?

    role_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE)
    assert_false role_question.extra_private?
  end

  def test_privacy_settings_association
    role_question = role_questions(:private_role_q)
    assert_equal [role_question_privacy_settings(:connected_members_privacy_setting)], role_question.privacy_settings

    assert_difference 'RoleQuestionPrivacySetting.count', -1 do
      role_question.destroy
    end
  end

  def test_privacy_setting_options_for
    mentor_role = programs(:albers).roles.with_name(RoleConstants::MENTOR_NAME).first
    mentee_role = programs(:albers).roles.with_name(RoleConstants::STUDENT_NAME).first
    user_role = programs(:albers).roles.with_name("user").first
    expected_output = [
      {label: "Administrators", privacy_type: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, privacy_setting: {}},
      {label: "User", privacy_type: RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, privacy_setting: {}},
      {label: "User's mentoring connections", privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS, role_id: nil}},
      {label: "All mentors", privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id}},
      {label: "All students", privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentee_role.id}},
      {label: "All users", privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: user_role.id}}
    ]
    assert_equal expected_output, RoleQuestion.privacy_setting_options_for(programs(:albers))

    employee_role = programs(:primary_portal).roles.with_name(RoleConstants::EMPLOYEE_NAME).first
    expected_output = [
      {label: "Administrators", privacy_type: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, privacy_setting: {}},
      {label: "User", privacy_type: RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, privacy_setting: {}},
      {label: "All employees", privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED, privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: employee_role.id}}
    ]
    assert_equal expected_output, RoleQuestion.privacy_setting_options_for(programs(:primary_portal))
  end

  def test_show_in_summary
    role_question = role_questions(:string_role_q)
    role_question.in_summary = false
    assert_false role_question.show_in_summary?

    role_question.in_summary = true
    assert role_question.show_in_summary?

    role_question.private = RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
    assert_false role_question.show_in_summary?

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    role_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    assert_false role_question.show_in_summary?

    role_question.save!
    assert role_question.in_summary
    assert_false role_question.show_in_summary?

    mentor_role = role_question.program.roles.with_name(RoleConstants::MENTOR_NAME).first
    role_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id)
    assert role_question.in_summary
    assert role_question.show_in_summary?

    role_question.save!
    assert role_question.in_summary
    assert role_question.show_in_summary?
  end

  def test_shown_in_summary
    role_question = role_questions(:string_role_q)
    profile_question = role_question.profile_question
    assert_equal [], profile_question.role_questions.shown_in_summary

    role_question.update_attributes!(in_summary: true)
    assert_equal [role_question], profile_question.role_questions.shown_in_summary

    role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert role_question.in_summary
    assert_equal [], profile_question.role_questions.shown_in_summary

    role_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    role_question.update_attributes!(private: RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    assert role_question.in_summary
    assert_equal [], profile_question.role_questions.shown_in_summary

    mentor_role = role_question.program.roles.with_name(RoleConstants::MENTOR_NAME).first
    role_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: mentor_role.id)
    role_question.save!
    assert_equal [role_question], profile_question.role_questions.shown_in_summary
  end

  def test_delete_match_configs_for_portal_role_question
    role_question = role_questions(:nch_string_role_q)
    Matching.expects(:perform_program_delta_index_and_refresh).never
    role_question.delete_match_configs
  end

  def test_required
    role_question = role_questions(:nch_string_role_q)
    assert_false role_question.required?

    role_question.update_attributes!(required: true)
    assert role_question.reload.required?
  end

  private

  def matching_setup
    @program = programs(:albers)
    prof_q = create_question(:role_names => [RoleConstants::MENTOR_NAME], :question_text => "Test match config")
    @mentor_question = prof_q.role_questions.reload.first
    @student_question = prof_q.role_questions.new
    @student_question.role = @program.get_role(RoleConstants::STUDENT_NAME)
    @student_question.save!
    MatchConfig.create!(:program => @program, :mentor_question => @mentor_question, :student_question => @student_question)
  end
end