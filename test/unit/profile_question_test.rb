
require_relative './../test_helper.rb'

class ProfileQuestionTest < ActiveSupport::TestCase
  def test_required_fields
    e = assert_raise(ActiveRecord::RecordInvalid) do
      ProfileQuestion.create!
    end

    assert_match(/Organization can't be blank/, e.message)
    assert_match(/Field Name can't be blank/, e.message)
    assert_match(/Field Type can't be blank/, e.message)
  end

  def test_should_create_question
    assert_difference 'ProfileQuestion.count' do
      create_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?")
    end
    q = ProfileQuestion.last
    assert_equal "Whats your age?", q.question_text
  end

  def test_publicize_ckassets
    role_question = role_questions(:string_role_q)
    profile_question = role_question.profile_question
    asset = create_ckasset
    assert asset.login_required?
    assert_false role_question.publicly_accessible?

    role_question.update_attributes(available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    profile_question.update_attributes(help_text: "Attachment: #{asset.url_content}")
    assert role_question.reload.publicly_accessible?
    assert profile_question.reload.publicly_accessible?
    assert_false asset.reload.login_required?
  end

  def test_publicly_accessible
    profile_question = profile_questions(:profile_questions_3)
    role_question_1 = profile_question.role_questions.first
    role_question_2 = profile_question.role_questions.second

    assert_false profile_question.publicly_accessible?

    role_question_1.update_attributes(available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    assert role_question_1.reload.publicly_accessible?
    assert_false role_question_2.reload.publicly_accessible?
    assert profile_question.reload.publicly_accessible?
  end

  def test_validate_text_only_type
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :question_type, "does not support not allowing digits") do
      create_question(:question_type => ProfileQuestion::Type::FILE, :text_only_option => true)
    end

    assert_difference 'ProfileQuestion.count', 1 do
      create_question(:question_type => ProfileQuestion::Type::STRING, :text_only_option => true)
    end
  end

  def test_no_question_notification_if_not_production_or_test
    ENV["RAILS_ENV"] = "staging"


    assert_no_emails do
      assert_difference 'ProfileQuestion.count' do
        @question = create_question(:role_names => [RoleConstants::STUDENT_NAME])
      end
    end

    assert_no_emails do
      assert(@question.update_attribute(:question_text, "New text"))
    end

    ENV["RAILS_ENV"] = "test"
  end

  def test_program
    assert_equal programs(:albers), role_questions(:string_role_q).program
  end

  def test_mandatory_for_any_roles_in
    roles = programs(:albers).roles
    location_profile_question = ProfileQuestion.where(question_type: ProfileQuestion::Type::LOCATION).first
    assert_false location_profile_question.mandatory_for_any_roles_in?(roles)
    location_profile_question.role_questions.where(role_id: roles[1].id).first.update_attributes(required: true)
    assert location_profile_question.mandatory_for_any_roles_in?(roles)
  end

  def test_role_profile_questions_with_role_ids
    program = programs(:albers)
    q1 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :question_choices => "Abc, Def", :role_names => [RoleConstants::MENTOR_NAME], :required => true, :question_text => "Whats your name12?")
    q2 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :question_choices => "Abc, Def", :role_names => [RoleConstants::STUDENT_NAME], :required => true, :question_text => "Whats your name34?")
    q3 = create_question(:program => programs(:albers), :question_type => ProfileQuestion::Type::TEXT, :question_choices => "Abc, Def", :role_names => [RoleConstants::ADMIN_NAME], :required => true, :question_text => "Whats your name56?")
    q1.role_questions.first.update_attributes!(available_for: 2)
    role_ids = program.roles.collect(&:id)

    assert_false programs(:albers).organization.profile_questions.role_profile_questions_with_role_ids(role_ids).include? q1
    assert programs(:albers).organization.profile_questions.role_profile_questions_with_role_ids(role_ids).include? q2
    assert programs(:albers).organization.profile_questions.role_profile_questions_with_role_ids(role_ids).include? q3
  end

  def test_question_text_with_mandatory_mark
    roles = programs(:albers).roles
    location_profile_question = ProfileQuestion.where(question_type: ProfileQuestion::Type::LOCATION).first
    assert_equal "Location", location_profile_question.question_text_with_mandatory_mark(roles)
    location_profile_question.role_questions.where(role_id: roles[1].id).first.update_attributes(required: true)
    assert_equal "Location *", location_profile_question.question_text_with_mandatory_mark(roles)
  end

  def test_default_questions_scope
    def_questions = programs(:org_primary).profile_questions_with_email_and_name.default_questions
    assert def_questions.first.name_type?
    assert def_questions.second.email_type?
    assert_equal 2,def_questions.count
  end

  def test_default_type_and_non_default_type
    profile_question = ProfileQuestion.new
    default_types = [ProfileQuestion::Type::NAME, ProfileQuestion::Type::EMAIL]

    default_types.each do |question_type|
      profile_question.question_type = question_type
      assert profile_question.default_type?
      assert_false profile_question.non_default_type?
    end

    (ProfileQuestion::Type.all - default_types).each do |question_type|
      profile_question.question_type = question_type
      assert profile_question.non_default_type?
      assert_false profile_question.default_type?
    end
  end

  def test_email_skype_name_scopes
    email_ques = programs(:org_primary).profile_questions_with_email_and_name.email_question.first
    name_ques = programs(:org_primary).profile_questions_with_email_and_name.name_question.first
    assert email_ques.email_type?
    assert name_ques.name_type?
    assert_false programs(:org_primary).profile_questions_with_email_and_name.except_email_and_name_question.include?(email_ques)
    assert_false programs(:org_primary).profile_questions_with_email_and_name.except_email_and_name_question.include?(name_ques)

    email_ques = programs(:org_primary).profile_questions.email_question.first
    name_ques = programs(:org_primary).profile_questions.name_question.first

    assert_nil email_ques
    assert_nil name_ques

    skype_ques = programs(:org_primary).profile_questions.skype_question.first
    assert skype_ques.skype_id_type?
    assert_false programs(:org_primary).profile_questions.except_skype_question.include?(skype_ques)
  end

  def test_experience_questions_scope
    assert_equal programs(:org_primary).profile_questions.where("question_type IN (?)", [ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE]), programs(:org_primary).profile_questions.experience_questions
  end

  def test_multi_field_questions_scope
    organization = programs(:org_primary)
    profile_questions = organization.profile_questions
    education_questions = profile_questions.where(question_type: [ProfileQuestion::Type::EDUCATION, ProfileQuestion::Type::MULTI_EDUCATION])
    experience_questions = profile_questions.where(question_type: [ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE])
    publication_questions = profile_questions.where(question_type: [ProfileQuestion::Type::PUBLICATION, ProfileQuestion::Type::MULTI_PUBLICATION])
    manager_questions = profile_questions.where(question_type: ProfileQuestion::Type::MANAGER)

    assert_equal_unordered (education_questions + experience_questions + publication_questions + manager_questions), profile_questions.multi_field_questions
  end

  def test_program_cannot_create_loc_question
    organization = programs(:org_primary)
    loc_ques = organization.profile_questions.select{|ques| ques.location?}
    assert_equal 1, loc_ques.count
    assert organization.valid?
    e = assert_raise(ActiveRecord::RecordInvalid) do
      ProfileQuestion.create!(
        :organization => programs(:org_primary),
        :question_type => ProfileQuestion::Type::LOCATION,
        :section => organization.sections.first,
        :question_text => "Whats your location?")
    end
    assert_equal "Validation failed: can't have more than one location question per role", e.message
  end

  def test_program_can_update_loc_question
    organization = programs(:org_primary)
    loc_ques = organization.profile_questions.select{|ques| ques.location?}
    assert_equal 1, loc_ques.count
    assert organization.valid?
    loc_ques.first.update_attributes(:question_text => "Whats your location?")
    assert_equal loc_ques.first.question_text, "Whats your location?"
  end

  def test_program_can_create_loc_question
    organization = programs(:org_primary)
    loc_ques = organization.profile_questions.select{|ques| ques.location?}
    assert_equal 1, loc_ques.count
    loc_ques.first.destroy

    assert_difference 'ProfileQuestion.count' do
      ProfileQuestion.create!(
        :organization => programs(:org_primary),
        :question_type => ProfileQuestion::Type::LOCATION,
        :section => organization.sections.first,
        :question_text => "Whats your location?")
    end
  end

  def test_program_cannot_create_member_question
    organization = programs(:org_primary)
    manager_q = organization.profile_questions.select{|ques| ques.manager?}
    assert_equal 1, manager_q.count
    assert organization.valid?
    e = assert_raise(ActiveRecord::RecordInvalid) do
      ProfileQuestion.create!(
        :organization => programs(:org_primary),
        :question_type => ProfileQuestion::Type::MANAGER,
        :section => organization.sections.first,
        :question_text => "Manager")
    end
    assert_equal "Validation failed: can't have more than one manager question per role", e.message
  end

  def test_program_can_update_manager_question
    organization = programs(:org_primary)
    manager_q = organization.profile_questions.select{|ques| ques.manager?}
    assert_equal 1, manager_q.count
    assert organization.valid?
    manager_q.first.update_attributes(:question_text => "Manag")
    assert_equal "Manag", manager_q.first.question_text
  end

  def test_program_can_create_manager_question
    organization = programs(:org_primary)
    manager_q = organization.profile_questions.select{|ques| ques.manager?}
    assert_equal 1, manager_q.count
    manager_q.first.destroy

    assert_difference 'ProfileQuestion.count' do
      ProfileQuestion.create!(
        :organization => programs(:org_primary),
        :question_type => ProfileQuestion::Type::MANAGER,
        :section => organization.sections.first,
        :question_text => "Manager")
    end
  end

  def test_manager_profile_question_cannot_exist_when_feature_is_disabled
    organization = programs(:org_primary)
    manager_feature = Feature.find_by(name: FeatureName::MANAGER)
    org_feature = OrganizationFeature.where(organization_id: organization.id, feature_id: manager_feature.id).first
    org_feature.update_attribute(:enabled, false) if org_feature.present?

    assert_false profile_questions(:manager_q).valid?
    assert_equal ["can't have manager question when manager feature is disabled"], profile_questions(:manager_q).errors[:base]
    org_feature.update_attribute(:enabled, true) if org_feature.present?
  end

  def test_required_for
    email_question = programs(:org_primary).profile_questions_with_email_and_name.email_question.first
    assert email_question.required_for(programs(:albers), RoleConstants::MENTOR_NAME)
    assert email_question.required_for(programs(:albers), RoleConstants::STUDENT_NAME)

    gender_question = programs(:org_primary).profile_questions_with_email_and_name.find_by(question_text: "Gender")
    assert_equal [false, false], programs(:albers).role_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).select{|q| q.profile_question == gender_question}.collect(&:required)
    assert !gender_question.required_for(programs(:albers), RoleConstants::MENTOR_NAME)
    assert !gender_question.required_for(programs(:albers), RoleConstants::STUDENT_NAME)

    mentor_gender_question = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question == gender_question}[0]
    mentor_gender_question.update_attributes(:required => true)
    assert gender_question.required_for(programs(:albers), RoleConstants::MENTOR_NAME)
    assert !gender_question.required_for(programs(:albers), RoleConstants::STUDENT_NAME)

    mentee_gender_question = programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).select{|q| q.profile_question == gender_question}[0]
    mentee_gender_question.update_attributes(:required => true)
    assert gender_question.required_for(programs(:albers), RoleConstants::MENTOR_NAME)
    assert gender_question.required_for(programs(:albers), RoleConstants::STUDENT_NAME)
  end

  def test_private_for
    email_question = programs(:org_primary).profile_questions_with_email_and_name.email_question.first
    assert email_question.private_for(programs(:albers), RoleConstants::MENTOR_NAME)
    assert email_question.private_for(programs(:albers), [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert email_question.private_for(programs(:albers), 'mentor_student')

    gender_question = programs(:org_primary).profile_questions_with_email_and_name.find_by(question_text: "Gender")
    assert_equal [false, false], programs(:albers).role_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).select{|q| q.profile_question == gender_question}.collect(&:private?)
    assert !gender_question.private_for(programs(:albers), RoleConstants::MENTOR_NAME)
    assert !gender_question.private_for(programs(:albers), RoleConstants::STUDENT_NAME)
    assert !gender_question.private_for(programs(:albers), [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert !gender_question.private_for(programs(:albers), 'mentor_student')

    mentor_gender_question = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question == gender_question}[0]
    mentor_gender_question.update_attributes(:private => RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
    assert gender_question.private_for(programs(:albers), RoleConstants::MENTOR_NAME)
    assert !gender_question.private_for(programs(:albers), RoleConstants::STUDENT_NAME)
    assert gender_question.private_for(programs(:albers), [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert gender_question.private_for(programs(:albers), 'mentor_student')

    mentee_gender_question = programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).select{|q| q.profile_question == gender_question}[0]
    mentee_gender_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    mentee_gender_question.update_attributes!(:private => RoleQuestion::PRIVACY_SETTING::RESTRICTED)
    assert gender_question.private_for(programs(:albers), RoleConstants::MENTOR_NAME)
    assert gender_question.private_for(programs(:albers), RoleConstants::STUDENT_NAME)
    assert gender_question.private_for(programs(:albers), [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert gender_question.private_for(programs(:albers), 'mentor_student')
  end

  def test_other_option
    assert_difference 'ProfileQuestion.count' do
      create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_choices => "alpha, beta, gamma")
    end
    q = ProfileQuestion.last
    assert_equal "Pick one", q.question_text
    assert_equal false, q.allow_other_option?
    q.update_attributes(:allow_other_option => true )
    assert q.allow_other_option?
  end

  def test_select_type
    q = create_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?")
    assert !q.select_type?

    q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_choices => "alpha, beta, gamma")
    assert q.select_type?

    q = create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, :question_text => "Select Preference", :question_choices => "alpha, beta, gamma", :options_count => 2)
    assert q.select_type?
  end

  def test_ordered_options_type
    assert_difference 'ProfileQuestion.count' do
      create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, :question_text => "Select Preference", :question_choices => "alpha, beta, gamma", :options_count => 2)
    end
    q = ProfileQuestion.last
    assert_equal "Select Preference", q.question_text
    assert q.ordered_options_type?
    assert_equal 2, q.options_count
  end

  def test_text_type
    q = create_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?")
    assert q.text_type?

    q = create_question(:question_type => ProfileQuestion::Type::MULTI_STRING, :question_text => "Pick one", :question_choices => "alpha,beta,gamma")
    assert q.text_type?

    q = create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, :question_text => "Select Preference", :question_choices => "alpha,beta,gamma", :options_count => 2)
    assert_false q.text_type?
  end

  def test_date_type
    q = create_question(question_type: ProfileQuestion::Type::DATE, question_text: "Date of Birth")  
    assert q.date?

    q = create_question(question_type: ProfileQuestion::Type::STRING, question_text: "Name")
    assert_false q.date?
  end

  def test_question_choices_is_internationalized
    question = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_text => "Select Many", :question_choices => "alpha,beta,gamma", :options_count => 2)
    run_in_another_locale(:'fr-CA') do
      assert_equal ["alpha", "beta", "gamma"], question.question_choices.collect(&:text)
      question.question_choices.each do |choice|
        choice.update_attributes!(text: "f" + choice.text)
      end
      assert ["falpha", "fbeta", "fgamma"], question.question_choices.collect(&:text)
    end
    assert ["alpha", "beta", "gamma"], question.question_choices.collect(&:text)
  end

  def test_default_choice_should_return_expected_locale_choices
    question = profile_questions(:student_multi_choice_q)
    assert_equal ["Stand", "Walk", "Run"], question.default_choices
    run_in_another_locale(:'fr-CA') do
      assert_equal ["Supporter", "Marcher", "Course"], question.default_choices
    end
  end

  def test_default_choice_should_return_expected_locale_choices_without_fallback
    question = profile_questions(:student_multi_choice_q)
    assert_equal ["Stand", "Walk", "Run"], question.default_choices
    run_in_another_locale(:'fr-CA') do
      assert_equal ["Supporter", "Marcher", "Course"], question.default_choices
      question.question_choices.each do |qc|
        qc.update_attributes(text: nil)
      end
      assert_equal ["Stand", "Walk", "Run"], question.default_choices
    end
  end

  def test_values_and_choices
    question = profile_questions(:student_multi_choice_q)
    expected_hash = {
      question_choices(:student_multi_choice_q_1).id => "Supporter",
      question_choices(:student_multi_choice_q_2).id => "Marcher",
      question_choices(:student_multi_choice_q_3).id => "Course"
    }
    run_in_another_locale(:'fr-CA') do
      assert_equal expected_hash, question.values_and_choices
    end
  end

  def test_eligible_for_set_matching
    q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_choices => "alpha, beta, gamma")
    assert q.eligible_for_set_matching?

    q = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_text => "Select Many", :question_choices => "alpha, beta, gamma", :options_count => 2)
    assert q.eligible_for_set_matching?

    q = create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, :question_text => "Select Preference", :question_choices => "alpha, beta, gamma", :options_count => 2)
    assert q.eligible_for_set_matching?

    q = create_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?", :text_only_option => true)
    assert_false q.eligible_for_set_matching?

    q = create_question(:question_type => ProfileQuestion::Type::MULTI_STRING, :question_text => "Pick one", :text_only_option => false)
    assert_false q.eligible_for_set_matching?

    q = create_question(:question_type => ProfileQuestion::Type::RATING_SCALE, :question_text => "Select Preference", :question_choices => "alpha, beta, gamma", :options_count => 2)
    assert_false q.eligible_for_set_matching?
  end

  def test_text_only_allowed
    q = create_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?", :text_only_option => true)
    assert q.text_only_allowed?

    q = create_question(:question_type => ProfileQuestion::Type::MULTI_STRING, :question_text => "Pick one", :text_only_option => false)
    assert_false q.text_only_allowed?
  end

  def test_choice_or_select_type
    q = create_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?")
    assert !q.choice_or_select_type?

    q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_choices => "alpha, beta, gamma")
    assert q.choice_or_select_type?

    q = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_text => "Select Many", :question_choices => "alpha, beta, gamma", :options_count => 2)
    assert q.choice_or_select_type?

    q = create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, :question_text => "Select Preference", :question_choices => "alpha, beta, gamma", :options_count => 2)
    assert q.choice_or_select_type?

    q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_choices => "alpha, beta, gamma")
    assert q.choice_or_select_type?

    q = create_question(:question_type => ProfileQuestion::Type::RATING_SCALE, :question_text => "Select Preference", :question_choices => "alpha, beta, gamma", :options_count => 2)
    assert q.choice_or_select_type?

  end

  def test_validations_of_ordered_options_question
    e = assert_raise(ActiveRecord::RecordInvalid) do
      ProfileQuestion.create!(
        :organization => programs(:org_primary),
        :question_type => ProfileQuestion::Type::ORDERED_OPTIONS,
        :section => programs(:org_primary).sections.first,
        :question_text => "Whats your location?"
      )
    end
    assert_equal "Validation failed: Number of options to ask for is not a number", e.message
  end

  def test_has_dependent_questions
    question = profile_questions(:string_q)
    conditional_question = profile_questions(:multi_choice_q)
    assert_false conditional_question.has_dependent_questions?

    #Set Conditional Question
    question.update_attributes!(:conditional_question_id => conditional_question.id)

    assert conditional_question.reload.has_dependent_questions?
  end

  def test_user_search_activity_association
    profile_question = profile_questions(:string_q)
    user_search_activities = [user_search_activities(:user_search_activity_1)]
    assert_equal user_search_activities, profile_question.user_search_activities
    assert_no_difference "UserSearchActivity.count" do
      assert_difference "ProfileQuestion.count", -1 do
        profile_question.destroy
      end
    end
    assert_nil user_search_activities(:user_search_activity_1).reload.profile_question
  end

  def test_update_question_choices
    assert profile_questions(:profile_questions_1).update_question_choices!({existing_question_choices_attributes: ""})
    question = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Choice Field1",
      :role_names => [:mentor], :program => programs(:albers), :filterable => false, allow_other_option: true)
    question.stubs(:has_match_configs?).returns(true)
    # Empty Choices Case

    e = assert_raise ActiveRecord::RecordInvalid do
      question.update_question_choices!({existing_question_choices_attributes: ""})
    end
    assert_equal "Validation failed: Question choices Choices can't be blank for choice based questions", e.message
    assert_equal "Question choices Choices can't be blank for choice based questions", question.errors.full_messages.to_sentence

    question.errors.clear

    Matching.expects(:perform_program_delta_index_and_refresh).never
    # Duplicate Choices Case
    e = assert_raise ActiveRecord::RecordInvalid do
      assert_difference "QuestionChoice.count", 2 do
        question.reload.update_question_choices!({existing_question_choices_attributes: [{"101" => {"text" => "abc"}, "102" => {"text" => "2"}, "103" => {"text" => "abc"}}], question_choices: {new_order: "101,102,103"}})
      end
    end
    assert_equal "Validation failed: choice has already been taken", e.message
    assert_equal "Question choices \"abc\" choice has already been taken", question.errors.full_messages.to_sentence
    question.reload
    assert_equal ["abc", "2"], question.question_choices.collect(&:text)

    question.errors.clear

    Matching.expects(:perform_program_delta_index_and_refresh).times(question.organization.programs.active.size)
    # Correct Choices List Case
    choice_1 = question.question_choices.find_by(text: "abc")
    choice_1.update_attributes(is_other: true)
    assert_difference "QuestionChoice.count", 2 do # Change by only 2 even though we send 3 new entries since 1 created earilier will be destroyed since we are not passing it in the existing_question_choices_attributes
      question.reload.update_question_choices!({existing_question_choices_attributes: [{"1010" => {"text" => "11"}, "1020" => {"text" => "12"}, "1030" => {"text" => "13"}, "101" => {"text" => "Abc"}}], question_choices: {new_order: "101,1020,1010,1030"}})
    end

    question.reload
    assert_equal ["Abc", "12", "11", "13"], question.question_choices.collect(&:text) # Order as given while creation, "2" is missing since it was not passed as part of params
    choice_1 = question.question_choices.find_by(text: "Abc")
    assert_false choice_1.is_other # is_other gets updated to false if the choice is passed as question choice attribute

    answer_choice = AnswerChoice.create!(question_choice_id: choice_1.id, ref_obj: profile_answers(:one))
    qc_1 = question.question_choices.find_by(text: "11")
    qc_2 = question.question_choices.find_by(text: "12")
    qc_3 = question.question_choices.find_by(text: "13")
    question.reload.update_question_choices!({existing_question_choices_attributes: [{qc_1.id.to_s => {"text" => "11"}, qc_2.id.to_s => {"text" => "12"}, qc_3.id.to_s => {"text" => "13"}}], question_choices: {new_order: "#{qc_2.id},#{qc_1.id},#{qc_3.id}"}})
    question.reload
    assert_equal ["12", "11", "13", "Abc"], question.question_choices.collect(&:text)
    choice_1 = question.question_choices.find_by(text: "Abc")
    assert choice_1.is_other # is_other gets updated to true if the choice is passed as question choice attribute

    answer_choice.destroy
    Matching.expects(:perform_program_delta_index_and_refresh).times(question.organization.programs.active.size)
    question.reload.update_question_choices!({existing_question_choices_attributes: [{qc_1.id.to_s => {"text" => "11"}, qc_2.id.to_s => {"text" => "12"}, qc_3.id.to_s => {"text" => "13"}}], question_choices: {new_order: "#{qc_2.id},#{qc_1.id},#{qc_3.id}"}}) # "Abc" is deleted because there are no answer choices left for that question choice
    question.reload
    assert_equal ["12", "11", "13"], question.question_choices.collect(&:text)


    AnswerChoice.create!(question_choice_id: question.question_choices.find_by(text: "13").id, ref_obj: profile_answers(:one))
    question.update_attribute(:allow_other_option, false)
    question.reload.update_question_choices!({existing_question_choices_attributes: [{qc_1.id.to_s => {"text" => "11"}, qc_2.id.to_s => {"text" => "12"}}], question_choices: {new_order: "#{qc_2.id},#{qc_1.id}"}}) # "13" is deleted even though it has answer choices because the allow_other_option has been set to false
    question.reload
    assert_equal ["12", "11"], question.question_choices.collect(&:text)
  end

  def test_is_question_single_or_multi_choice
    assert_false profile_questions(:string_q).is_question_single_or_multi_choice?
    assert profile_questions(:multi_choice_q).is_question_single_or_multi_choice?
    assert profile_questions(:single_choice_q).is_question_single_or_multi_choice?
  end

  def test_has_one_conditional_quesation
    question = profile_questions(:string_q)
    conditional_question = profile_questions(:multi_choice_q)

    assert_nil question.conditional_question
    question.update_attributes!(:conditional_question_id => conditional_question.id)
    assert_equal conditional_question, question.reload.conditional_question
  end

  def test_has_many_dependent_questions
    question = profile_questions(:multi_choice_q)
    dependent_question = profile_questions(:string_q)
    assert_false question.has_dependent_questions?
    assert_blank question.dependent_questions

    dependent_question.update_attributes!(:conditional_question_id => question.id)
    question = question.reload
    assert question.has_dependent_questions?
    assert_equal [dependent_question], question.dependent_questions
  end

  def test_has_many_group_view_columns
    question = profile_questions(:multi_choice_q)
    group_view = programs(:albers).group_view
    mentor_role_id = programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME)
    assert_blank question.group_view_columns

    group_view_column = GroupViewColumn.create!(:group_view => group_view, :profile_question => question, :position => 3, :role_id => mentor_role_id, :ref_obj_type => GroupViewColumn::ColumnType::USER)

    question = question.reload
    assert_equal [group_view_column], question.group_view_columns
  end

  def test_preference_based_mentor_lists
    pq = profile_questions(:profile_questions_25)
    assert_difference 'PreferenceBasedMentorList.count' do
      pq.preference_based_mentor_lists.create!(ref_obj: Location.first, user: User.first, weight: 0.55)
    end

    assert_equal 0.55, pq.preference_based_mentor_lists.last.weight

    assert_difference 'PreferenceBasedMentorList.count', -1 do
      pq.destroy
    end
  end

  def test_conditional_text_matches
    question = profile_questions(:string_q)
    member = members(:f_mentor)
    conditional_question = profile_questions(:multi_choice_q)
    answer_text = member.profile_answers.find_by(profile_question_id: conditional_question.id).answer_value
    assert_equal ["Stand", "Run"], answer_text
    assert_nil question.conditional_question
    all_answers = member.profile_answers.group_by(&:profile_question_id)

    #should return true if no conmditional question is set
    assert question.conditional_text_matches?(all_answers)

    #Set Conditional Question
    question.conditional_question_id = conditional_question.id
    question.save!

    question.conditional_match_choices.create!(question_choice_id: question_choices(:multi_choice_q_2).id)
    question = question.reload
    assert_false question.conditional_text_matches?(all_answers)

    #test for multiple inputs(answer should contain "walk" or "stand")
    question.conditional_match_choices.create!(question_choice_id: question_choices(:multi_choice_q_1).id)
    question = question.reload
    assert question.conditional_text_matches?(all_answers)
  end

  def test_conditional_question_applicable
    parent_question, question, member, profile_answer = create_data_for_conditional_question_testing
    profile_answer.answer_value = "Walk"
    profile_answer.save
    assert_false question.conditional_question_applicable?(member)
    profile_answer.answer_value = "Run"
    profile_answer.save
    assert question.conditional_question_applicable?(member)
  end

  def test_get_dependent_questions_tree_answers
    member = members(:f_mentor)
    q1, q2, q3, q4, q5, q6, q7 = create_temporary_questions_dependency_tree
    assert_equal_hash(member.profile_answers.where(profile_question_id: [q1, q2, q3, q4, q5, q6, q7].map(&:id)).group_by(&:profile_question_id), q1.get_dependent_questions_tree_answers(member))
  end

  def test_handled_after_check_for_conditional_question_applicability
    assert_nil profile_questions(:education_q).conditional_question_id
    member = members(:f_mentor)
    assert_false profile_questions(:education_q).handled_after_check_for_conditional_question_applicability?(member)
    parent_question, question, member, profile_answer = create_data_for_conditional_question_testing
    profile_answer.answer_value = "Walk"
    profile_answer.save
    question.expects(:remove_dependent_tree_answers).once
    assert question.handled_after_check_for_conditional_question_applicability?(member)
    profile_answer.answer_value = "Run"
    profile_answer.save
    assert_false question.handled_after_check_for_conditional_question_applicability?(member)
  end

  def test_update_dependent_questions
    parent_question, question, member, profile_answer = create_data_for_conditional_question_testing
    profile_answer.answer_value = "Run"
    profile_answer.save
    child_profile_answer = member.profile_answers.where(profile_question_id: question.id).first
    parent_question.update_dependent_questions(member)
    assert ProfileAnswer.where(id: child_profile_answer.id).exists?
    profile_answer.answer_value = "Walk"
    profile_answer.save
    parent_question.update_dependent_questions(member)
    assert_false ProfileAnswer.where(id: child_profile_answer.id).exists?
  end

  def test_dependent_questions_subtree
    q1, q2, q3, q4, q5, q6, q7 = create_temporary_questions_dependency_tree

    assert_equal_unordered [q7].collect(&:id), q3.dependent_questions_subtree
    assert_equal_unordered [q4, q5, q6].collect(&:id), q2.dependent_questions_subtree
    assert_equal_unordered [q2, q3, q4, q5, q6, q7].collect(&:id), q1.dependent_questions_subtree

    assert_equal_unordered [], q6.dependent_questions_subtree
    assert_equal_unordered [], q5.dependent_questions_subtree
    assert_equal_unordered [], q7.dependent_questions_subtree
  end

  def test_dependent_questions_tree
    q1, q2, q3, q4, q5, q6, q7 = create_temporary_questions_dependency_tree

    assert_equal_unordered [q3, q7].collect(&:id), q3.dependent_questions_tree
    assert_equal_unordered [q2, q4, q5, q6].collect(&:id), q2.dependent_questions_tree
    assert_equal_unordered [q1, q2, q3, q4, q5, q6, q7].collect(&:id), q1.dependent_questions_tree

    assert_equal_unordered [q6].collect(&:id), q6.dependent_questions_tree
    assert_equal_unordered [q5].collect(&:id), q5.dependent_questions_tree
    assert_equal_unordered [q7].collect(&:id), q7.dependent_questions_tree
  end

  def test_remove_dependent_tree_answers
    user = users(:f_mentor)
    q1 = profile_questions(:profile_questions_10)
    q2 = create_question(question_choices: "Accounting, Wealthy" ,conditional_question_id: q1.id, conditional_match_text: "Internet")
    q3 = create_question(conditional_question_id: q2.id, conditional_match_text: "accounting")
    ProfileAnswer.create!(:answer_value => {answer_text: 'Internet', question: q1}, :profile_question => q1, :ref_obj => members(:f_mentor))
    ProfileAnswer.create!(:answer_value => {answer_text: 'hello', question: q2}, :profile_question => q2, :ref_obj => members(:f_mentor))
    ProfileAnswer.create!(:answer_value => {answer_text: 'yes', question: q3}, :profile_question => q3, :ref_obj => members(:f_mentor))
    all_answers = user.reload.profile_answers.group_by(&:profile_question_id)

    assert_difference 'ProfileAnswer.count', -3 do
      q1.remove_dependent_tree_answers(all_answers)
    end
  end

  def test_conditional_answer_matches_any_of_conditional_choices
    question = profile_questions(:string_q)
    answer = profile_answers(:multi_choice_ans_1)
    assert_equal ["Stand", "Run"], answer.answer_value

    #return true for no match text
    assert question.conditional_question.blank?
    assert question.conditional_answer_matches_any_of_conditional_choices?(answer)
    assert question.conditional_answer_matches_any_of_conditional_choices?("Stand,Run")

    #return false for unmatching match text
    question.conditional_question = profile_questions(:multi_choice_q)
    question.save!

    question.conditional_match_choices.create!(question_choice_id: question_choices(:multi_choice_q_2).id)
    assert_false question.reload.conditional_answer_matches_any_of_conditional_choices?(answer)
    assert_false question.reload.conditional_answer_matches_any_of_conditional_choices?("Stand,Run")

    #return true for matching match text
    question.conditional_match_choices.create!(question_choice_id: question_choices(:multi_choice_q_1).id)
    assert question.reload.conditional_answer_matches_any_of_conditional_choices?(answer)
    assert question.reload.conditional_answer_matches_any_of_conditional_choices?("Stand,Run")
  end

  def test_sort_listing_page_filters
    #Same Section sorted ques
    questions = [profile_questions(:single_choice_q), profile_questions(:multi_choice_q)]
    sorted_ques = ProfileQuestion.sort_listing_page_filters(questions)
    assert_equal questions, sorted_ques

    #Same Section unsorted ques
    questions = [profile_questions(:multi_choice_q), profile_questions(:single_choice_q)]
    sorted_ques = ProfileQuestion.sort_listing_page_filters(questions)
    assert_equal [profile_questions(:single_choice_q), profile_questions(:multi_choice_q)], sorted_ques

    #diff Section sorted ques
    questions = [profile_questions(:education_q), profile_questions(:single_choice_q), profile_questions(:multi_choice_q), profile_questions(:student_multi_choice_q)]
    sorted_ques = ProfileQuestion.sort_listing_page_filters(questions)
    assert_equal [profile_questions(:education_q), profile_questions(:single_choice_q), profile_questions(:multi_choice_q), profile_questions(:student_multi_choice_q)], sorted_ques

    #diff Section unsorted ques
    questions = [profile_questions(:multi_choice_q), profile_questions(:education_q), profile_questions(:student_multi_choice_q), profile_questions(:single_choice_q)]
    sorted_ques = ProfileQuestion.sort_listing_page_filters(questions)
    assert_equal [profile_questions(:education_q), profile_questions(:single_choice_q), profile_questions(:multi_choice_q), profile_questions(:student_multi_choice_q)], sorted_ques

    questions = []
    sorted_ques = ProfileQuestion.sort_listing_page_filters(questions)
    assert_equal questions, sorted_ques

    section = profile_questions(:single_choice_q).section
    last_question = section.profile_questions.last
    last_but_one = section.profile_questions[-2]
    last_question.update_attribute(:position, last_but_one.position)
    assert_equal last_but_one.position, last_question.position
    filter_positions = ProfileQuestion.sort_listing_page_filters(section.profile_questions).collect(&:id)
    section_positions = section.profile_questions.collect(&:id)
    assert_equal filter_positions, section_positions
  end

  def test_skype_text
    assert_equal "Including Skype id in your profile would allow your connected members to call you from the mentoring area. If you face trouble receiving Skype calls, please check your privacy settings.", ProfileQuestion.skype_text
  end

  def test_role_questions_with_match_configs_and_has_match_configs
    program = programs(:albers)
    program2 = programs(:nwen)
    prof_q = create_profile_question(:organization => programs(:org_primary))
    mentor_question = create_role_question(:program => program, :role_names => [RoleConstants::MENTOR_NAME], :profile_question => prof_q)
    student_question = create_role_question(:program => program, :role_names => [RoleConstants::STUDENT_NAME], :profile_question => prof_q)
    create_role_question(:program => program2, :role_names => [RoleConstants::MENTOR_NAME], :profile_question => prof_q)
    create_role_question(:program => program2, :role_names => [RoleConstants::STUDENT_NAME], :profile_question => prof_q)

    assert_false prof_q.has_match_configs?
    assert_empty prof_q.role_questions_with_match_configs(program.id)
    MatchConfig.create!(:program => program, :mentor_question => mentor_question, :student_question => student_question)
    assert_equal [mentor_question.id, student_question.id].sort, prof_q.role_questions_with_match_configs(program.id).map{|role_question| role_question['id']}.sort
    assert_empty prof_q.role_questions_with_match_configs(program2.id)
    assert prof_q.has_match_configs?
    assert prof_q.has_match_configs?(program)
    assert_false prof_q.has_match_configs?(program2)
  end

  def test_profile_question_has_match_configs_should_call_matching_reindex_on_update_of_profile_question
    program = programs(:albers)
    organization = program.organization
    prof_q = create_profile_question(organization: organization)
    prof_q2 = create_profile_question(organization: organization)
    mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)

    assert_false prof_q.has_match_configs?
    assert_empty prof_q.role_questions_with_match_configs(program.id)
    MatchConfig.create!(program: program, mentor_question: mentor_question, student_question: student_question)
    assert_equal [mentor_question.id, student_question.id].sort, prof_q.role_questions_with_match_configs(program.id).map { |role_question| role_question['id'] }.sort
    assert prof_q.has_match_configs?
    assert prof_q.has_match_configs?(program)

    Matching.expects(:perform_program_delta_index_and_refresh).with(program.id).once
    prof_q.update_attributes!(question_type: ProfileQuestion::Type::TEXT)
    prof_q2.update_attributes!(question_type: ProfileQuestion::Type::TEXT)
  end

  def test_format_profile_answer
    education_question = profile_questions(:education_q)
    education_answer = education_question.profile_answers.first
    assert_equal [["American boys school", "Science", "Mechanical", 2003]], education_question.format_profile_answer(education_answer)

    experience_question = profile_questions(:experience_q)
    experience_answer = experience_question.profile_answers.first
    assert_equal [["Lead Developer", 1990, 1995, "Microsoft"]], experience_question.format_profile_answer(experience_answer)

    publication_question = profile_questions(:publication_q)
    publication_answer = publication_question.profile_answers.first
    assert_equal [["Forth publication", "Publisher", "October 03, 2010", "http://publication.url", "Good unique name", "Very useful publication"]], publication_question.format_profile_answer(publication_answer)

    manager_question = profile_questions(:manager_q)
    manager_answer = manager_question.profile_answers.first
    assert_equal ["Manager1", "Name1", "manager1@example.com"], manager_question.format_profile_answer(manager_answer)

    other_question = profile_questions(:private_q)
    other_answer = other_question.profile_answers.first
    assert_equal "Ooty", other_question.format_profile_answer(other_answer)

    date_question = profile_questions(:date_question)
    date_answer = date_question.profile_answers.first
    assert_equal "June 23, 2017", date_question.format_profile_answer(date_answer)
    run_in_another_locale(:"fr-CA") do
      assert_equal "23 Juin 2017", date_question.format_profile_answer(date_answer)
    end
    date_answer.answer_text = "Hello"
    assert_equal "", date_question.format_profile_answer(date_answer)
  end

  def test_format_profile_answer_for_location_based_question
    answer = ProfileAnswer.where("location_id is not null").first
    question = answer.profile_question
    assert_equal answer.answer_text, question.format_profile_answer(answer)
    assert_equal answer.location.city, question.format_profile_answer(answer, scope: AdminViewColumn::ScopedProfileQuestion::Location::CITY)
    assert_equal answer.location.state, question.format_profile_answer(answer, scope: AdminViewColumn::ScopedProfileQuestion::Location::STATE)
    assert_equal answer.location.country, question.format_profile_answer(answer, scope: AdminViewColumn::ScopedProfileQuestion::Location::COUNTRY)
    answer = nil
    assert_equal "", question.format_profile_answer(answer)
    assert_equal "", question.format_profile_answer(answer, scope: AdminViewColumn::ScopedProfileQuestion::Location::CITY)
    assert_equal "", question.format_profile_answer(answer, scope: AdminViewColumn::ScopedProfileQuestion::Location::STATE)
    assert_equal "", question.format_profile_answer(answer, scope: AdminViewColumn::ScopedProfileQuestion::Location::COUNTRY)
  end

  def test_format_profile_answer_for_choice_based_questions
    question = profile_questions(:student_multi_choice_q)
    a = ProfileAnswer.new(:profile_question => question, :ref_obj => members(:f_student))
    a.answer_value = ["Stand", "Walk"]
    a.save!

    assert_equal "Stand, Walk", question.format_profile_answer(a)
    run_in_another_locale(:'fr-CA') do
      assert_equal "Supporter, Marcher", question.format_profile_answer(a)
    end
  end

  def test_format_profile_answer_for_xls
    education_question = profile_questions(:education_q)
    education_question.stubs(:format_profile_answer).returns('something')
    education_answer = education_question.profile_answers.first

    assert_equal 'something', education_question.format_profile_answer_for_xls(nil)
    assert_equal education_answer.answer_text, education_question.format_profile_answer_for_xls(education_answer)

    education_question.stubs(:education?).returns(false)
    education_question.stubs(:experience?).returns(true)
    education_answer.experiences.destroy_all
    education_answer.reload
    assert_equal education_answer.answer_text, education_question.format_profile_answer_for_xls(education_answer)

    education_question.stubs(:experience?).returns(false)
    education_question.stubs(:publication?).returns(true)
    assert_equal education_answer.answer_text, education_question.format_profile_answer_for_xls(education_answer)

    education_question.stubs(:publication?).returns(false)
    education_question.stubs(:manager?).returns(true)
    assert_equal education_answer.answer_text, education_question.format_profile_answer_for_xls(education_answer)

    education_question.stubs(:manager?).returns(false)
    assert_equal 'something', education_question.format_profile_answer_for_xls(education_answer)
  end

  def test_profile_question_translation_fields
    assert ProfileQuestion::Translation.column_names.include?("question_text")
    assert ProfileQuestion::Translation.column_names.include?("help_text")
  end

  def test_create_question_info_in_different_locale_should_work_just_fine
    run_in_another_locale(:'fr-CA') do
      assert_difference 'ProfileQuestion.count' do
        create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_choices => "falpha,fbeta,fgamma")
      end
      question = ProfileQuestion.last
      assert_equal ["falpha", "fbeta", "fgamma"], question.default_choices

      assert_difference 'ProfileQuestion.count' do
        create_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?")
      end
      q = ProfileQuestion.last
      assert_equal "Whats your age?", q.question_text
    end
  end

  def test_survey_response_column_association
    survey = surveys(:progress_report)
    profile_questions = survey.program.profile_questions_for(survey.survey_answers.collect(&:user).map{|u| u.role_names}.flatten.uniq, {default: true, skype: false, fetch_all: true})
    profile_question = profile_questions.first

    src = survey.survey_response_columns.create!(:survey_id => survey.id, :position => survey.survey_response_columns.collect(&:position).max+1, :profile_question_id => profile_question.id, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)

    profile_question.reload
    assert_equal profile_question.survey_response_columns, [src]

    assert_difference "SurveyResponseColumn.count", -1 do
      profile_question.destroy
    end
  end

  def test_handle_choices_update
    profile_question = profile_questions(:string_q)
    profile_answers = profile_question.profile_answers
    assert profile_answers.present?

    profile_question.question_type = ProfileQuestion::Type::SINGLE_CHOICE
    profile_question.expects(:compact_single_choice_answer_choices).with(profile_answers).once
    profile_question.handle_choices_update

    profile_question.question_type = ProfileQuestion::Type::MULTI_CHOICE
    profile_question.expects(:compact_single_choice_answer_choices).never
    profile_question.expects(:compact_multi_choice_answer_choices).with(profile_answers).once
    profile_question.handle_choices_update

    profile_question.question_type = ProfileQuestion::Type::ORDERED_OPTIONS
    profile_question.options_count = 2300
    profile_question.expects(:compact_multi_choice_answer_choices).with(profile_answers, 2300).once
    profile_question.handle_choices_update

    unsupported_types = (ProfileQuestion::Type.all - [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS])
    profile_question.expects(:compact_multi_choice_answer_choices).never
    unsupported_types.each do |unsupported_type|
      profile_question.question_type = unsupported_type
      profile_question.handle_choices_update
    end
  end

  def test_handle_ordered_options_to_choice_type_conversion
    profile_question = profile_questions(:string_q)
    profile_answers = profile_question.profile_answers
    assert profile_answers.present?

    profile_question.question_type = ProfileQuestion::Type::SINGLE_CHOICE
    profile_question.expects(:compact_answers_for_ordered_options_to_single_choice_conversion).with(profile_answers).once
    profile_question.handle_ordered_options_to_choice_type_conversion

    profile_question.question_type = ProfileQuestion::Type::MULTI_CHOICE
    profile_question.expects(:compact_answers_for_ordered_options_to_single_choice_conversion).never
    profile_question.expects(:compact_answers_for_ordered_options_to_multi_choice_conversion).with(profile_answers).once
    profile_question.handle_ordered_options_to_choice_type_conversion

    unsupported_types = (ProfileQuestion::Type.all - [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE])
    profile_question.expects(:compact_answers_for_ordered_options_to_multi_choice_conversion).never
    unsupported_types.each do |unsupported_type|
      profile_question.question_type = unsupported_type
      profile_question.handle_ordered_options_to_choice_type_conversion
    end
  end

  def test_default_choices
    pq = profile_questions(:multi_choice_q)
    pq.update_attributes!(allow_other_option: true)
    pq.create_other_question_choice!("Other option")
    assert_equal ["Stand", "Walk", "Run"], pq.default_choices
  end

  def test_all_choices
    pq = profile_questions(:multi_choice_q)
    pq.update_attributes!(allow_other_option: true)
    pq.create_other_question_choice!("Other option")
    assert_equal ["Stand", "Walk", "Run", "Other option"], pq.all_choices
  end

  def test_create_other_question_choice
    pq = profile_questions(:multi_choice_q)
    pq.update_attributes!(allow_other_option: true)
    oqc = pq.create_other_question_choice!("Other option")
    assert_equal ["Other option"], pq.question_choices.other_choices.collect(&:text)
    oqc.destroy
    pq.update_attributes!(allow_other_option: false)
    pq.create_other_question_choice!("Other option2")
    assert_equal [], pq.question_choices.other_choices.collect(&:text)
  end

  def test_multi_education
    organization = programs(:org_primary)
    profile_question = organization.profile_questions.where(question_type: ProfileQuestion::Type::MULTI_EDUCATION).first
    assert profile_question.multi_education?

    profile_question.question_type = ProfileQuestion::Type::STRING
    assert_false profile_question.multi_education?
  end

  def test_multi_experience
    organization = programs(:org_primary)
    profile_question = organization.profile_questions.where(question_type: ProfileQuestion::Type::MULTI_EXPERIENCE).first
    assert profile_question.multi_experience?

    profile_question.question_type = ProfileQuestion::Type::STRING
    assert_false profile_question.multi_experience?
  end

  def test_multi_publication
    organization = programs(:org_primary)
    profile_question = organization.profile_questions.where(question_type: ProfileQuestion::Type::MULTI_PUBLICATION).first
    assert profile_question.multi_publication?

    profile_question.question_type = ProfileQuestion::Type::STRING
    assert_false profile_question.multi_publication?
  end

  def test_multi_education_or_experience_or_publication
    organization = programs(:org_primary)
    profile_question = organization.profile_questions.where(question_type: ProfileQuestion::Type::MULTI_EXPERIENCE).first
    assert profile_question.multi_education_or_experience_or_publication?

    profile_question = organization.profile_questions.where(question_type: ProfileQuestion::Type::MULTI_PUBLICATION).first
    assert profile_question.multi_education_or_experience_or_publication?

    profile_question = organization.profile_questions.where(question_type: ProfileQuestion::Type::MULTI_EDUCATION).first
    assert profile_question.multi_education_or_experience_or_publication?

    profile_question.question_type = ProfileQuestion::Type::STRING
    assert_false profile_question.multi_education_or_experience_or_publication?
  end

  def test_education_or_experience_or_publication
    organization = programs(:org_primary)
    profile_question = organization.profile_questions.where(question_type: ProfileQuestion::Type::EXPERIENCE).first
    assert profile_question.education_or_experience_or_publication?

    profile_question = organization.profile_questions.where(question_type: ProfileQuestion::Type::PUBLICATION).first
    assert profile_question.education_or_experience_or_publication?

    profile_question = organization.profile_questions.where(question_type: ProfileQuestion::Type::EDUCATION).first
    assert profile_question.education_or_experience_or_publication?

    profile_question.question_type = ProfileQuestion::Type::STRING
    assert_false profile_question.education_or_experience_or_publication?
  end

  def test_part_of_sftp_feed
    organization = programs(:org_primary)

    # creating config for sftp
    feed_import_config = FeedImportConfiguration.create(organization_id: organization.id, sftp_user_name: "test name", frequency: FeedImportConfiguration::Frequency::WEEKLY)
    feed_import_config.set_config_options!(imported_profile_question_texts: ["Email", "Some Other"])

    profile_question = organization.profile_questions.first
    profile_question.question_text = "Email"
    assert profile_question.part_of_sftp_feed?(organization)

    profile_question.question_text = "Name"
    assert_false profile_question.part_of_sftp_feed?(organization)

    feed_exporter = organization.create_feed_exporter(sftp_account_name: "test")
    mem_config = FeedExporter::MemberConfiguration.new(feed_exporter: feed_exporter)
    mem_config.set_config_options!(profile_question_texts: ["Gender"])
    feed_exporter.reload
    profile_question.question_text = "Gender"
    assert profile_question.part_of_sftp_feed?(organization)

    group_config = FeedExporter::ConnectionConfiguration.new(feed_exporter: feed_exporter)
    group_config.set_config_options!(profile_question_texts: ["Name"])
    feed_exporter.reload
    profile_question.question_text = "Name"
    assert profile_question.part_of_sftp_feed?(organization)

    profile_question.question_text = "Invalid"
    assert_false profile_question.part_of_sftp_feed?(organization)
  end

  def test_conditional_profile_question
    profile_question = profile_questions(:profile_questions_1)
    assert_false profile_question.conditional?

    profile_question.conditional_question_id = profile_questions(:profile_questions_2).id
    assert profile_question.conditional?
  end

  def test_conditional_text_choices
    parent_question = profile_questions(:multi_choice_q)
    question = profile_questions(:string_q)
    question.conditional_question_id = parent_question.id
    question.save!

    assert_equal [], question.reload.conditional_text_choices
    ProfileQuestion.expects(:delayed_es_reindex).with(question.id).once
    question.update_conditional_match_choices!([question_choices(:multi_choice_q_2).id.to_s, question_choices(:multi_choice_q_3).id.to_s])

    assert_equal ["Walk", "Run"], question.reload.conditional_text_choices

    run_in_another_locale(:'fr-CA') do
      assert_equal ["Walk", "Run"], question.reload.conditional_text_choices

      question_choices(:multi_choice_q_2).update_attributes(text: "fWalk")
      assert_equal ["fWalk", "Run"], question.reload.conditional_text_choices
    end
  end

  def test_update_conditional_match_choices
    parent_question = profile_questions(:multi_choice_q)
    question = profile_questions(:string_q)
    question.conditional_question_id = parent_question.id
    question.save!

    ProfileQuestion.expects(:delayed_es_reindex).with(question.id).times(6)

    assert_difference "ConditionalMatchChoice.count", 1 do  # multi_choice_q_3 created
      question.update_conditional_match_choices!([question_choices(:multi_choice_q_3).id.to_s])
    end

    assert_equal ["Run"], question.reload.conditional_text_choices

    assert_difference "ConditionalMatchChoice.count", -1 do  # multi_choice_q_3 deleted
      question.update_conditional_match_choices!([])
    end

    assert_equal [], question.reload.conditional_text_choices

    assert_difference "ConditionalMatchChoice.count", 2 do  # multi_choice_q_3 created, multi_choice_q_2 created
      question.update_conditional_match_choices!([question_choices(:multi_choice_q_2).id.to_s, question_choices(:multi_choice_q_3).id.to_s])
    end

    assert_equal ["Walk", "Run"], question.reload.conditional_text_choices

    assert_difference "ConditionalMatchChoice.count", -1 do  # multi_choice_q_3 deleted, multi_choice_q_2 left alone
      question.update_conditional_match_choices!([question_choices(:multi_choice_q_2).id.to_s])
    end

    assert_equal ["Walk"], question.reload.conditional_text_choices

    assert_difference "ConditionalMatchChoice.count", 1 do # multi_choice_q_2 left alone, and multi_choice_q_3 created
      question.update_conditional_match_choices!([question_choices(:multi_choice_q_2).id.to_s, question_choices(:multi_choice_q_3).id.to_s])
    end

    assert_equal ["Walk", "Run"], question.reload.conditional_text_choices

    assert_no_difference "ConditionalMatchChoice.count" do # multi_choice_q_3 deleted, multi_choice_q_2 left alone, and multi_choice_q_1 created
      question.update_conditional_match_choices!([question_choices(:multi_choice_q_2).id.to_s, question_choices(:multi_choice_q_1).id.to_s])
    end

    assert_equal ["Stand", "Walk"], question.reload.conditional_text_choices
  end

  def test_linkedin_importable
    profile_question = ProfileQuestion.new
    linkedin_importable_types = [
      ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE
    ]

    linkedin_importable_types.each do |question_type|
      profile_question.question_type = question_type
      assert profile_question.linkedin_importable?
    end

    (ProfileQuestion::Type.all - linkedin_importable_types).each do |question_type|
      profile_question.question_type = question_type
      assert_false profile_question.linkedin_importable?
    end
  end

  private

  def create_data_for_conditional_question_testing
    parent_question = profile_questions(:multi_choice_q)
    question = profile_questions(:string_q)
    question.conditional_question_id = parent_question.id
    question.save!

    question.conditional_match_choices.create!(question_choice_id: question_choices(:multi_choice_q_3).id)
    member = members(:f_mentor)
    profile_answer = member.profile_answers.where(profile_question_id: parent_question.id).first
    [parent_question, question, member, profile_answer]
  end

  def create_temporary_questions_dependency_tree
    q1 = profile_questions(:profile_questions_10)
    q2 = profile_questions(:profile_questions_11)
    q3 = profile_questions(:single_choice_q)
    q4 = profile_questions(:multi_choice_q)
    q5 = profile_questions(:string_q)
    q6 = profile_questions(:education_q)
    q7 = profile_questions(:experience_q)

    q2.update_attributes!(:conditional_question_id => q1.id, :conditional_match_text => "internet")
    q3.update_attributes!(:conditional_question_id => q1.id, :conditional_match_text => "accounting")
    q4.update_attributes!(:conditional_question_id => q2.id, :conditional_match_text => "finance")
    q5.update_attributes!(:conditional_question_id => q2.id, :conditional_match_text => "research")
    q6.update_attributes!(:conditional_question_id => q4.id, :conditional_match_text => "walk")
    q7.update_attributes!(:conditional_question_id => q3.id, :conditional_match_text => "opt_1")
    [q1, q2, q3, q4, q5, q6, q7]
  end
end
