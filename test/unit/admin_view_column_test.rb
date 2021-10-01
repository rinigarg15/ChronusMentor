require_relative './../test_helper.rb'

class AdminViewColumnTest < ActiveSupport::TestCase
  def test_validations
    admin_view = programs(:albers).admin_views.first
    admin_view_column = AdminViewColumn.new
    assert_false admin_view_column.valid?
    assert_equal(["can't be blank"], admin_view_column.errors[:admin_view])
    assert_equal(["can't be blank", "is not included in the list"], admin_view_column.errors[:column_key])
    assert_equal(["can't be blank"], admin_view_column.errors[:profile_question_id])

    admin_view_column = AdminViewColumn.new(:admin_view => admin_view, :column_key => "first_name12")
    assert_false admin_view_column.valid?
    assert_equal(["is not included in the list"], admin_view_column.errors[:column_key])

    admin_view_column = AdminViewColumn.new(:admin_view => admin_view, :column_key => "first_name")
    assert_false admin_view_column.valid?   
    assert_equal(["has already been taken"], admin_view_column.errors[:column_key]) 

    admin_view_column = AdminViewColumn.create!(:admin_view => admin_view, :profile_question_id => 1, :position => 9)
    assert admin_view_column.valid?   

    admin_view_column = AdminViewColumn.new(:admin_view => admin_view, :profile_question_id => 1)
    assert_false admin_view_column.valid?   
    assert_equal(["has already been taken"], admin_view_column.errors[:profile_question_id]) 
  end

  def test_is_default
    admin_view_column = AdminViewColumn.first
    assert admin_view_column.is_default?

    admin_view_column.update_attributes!(:column_key => nil, :profile_question_id => 1)
    assert_false admin_view_column.is_default?
  end

  def update_custom_term(program)
    term = program.customized_terms.where(term_type: "Mentoring_Connection").first
    custom_connection_id = term.id
    CustomizedTerm.find_by(id: custom_connection_id).update_attributes(term: "Mentoring Connection", term_downcase: "mentoring connection", pluralized_term: "Mentoring Connections", pluralized_term_downcase: "mentoring connections", articleized_term: "a Mentoring Connection", articleized_term_downcase: "a mentoring connection")
    options = { Mentoring_Connections: term.pluralized_term }
    return options
  end

  def test_get_title
    admin_view_column = AdminViewColumn.first
    assert_equal "Member ID", admin_view_column.get_title
    options = update_custom_term(programs(:albers))
    admin_view_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::GROUPS)
    assert_equal "Ongoing Mentoring Connections", admin_view_column.get_title(Mentoring_Connections: options[:Mentoring_Connections])
    admin_view_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::CLOSED_GROUPS)
    assert_equal "Closed Mentoring Connections", admin_view_column.get_title(Mentoring_Connections: options[:Mentoring_Connections])
    admin_view_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::DRAFTED_GROUPS)
    assert_equal "Drafted Mentoring Connections", admin_view_column.get_title(Mentoring_Connections: options[:Mentoring_Connections])
    admin_view_column.update_attributes!(column_key: nil, profile_question_id: profile_questions(:single_choice_q).id)
    assert_equal "What is your name", admin_view_column.get_title
    assert_equal "What is your name", profile_questions(:single_choice_q).question_text

    admin_view_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES, profile_question_id: 2)
    assert_equal "New Program", admin_view_column.get_title(program_title: "New Program")
  end

  def test_get_title_for_mandtory_question
    admin_view = programs(:albers).admin_views.first
    role_question = programs(:albers).role_questions.where(required: false).first
    role_question.update_attribute(:required, true)
    admin_view_column = AdminViewColumn.new(admin_view_id: admin_view.id, profile_question_id: role_question.profile_question_id)
    assert_equal "#{role_question.profile_question.question_text} *", admin_view_column.get_title
  end

  def test_get_answer
    user = users(:f_mentor)
    first_name_column = AdminViewColumn.find_by(column_key: AdminViewColumn::Columns::Key::FIRST_NAME)
    member_id_column = AdminViewColumn.find_by(column_key: AdminViewColumn::Columns::Key::MEMBER_ID)

    assert_equal "Good unique", first_name_column.get_answer(user)
    assert_equal user.member_id, member_id_column.get_answer(user)

    admin_view_column = first_name_column
    admin_view_column.update_attributes!(column_key: nil, profile_question_id: 2)
    assert_equal "", admin_view_column.get_answer(user)

    admin_view_column.update_attributes!(column_key: nil, profile_question_id: 4)
    assert_equal "", admin_view_column.get_answer(user)

    admin_view_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MENTORING_MODE)
    assert_equal "Ongoing and One-time Mentoring", admin_view_column.get_answer(user)

    user.mentoring_mode = User::MentoringMode::ONGOING
    user.save!
    assert_equal "Ongoing Mentoring", admin_view_column.get_answer(user)

    user.mentoring_mode = User::MentoringMode::ONE_TIME
    user.save!
    assert_equal "One-time Mentoring", admin_view_column.get_answer(user)

    user = users(:f_student)
    user.mentoring_mode = User::MentoringMode::NOT_APPLICABLE
    user.save!
    assert_equal "NA", admin_view_column.get_answer(user)

    # test for rating column
    mentee = users(:f_student)
    mentor = users(:f_mentor)
    program = programs(:albers)
    admin_view_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::RATING)
    # with feature disabled
    assert_equal "NA", admin_view_column.get_answer(mentee)
    assert_equal "NA", admin_view_column.get_answer(mentor)
    # enabling the feature
    program.enable_feature(FeatureName::COACH_RATING, true)
    mentee.program.reload
    mentor.program.reload
    assert_equal "NA", admin_view_column.get_answer(mentee)
    assert_equal "Not rated yet.", admin_view_column.get_answer(mentor)
    user_stat = UserStat.create!(user: mentor, average_rating: 4)
    mentor.reload
    assert_equal 4.0, admin_view_column.get_answer(mentor)
  end

  def test_get_answer_with_hash_received
    first_name_column = AdminViewColumn.find_by(column_key: AdminViewColumn::Columns::Key::FIRST_NAME)
    member_id_column = AdminViewColumn::find_by(column_key: AdminViewColumn::Columns::Key::MEMBER_ID)

    user = users(:f_mentor)
    user_hash = {
      'first_name' => user.first_name,
      'member_id' => user.member_id
    }
    assert_equal "Good unique", first_name_column.get_answer(user_hash)
    assert_equal 3, member_id_column.get_answer(user_hash)

    admin_view_column = first_name_column
    q1 = profile_questions(:string_q)
    profile_answers_hash = {
      user.member_id => {
        q1.id => [profile_answers(:one)]
      }
    }
    admin_view_column.update_attributes!(column_key: nil, profile_question_id: q1.id)
    assert_equal "Computer", admin_view_column.get_answer(user_hash, profile_answers_hash)

    q2 = profile_questions(:profile_questions_4)
    admin_view_column.update_attributes!(column_key: nil, profile_question_id: q2.id)
    assert_equal "", admin_view_column.get_answer(user_hash, profile_answers_hash)
  end

  def test_get_answer_with_correct_options_profile_score
    program = programs(:albers)
    opts = {:default => false, :skype => program.organization.skype_enabled?, :dont_include_section => true}
    mentor_questions = program.profile_questions_for(RoleConstants::MENTOR_NAME, opts)
    student_questions = program.profile_questions_for(RoleConstants::STUDENT_NAME, opts)
    options = {:questions => {RoleConstants::MENTOR_NAME => mentor_questions, RoleConstants::STUDENT_NAME => student_questions}}

    admin_view = program.admin_views.first
    admin_view_column = AdminViewColumn.new(:admin_view => admin_view, :column_key => AdminViewColumn::Columns::Key::PROFILE_SCORE)
    user = users(:f_mentor)
    assert_equal 59, admin_view_column.get_answer(user, {},options)
  end

  def test_get_answer_with_wrong_options_profile_score
    program = programs(:albers)
    opts = {:default => false, :skype => program.organization.skype_enabled?, :dont_include_section => true}
    mentor_questions = program.profile_questions_for(RoleConstants::MENTOR_NAME, opts)
    student_questions = program.profile_questions_for(RoleConstants::STUDENT_NAME, opts)
    options = {:questions => {RoleConstants::MENTOR_NAME => student_questions, RoleConstants::STUDENT_NAME => mentor_questions}}

    admin_view = program.admin_views.first
    admin_view_column = AdminViewColumn.new(:admin_view => admin_view, :column_key => AdminViewColumn::Columns::Key::PROFILE_SCORE)    
    assert_equal 20, admin_view_column.get_answer(users(:f_mentor), {},options)
  end

  def test_get_answer_without_options_profile_score
    program = programs(:albers)
    admin_view = program.admin_views.first
    admin_view_column = AdminViewColumn.new(:admin_view => admin_view, :column_key => AdminViewColumn::Columns::Key::PROFILE_SCORE)
    assert_equal 59, admin_view_column.get_answer(users(:f_mentor))
  end

  def test_get_answer_should_success_for_education
    admin_view_column = AdminViewColumn.first
    user = users(:f_mentor)

    admin_view_column.update_attributes!(:column_key => nil, :profile_question_id => 6)

    assert_equal [], admin_view_column.get_answer(user)

    ed = create_education(user, admin_view_column.profile_question)
    assert_equal [["SSV", "BTech", "IT", 2009]], admin_view_column.get_answer(user)

    ed.update_attribute(:graduation_year, nil)
    assert_equal [["SSV", "BTech", "IT", nil]], admin_view_column.get_answer(user)

    ed.update_attribute(:graduation_year, 2010)
    create_education(user, admin_view_column.profile_question)
    assert_equal [["SSV", "BTech", "IT", 2010], ["SSV", "BTech", "IT", 2009]], admin_view_column.get_answer(user.reload)
  end

  def test_get_answer_for_member_should_success_for_education
    admin_view_column = AdminViewColumn.first
    member = members(:f_mentor)

    admin_view_column.update_attributes!(:column_key => nil, :profile_question_id => 6)

    assert_equal [], admin_view_column.get_answer(member)

    ed = create_education(member, admin_view_column.profile_question)
    assert_equal [["SSV", "BTech", "IT", 2009]], admin_view_column.get_answer(member)

    ed.update_attribute(:graduation_year, nil)
    assert_equal [["SSV", "BTech", "IT", nil]], admin_view_column.get_answer(member)

    ed.update_attribute(:graduation_year, 2010)
    create_education(member, admin_view_column.profile_question)
    assert_equal [["SSV", "BTech", "IT", 2010], ["SSV", "BTech", "IT", 2009]], admin_view_column.get_answer(member)
  end

  def test_get_answer_should_success_for_experience
    admin_view_column = AdminViewColumn.first
    user = users(:f_mentor)

    admin_view_column.update_attributes!(:column_key => nil, :profile_question_id => 7)

    assert_equal [], admin_view_column.get_answer(user)

    ex = create_experience(user, admin_view_column.profile_question)
    assert_equal [["SDE", 2000, 2009, "MSFT"]], admin_view_column.get_answer(user)

    ex.update_attribute(:end_year, nil)
    assert_equal [["SDE", 2000, nil, "MSFT"]], admin_view_column.get_answer(user)

    ex.update_attribute(:end_year, 2010)
    create_experience(user, admin_view_column.profile_question)
    assert_equal [["SDE", 2000, 2010, "MSFT"], ["SDE", 2000, 2009, "MSFT"]], admin_view_column.get_answer(user.reload)
  end

  def test_get_answer_should_success_for_publication
    admin_view_column = AdminViewColumn.first
    user = users(:f_mentor)
    pub_question = create_question(:question_type => ProfileQuestion::Type::PUBLICATION, :question_text => "Publication", :organization => programs(:org_primary))

    admin_view_column.update_attributes!(:column_key => nil, :profile_question_id => pub_question.id)

    assert_equal [], admin_view_column.get_answer(user)

    pub = create_publication(user, admin_view_column.profile_question)
    assert_equal [["Publication", "Publisher ltd.", "January 03, 2009", "http://public.url","Author", "Very useful publication"]], admin_view_column.get_answer(user)

    pub.update_attribute(:year, nil)
    assert_equal [["Publication", "Publisher ltd.", "", "http://public.url", "Author", "Very useful publication"]], admin_view_column.get_answer(user)

    pub.update_attributes(:year => 2010, :day => 11, :month => 11)
    pub.update_attribute(:created_at, '2010-11-11')
    create_publication(user, admin_view_column.profile_question)
    assert_equal [["Publication", "Publisher ltd.", "January 03, 2009", "http://public.url","Author", "Very useful publication"],
                  ["Publication", "Publisher ltd.", "November 11, 2010", "http://public.url","Author", "Very useful publication"], 
                 ], admin_view_column.get_answer(user.reload)
  end

  def test_get_answer_should_success_for_manager
    admin_view_column = AdminViewColumn.first
    user = users(:f_mentor)
    manager_question = programs(:org_primary).profile_questions.manager_questions.first

    admin_view_column.update_attributes!(:column_key => nil, :profile_question_id => manager_question.id)

    assert_equal ["Manager1", "Name1", "manager1@example.com"], admin_view_column.get_answer(user)

    manager = user.member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.try(:manager)
    manager.update_attribute(:last_name, "New last name")
    assert_equal ["Manager1", "New last name", "manager1@example.com"], admin_view_column.get_answer(user.reload)
  end

  def test_get_answer_for_member_should_success_for_experience
    admin_view_column = AdminViewColumn.first
    member = members(:f_mentor)

    admin_view_column.update_attributes!(:column_key => nil, :profile_question_id => 7)

    assert_equal [], admin_view_column.get_answer(member)

    ex = create_experience(member, admin_view_column.profile_question)
    assert_equal [["SDE", 2000, 2009, "MSFT"]], admin_view_column.get_answer(member)

    ex.update_attribute(:end_year, nil)
    assert_equal [["SDE", 2000, nil, "MSFT"]], admin_view_column.get_answer(member)

    ex.update_attribute(:end_year, 2010)
    create_experience(member, admin_view_column.profile_question)
    assert_equal [["SDE", 2000, 2010, "MSFT"], ["SDE", 2000, 2009, "MSFT"]], admin_view_column.get_answer(member)
  end

  def test_get_answer_with_answers_hash
    admin_view_column = AdminViewColumn.first
    answers_hash = {}
    user = users(:f_mentor)
    pq_id = profile_answers(:one).profile_question_id

    admin_view_column.update_attributes!(:column_key => nil, :profile_question_id => pq_id)
    assert_equal "Computer", admin_view_column.get_answer(user)

    answers_hash[user.member.id] = {pq_id => [profile_answers(:one)]}
    assert_equal "Computer", admin_view_column.get_answer(user, answers_hash)
  end

  def test_get_answer_for_member_with_answers_hash
    admin_view_column = AdminViewColumn.first
    answers_hash = {}
    member = members(:f_mentor)
    pq_id = profile_answers(:one).profile_question_id

    admin_view_column.update_attributes!(:column_key => nil, :profile_question_id => pq_id)
    assert_equal "Computer", admin_view_column.get_answer(member)

    answers_hash[member.id] = {pq_id => [profile_answers(:one)]}
    assert_equal "Computer", admin_view_column.get_answer(member, answers_hash)
  end

  def test_program_default_has
    assert_false AdminViewColumn::Columns::ProgramDefaults.has?("sample")
    assert_false AdminViewColumn::Columns::ProgramDefaults.has?("sample123")

    assert AdminViewColumn::Columns::ProgramDefaults.has?(AdminViewColumn::Columns::Key::MEMBER_ID)
    assert AdminViewColumn::Columns::ProgramDefaults.has?(AdminViewColumn::Columns::Key::FIRST_NAME)
    assert AdminViewColumn::Columns::ProgramDefaults.has?(AdminViewColumn::Columns::Key::ROLES)
    assert AdminViewColumn::Columns::ProgramDefaults.has?(AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1)
    assert AdminViewColumn::Columns::ProgramDefaults.has?(AdminViewColumn::Columns::Key::LANGUAGE)
  end

  def test_organization_default_has
    assert_false AdminViewColumn::Columns::OrganizationDefaults.has?("sample")
    assert_false AdminViewColumn::Columns::OrganizationDefaults.has?(AdminViewColumn::Columns::Key::ROLES)
    assert_false AdminViewColumn::Columns::OrganizationDefaults.has?(AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1)

    assert AdminViewColumn::Columns::OrganizationDefaults.has?(AdminViewColumn::Columns::Key::MEMBER_ID)
    assert AdminViewColumn::Columns::OrganizationDefaults.has?(AdminViewColumn::Columns::Key::FIRST_NAME)
    assert AdminViewColumn::Columns::OrganizationDefaults.has?(AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES)
    assert AdminViewColumn::Columns::OrganizationDefaults.has?(AdminViewColumn::Columns::Key::LANGUAGE)
  end

  def test_organization_default_columns
    assert AdminViewColumn::Columns::OrganizationDefaults.defaults(include_language: true).keys.include?(AdminViewColumn::Columns::Key::LANGUAGE)
    assert_false AdminViewColumn::Columns::OrganizationDefaults.defaults.keys.include?(AdminViewColumn::Columns::Key::LANGUAGE)
  end

  def test_program_basic_information_columns
    admin_view = programs(:albers).admin_views.first
    # see test case for AdminView#languages_filter_enabled? in admin_view_test.rb
    admin_view.stubs(:languages_filter_enabled?).returns(true)
    assert AdminViewColumn::Columns::ProgramDefaults.basic_information_columns(admin_view).keys.include?(AdminViewColumn::Columns::Key::LANGUAGE)
    assert AdminViewColumn::Columns::ProgramDefaults.has?(AdminViewColumn::Columns::Key::LANGUAGE)
    admin_view.stubs(:languages_filter_enabled?).returns(false)
    assert_false AdminViewColumn::Columns::ProgramDefaults.basic_information_columns(admin_view).keys.include?(AdminViewColumn::Columns::Key::LANGUAGE)
    assert AdminViewColumn::Columns::ProgramDefaults.has?(AdminViewColumn::Columns::Key::LANGUAGE)
  end

  def test_language_get_title
    admin_view = programs(:org_primary).admin_views.first
    language_column = get_tmp_language_column(admin_view)
    assert_false admin_view.is_program_view?
    admin_view.stubs(:languages_filter_enabled?).returns(true)
    admin_view.organization.stubs(:languages_filter_enabled?).returns(true)
    assert_equal "Language used", language_column.get_title
    admin_view.stubs(:languages_filter_enabled?).returns(false)
    admin_view.organization.stubs(:languages_filter_enabled?).returns(false)
    assert_equal "Language used", language_column.get_title
  end

  def test_engagement_get_title
    admin_view = programs(:org_primary).admin_views.first
    admin_view_column = admin_view.admin_view_columns.create!(:admin_view => admin_view, :column_key => "ongoing_engagements")
    assert_false admin_view.is_program_view?
    assert_equal "Ongoing Engagements", admin_view_column.get_title
    admin_view_column1 = admin_view.admin_view_columns.create!(:admin_view => admin_view, :column_key => "closed_engagements")
    assert_equal "Closed Engagements", admin_view_column1.get_title
  end

  def test_default_member_answer_for_language
    admin_view = programs(:org_primary).admin_views.first
    admin_view_column = admin_view.admin_view_columns.first
    assert_equal "Hindi", admin_view_column.send(:default_member_answer, members(:mentor_13), AdminViewColumn::Columns::Key::LANGUAGE)
    assert_equal AdminViewColumn::LANGUAGE_NOT_SET_DISPLAY, admin_view_column.send(:default_member_answer, members(:dormant_member), AdminViewColumn::Columns::Key::LANGUAGE)
    assert_equal "English", admin_view_column.send(:default_member_answer, members(:mentor_10), AdminViewColumn::Columns::Key::LANGUAGE)
  end

  def test_get_net_recommended_count
    admin_view = programs(:org_primary).admin_views.first
    admin_view_column = admin_view.admin_view_columns.create!(admin_view: admin_view, column_key: AdminViewColumn::Columns::Key::NET_RECOMMENDED_COUNT)
    mentor = users(:f_mentor)
    assert_equal "NA", admin_view_column.send(:get_net_recommended_count, false, {net_recommended_count: 10, user: mentor})
    assert_equal 10, admin_view_column.send(:get_net_recommended_count, true, {net_recommended_count: 10, user: mentor})
    assert_equal mentor.net_recommended_count, admin_view_column.send(:get_net_recommended_count, true, {user: mentor})
  end

  def test_default_member_answer_for_engagement
    admin_view = programs(:org_primary).admin_views.first
    admin_view_column = admin_view.admin_view_columns.first
    assert_equal 3, admin_view_column.send(:default_member_answer, members(:f_mentor), AdminViewColumn::Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS, {ongoing_engagements_map: {members(:f_mentor).id => 3}})
    assert_equal "0", admin_view_column.send(:default_member_answer, members(:f_mentor), AdminViewColumn::Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS, {ongoing_engagements_map: {members(:f_student).id => 3}})
    assert_equal "0", admin_view_column.send(:default_member_answer, members(:f_mentor), AdminViewColumn::Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS, {ongoing_engagements_map: {}})

    assert_equal 2, admin_view_column.send(:default_member_answer, members(:f_mentor), AdminViewColumn::Columns::Key::ORG_LEVEL_CLOSED_ENGAGEMENTS, {closed_engagements_map: {members(:f_mentor).id => 2}})
    assert_equal "0", admin_view_column.send(:default_member_answer, members(:f_mentor), AdminViewColumn::Columns::Key::ORG_LEVEL_CLOSED_ENGAGEMENTS, {closed_engagements_map: {members(:f_student).id => 2}})
    assert_equal "0", admin_view_column.send(:default_member_answer, members(:f_mentor), AdminViewColumn::Columns::Key::ORG_LEVEL_CLOSED_ENGAGEMENTS, {closed_engagements_map: {}})
  end

  def test_get_ongoing_engagements_member_count
    admin_view = programs(:org_primary).admin_views.first
    admin_view_column = admin_view.admin_view_columns.first
    assert_equal 3, admin_view_column.send(:get_ongoing_engagements_member_count, members(:f_mentor), {ongoing_engagements_map: {members(:f_mentor).id => 3}})
    assert_equal "0", admin_view_column.send(:get_ongoing_engagements_member_count, members(:f_mentor), {ongoing_engagements_map: {members(:f_student).id => 3}})
    assert_equal "0", admin_view_column.send(:get_ongoing_engagements_member_count, members(:f_mentor), {ongoing_engagements_map: {}})
  end

  def test_get_closed_engagements_member_count
    admin_view = programs(:org_primary).admin_views.first
    admin_view_column = admin_view.admin_view_columns.first
    assert_equal 2, admin_view_column.send(:get_closed_engagements_member_count, members(:f_mentor), {closed_engagements_map: {members(:f_mentor).id => 2}})
    assert_equal "0", admin_view_column.send(:get_closed_engagements_member_count, members(:f_mentor), {closed_engagements_map: {members(:f_student).id => 2}})
    assert_equal "0", admin_view_column.send(:get_closed_engagements_member_count, members(:f_mentor), {closed_engagements_map: {}})
  end

  def test_key
    admin_view = programs(:albers).admin_views.first

    column = admin_view.admin_view_columns.first
    assert_equal AdminViewColumn::Columns::Key::MEMBER_ID, column.key

    column = admin_view.admin_view_columns.second
    assert_equal AdminViewColumn::Columns::Key::FIRST_NAME, column.key

    profile_question = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], { skype: false, default: false } ).first
    column.update_attributes!(column_key: nil, profile_question: profile_question)
    assert_equal profile_question.id, column.key.to_i
  end

  def test_default
    admin_view = programs(:albers).admin_views.first
    assert_equal 10, admin_view.admin_view_columns.default.size

    column = admin_view.admin_view_columns.default.first
    profile_question = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], { skype: false, default: false } ).first
    column.update_attributes!(column_key: nil, profile_question: profile_question)
    assert_equal 9, admin_view.admin_view_columns.default.size
  end

  def test_custom
    admin_view = programs(:albers).admin_views.first
    assert_equal 0, admin_view.admin_view_columns.custom.size

    column = admin_view.admin_view_columns.first
    profile_question = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], {skype: false, default: false}).first
    column.update_attributes!(:column_key => nil, :profile_question => profile_question)

    assert_equal 1, admin_view.admin_view_columns.custom.size
  end

  def test_find_object
    column_array = AdminViewColumn.all[0..3]
    admin_view = programs(:albers).admin_views.first

    assert_nil AdminViewColumn.find_object(column_array, "sample", admin_view)
    assert_nil AdminViewColumn.find_object([], AdminViewColumn::Columns::Key::FIRST_NAME, admin_view)
    assert_nil AdminViewColumn.find_object([], "sample", admin_view)

    column_obj = AdminViewColumn.find_object(column_array, AdminViewColumn::Columns::Key::MEMBER_ID, admin_view)
    assert_equal column_array[0], column_obj

    column_obj = AdminViewColumn.find_object(column_array, AdminViewColumn::Columns::Key::FIRST_NAME, admin_view)
    assert_equal column_array[1], column_obj

    location_profile_question = ProfileQuestion.where(question_type: ProfileQuestion::Type::LOCATION).first
    unscoped_location_admin_view_column = AdminViewColumn.create(admin_view_id: column_obj.admin_view_id, profile_question_id: location_profile_question.id)
    state_location_admin_view_column = AdminViewColumn.create(admin_view_id: column_obj.admin_view_id, profile_question_id: location_profile_question.id, column_sub_key: AdminViewColumn::ScopedProfileQuestion::Location::STATE)
    column_array << unscoped_location_admin_view_column
    column_array << state_location_admin_view_column

    assert_equal unscoped_location_admin_view_column, AdminViewColumn.find_object(column_array, "#{location_profile_question.id}", admin_view)
    assert_equal state_location_admin_view_column, AdminViewColumn.find_object(column_array, "#{location_profile_question.id}-state", admin_view)
  end

  def test_scoped_profile_question_key
    location_profile_question = ProfileQuestion.where(question_type: ProfileQuestion::Type::LOCATION).first
    assert_equal "#{location_profile_question.id}-country", AdminViewColumn.new(profile_question_id: location_profile_question.id, column_sub_key: AdminViewColumn::ScopedProfileQuestion::Location::COUNTRY).key
    assert_equal "#{location_profile_question.id}", AdminViewColumn.new(profile_question_id: location_profile_question.id).key
  end

  def test_get_column_sub_key
    assert_equal "xyz", AdminViewColumn.get_column_sub_key("3-xyz")
  end

  def test_scoped_profile_question_text
    location_profile_question = ProfileQuestion.where(question_type: ProfileQuestion::Type::LOCATION).first
    admin_view = location_profile_question.organization.programs.first.admin_views.first
    assert_equal location_profile_question.question_text, AdminViewColumn.scoped_profile_question_text(admin_view, location_profile_question, "#{location_profile_question.id}")
    assert_equal "#{location_profile_question.question_text} (City)", AdminViewColumn.scoped_profile_question_text(admin_view, location_profile_question, "#{location_profile_question.id}-city")
    assert_equal "#{location_profile_question.question_text} (State)", AdminViewColumn.scoped_profile_question_text(admin_view, location_profile_question, "#{location_profile_question.id}-state")
    assert_equal "#{location_profile_question.question_text} (Country)", AdminViewColumn.scoped_profile_question_text(admin_view, location_profile_question, "#{location_profile_question.id}-country")
    location_profile_question.role_questions.each { |rq| rq.update_attributes(required: true) }
    location_profile_question.reload
    assert_equal location_profile_question.question_text + " *", AdminViewColumn.scoped_profile_question_text(admin_view, location_profile_question, "#{location_profile_question.id}")
    assert_equal "#{location_profile_question.question_text} (City) *", AdminViewColumn.scoped_profile_question_text(admin_view, location_profile_question, "#{location_profile_question.id}-city")
    assert_equal "#{location_profile_question.question_text} (State) *", AdminViewColumn.scoped_profile_question_text(admin_view, location_profile_question, "#{location_profile_question.id}-state")
    assert_equal "#{location_profile_question.question_text} (Country) *", AdminViewColumn.scoped_profile_question_text(admin_view, location_profile_question, "#{location_profile_question.id}-country")
  end

  def test_get_title_for_scoped_profile_questions
    location_profile_question = ProfileQuestion.where(question_type: ProfileQuestion::Type::LOCATION).first
    admin_view = location_profile_question.organization.programs.first.admin_views.first
    assert_equal "#{location_profile_question.question_text} (Country)", AdminViewColumn.new(admin_view_id: admin_view.id, profile_question_id: location_profile_question.id, column_sub_key: AdminViewColumn::ScopedProfileQuestion::Location::COUNTRY).get_title
    assert_equal "#{location_profile_question.question_text}", AdminViewColumn.new(admin_view_id: admin_view.id, profile_question_id: location_profile_question.id).get_title
  end

  def test_check_dependent_destoy_on_profile_question
    admin_view_column = AdminViewColumn.first
    assert admin_view_column.is_default?

    pq = ProfileQuestion.first
    admin_view_column.update_attributes!(:column_key => nil, :profile_question_id => pq.id)
    assert_false admin_view_column.is_default?

    assert_difference "AdminViewColumn.count", -1 do
      pq.destroy
    end
  end

  def test_column_headers_for_default
    admin_view_column = AdminViewColumn.first
    question = profile_questions(:profile_questions_1)
    admin_view_column.update_attributes!(column_key: nil, profile_question: question)
    assert_equal [], admin_view_column.column_headers
    assert_equal 1, admin_view_column.columns_count
  end

  def test_column_headers_for_multi_education_question
    admin_view_column = AdminViewColumn.first
    question = profile_questions(:profile_questions_6)
    admin_view_column.update_attributes!(column_key: nil, profile_question: question)
    expected = [
      "Education-College/School Name",
      "Education-Degree",
      "Education-Major",
      "Education-Graduation Year",
    ]
    assert_equal expected, admin_view_column.column_headers
    assert_equal 4, admin_view_column.columns_count
  end

  def test_column_headers_for_single_education_question
    admin_view_column = AdminViewColumn.first
    question = profile_questions(:education_q)
    admin_view_column.update_attributes!(column_key: nil, profile_question: question)
    expected = [
      "Current Education-College/School Name",
      "Current Education-Degree",
      "Current Education-Major",
      "Current Education-Graduation Year",
    ]
    assert_equal expected, admin_view_column.column_headers
    assert_equal 4, admin_view_column.columns_count
  end

  def test_column_headers_for_multi_experience_question
    admin_view_column = AdminViewColumn.first
    question = profile_questions(:profile_questions_7)
    admin_view_column.update_attributes!(column_key: nil, profile_question: question)
    expected = [
      "Work-Job Title",
      "Work-Start year",
      "Work-End year",
      "Work-Company/Institution",
    ]
    assert_equal expected, admin_view_column.column_headers
    assert_equal 4, admin_view_column.columns_count
  end

  def test_column_headers_for_single_experience_question
    admin_view_column = AdminViewColumn.first
    question = profile_questions(:experience_q)
    admin_view_column.update_attributes!(column_key: nil, profile_question: question)
    expected = [
      "Current Experience-Job Title",
      "Current Experience-Start year",
      "Current Experience-End year",
      "Current Experience-Company/Institution",
    ]
    assert_equal expected, admin_view_column.column_headers
    assert_equal 4, admin_view_column.columns_count
  end

  def test_column_headers_for_multi_publication_question
    admin_view_column = AdminViewColumn.first
    pub_question = create_question(:question_type => ProfileQuestion::Type::PUBLICATION, :question_text => "Publication", :organization => programs(:org_primary))
    admin_view_column.update_attributes!(column_key: nil, profile_question: pub_question)
    expected = [
      "Publication-Title",
      "Publication-Publication/Publisher",
      "Publication-Publication Date",
      "Publication-Publication URL",
      "Publication-Author(s)",
      "Publication-Description"
    ]
    assert_equal expected, admin_view_column.column_headers
    assert_equal 6, admin_view_column.columns_count
  end

  def test_column_headers_for_single_publication_question
    admin_view_column = AdminViewColumn.first
    question = profile_questions(:publication_q)
    admin_view_column.update_attributes!(column_key: nil, profile_question: question)
    expected = [
      "Current Publication-Title",
      "Current Publication-Publication/Publisher",
      "Current Publication-Publication Date",
      "Current Publication-Publication URL",
      "Current Publication-Author(s)",
      "Current Publication-Description"
    ]
    assert_equal expected, admin_view_column.column_headers
    assert_equal 6, admin_view_column.columns_count
  end

  def test_column_headers_for_single_manager_question
    admin_view_column = AdminViewColumn.first
    question = profile_questions(:manager_q)
    admin_view_column.update_attributes!(column_key: nil, profile_question: question)
    expected = [
      "Current Manager-First name",
      "Current Manager-Last name",
      "Current Manager-Email"
    ]
    assert_equal expected, admin_view_column.column_headers
    assert_equal 3, admin_view_column.columns_count
  end

  def test_terms_and_conditions_accepted_column
    admin_view_column = AdminViewColumn.first
    admin_view_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::TERMS_AND_CONDITIONS)

    user = users(:f_mentor)
    member = user.member

    Timecop.freeze Date.parse('2012-01-01') do
      member.update_attribute(:terms_and_conditions_accepted, Time.zone.now)
    end
    assert_equal '01 Jan 2012', admin_view_column.get_answer(user)
  end

  def test_engagement_accepted_column
    admin_view_column = AdminViewColumn.first
    admin_view_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS)

    user = users(:f_mentor)
    member = user.member
    ongoing_engagements_map = Member.get_groups_count_map_for_status(member.id, Group::Status::ACTIVE_CRITERIA) 
    closed_engagements_map = Member.get_groups_count_map_for_status(member.id, Group::Status::CLOSED)
    options = {ongoing_engagements_map: ongoing_engagements_map, closed_engagements_map: closed_engagements_map}

    assert_equal 3, admin_view_column.get_answer(member, {}, options)

    assert_equal "0", admin_view_column.get_answer(member, {}, {})

    admin_view_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::ORG_LEVEL_CLOSED_ENGAGEMENTS)

    assert_equal "0", admin_view_column.get_answer(member, {}, options)
  end

  def test_mentoring_request_columns
    mentor = users(:f_mentor)
    student = users(:mkr_student)

    t1 = Time.now.utc - 1.minute

    mr = create_mentor_request(:student => student, :mentor => mentor, :program => programs(:albers))
    mr2 = create_mentor_request(student: student, mentor: mentor, program: programs(:albers), status: AbstractRequest::Status::REJECTED)
    mr3 = create_mentor_request(student: student, mentor: mentor, program: programs(:albers), status: AbstractRequest::Status::CLOSED, closed_at: Time.now)

    received_column = AdminViewColumn.first
    sent_column = AdminViewColumn.first(2).last
    sent_pending_column = AdminViewColumn.first(3).last
    received_rejected_column = AdminViewColumn.first(4).last
    received_closed_column = AdminViewColumn.first(5).last
    received_pending_column = AdminViewColumn.last

    received_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED)
    sent_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT)
    sent_pending_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT_AND_PENDING)
    received_pending_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING)
    received_closed_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_CLOSED)
    received_rejected_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_REJECTED)

    assert_equal 18, received_column.get_answer(mentor)
    assert_equal "NA", sent_column.get_answer(mentor)
    assert_equal "NA", sent_pending_column.get_answer(mentor)
    assert_equal 12, received_pending_column.get_answer(mentor)
    assert_equal 5, received_rejected_column.get_answer(mentor)
    assert_equal 1, received_closed_column.get_answer(mentor)

    assert_equal "NA", received_column.get_answer(student)
    assert_equal 3, sent_column.get_answer(student)
    assert_equal 1, sent_pending_column.get_answer(student)
    assert_equal "NA", received_pending_column.get_answer(student)
    assert_equal "NA", received_rejected_column.get_answer(student)
    assert_equal "NA", received_closed_column.get_answer(student)

    mr.update_attributes!(:status => AbstractRequest::Status::WITHDRAWN)
    
    create_mentor_request(:student => student, :mentor => mentor, :program => programs(:albers))

    assert_equal 19, received_column.get_answer(mentor)
    assert_equal "NA", sent_column.get_answer(mentor)
    assert_equal "NA", sent_pending_column.get_answer(mentor)
    assert_equal 12, received_pending_column.get_answer(mentor)
    assert_equal 5, received_rejected_column.get_answer(mentor)
    assert_equal 1, received_closed_column.get_answer(mentor)

    assert_equal "NA", received_column.get_answer(student)
    assert_equal 4, sent_column.get_answer(student)
    assert_equal 1, sent_pending_column.get_answer(student)
    assert_equal "NA", received_pending_column.get_answer(student)
    assert_equal "NA", received_rejected_column.get_answer(student)
    assert_equal "NA", received_closed_column.get_answer(student)

    t2 = Time.now.utc + 1.hour

    assert_equal 4, received_column.get_answer(mentor, {}, date_ranges: { "mentoring_requests_received_v1" => t1..t2 })
    assert_equal "NA", sent_column.get_answer(mentor, {}, :date_ranges => {"mentoring_requests_sent_v1" => t1..t2})
    assert_equal "NA", sent_pending_column.get_answer(mentor, {}, :date_ranges => {"mentoring_requests_sent_and_pending_v1" => t1..t2})
    assert_equal 1, received_pending_column.get_answer(mentor, {}, :date_ranges => {"mentoring_requests_received_and_pending_v1" => t1..t2})
    assert_equal 1, received_rejected_column.get_answer(mentor, {}, :date_ranges => {"mentoring_requests_received_and_rejected" => t1..t2})
    assert_equal 1, received_closed_column.get_answer(mentor, {}, :date_ranges => {"mentoring_requests_received_and_closed" => t1..t2})

    assert_equal "NA", received_column.get_answer(student, {}, :date_ranges => {"mentoring_requests_received_v1" => t1..t2})
    assert_equal 4, sent_column.get_answer(student, {}, :date_ranges => {"mentoring_requests_sent_v1" => t1..t2})
    assert_equal 1, sent_pending_column.get_answer(student, {}, :date_ranges => {"mentoring_requests_sent_and_pending_v1" => t1..t2})
    assert_equal "NA", received_pending_column.get_answer(student, {}, :date_ranges => {"mentoring_requests_received_and_pending_v1" => t1..t2})
    assert_equal "NA", received_rejected_column.get_answer(student, {}, :date_ranges => {"mentoring_requests_received_and_rejected" => t1..t2})
    assert_equal "NA", received_rejected_column.get_answer(student, {}, :date_ranges => {"mentoring_requests_received_and_closed" => t1..t2})
  end

  def test_date_range_columns
    admin_view  = admin_views(:admin_views_1)
    admin_view_column = admin_view.admin_view_columns.last
    assert_equal_unordered ["created_at", "last_seen_at", "terms_and_conditions_accepted", "mentoring_requests_sent_v1", "mentoring_requests_received_v1", "mentoring_requests_sent_and_pending_v1", "mentoring_requests_received_and_pending_v1", "mentoring_requests_received_and_rejected", "mentoring_requests_received_and_closed", "meeting_requests_received_v1", "meeting_requests_sent_v1", "meeting_requests_sent_and_accepted_v1", "meeting_requests_received_and_accepted_v1", "meeting_requests_sent_and_pending_v1", "meeting_requests_received_and_pending_v1", "meeting_requests_received_and_rejected", "meeting_requests_received_and_closed", "last_closed_group_time", "last_deactivated_at", "last_suspended_at"], AdminViewColumn::Columns::DateRangeColumns.all(admin_view)

    admin_view_column.update(profile_question_id: profile_questions(:date_question).id)
    assert_equal_unordered ["column7"], AdminViewColumn::Columns::DateRangeColumns.custom_date_range_columns(admin_view)
    assert_equal_unordered ["created_at", "last_seen_at", "terms_and_conditions_accepted", "mentoring_requests_sent_v1", "mentoring_requests_received_v1", "mentoring_requests_sent_and_pending_v1", "mentoring_requests_received_and_pending_v1", "mentoring_requests_received_and_rejected", "mentoring_requests_received_and_closed", "meeting_requests_received_v1", "meeting_requests_sent_v1", "meeting_requests_sent_and_accepted_v1", "meeting_requests_received_and_accepted_v1", "meeting_requests_sent_and_pending_v1", "meeting_requests_received_and_pending_v1", "meeting_requests_received_and_rejected", "meeting_requests_received_and_closed", "last_closed_group_time", "last_deactivated_at", "last_suspended_at", "column7"], AdminViewColumn::Columns::DateRangeColumns.all(admin_view)
  end

  def test_meeting_request_columns
    mentor = users(:f_mentor)
    student = users(:mkr_student)
    received_column = AdminViewColumn.first
    sent_column = AdminViewColumn.first(2).last
    sent_accepted_column = AdminViewColumn.first(3).last
    received_accepted_column = AdminViewColumn.first(4).last
    sent_pending_column = AdminViewColumn.first(5).last
    received_rejected_column = AdminViewColumn.first(6).last
    received_closed_column = AdminViewColumn.first(7).last
    received_pending_column = AdminViewColumn.last

    received_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1)
    sent_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_V1)
    sent_accepted_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_ACCEPTED)
    received_accepted_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED)
    sent_pending_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_PENDING)
    received_pending_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_PENDING)
    received_closed_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED)
    received_rejected_column.update_attributes!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED)

    Timecop.freeze(Time.current - 1.minute) do
      meeting_request = create_meeting_request(student: student, mentor: mentor, program: student.program)
      meeting_request.update_column(:status, AbstractRequest::Status::WITHDRAWN)

      meeting_request2 = create_meeting_request(student: student, mentor: mentor, program: student.program)
      meeting_request2.update_attributes!(status: AbstractRequest::Status::CLOSED, closed_at: Time.current)

      meeting_request3 = create_meeting_request(student: student, mentor: mentor, program: student.program)
      meeting_request3.update_attributes!(status: AbstractRequest::Status::REJECTED)
    end

    assert_equal 8, received_column.get_answer(mentor)
    assert_equal "NA", sent_column.get_answer(mentor)
    assert_equal "NA", sent_accepted_column.get_answer(mentor)
    assert_equal 4, received_accepted_column.get_answer(mentor)
    assert_equal "NA", sent_pending_column.get_answer(mentor)
    assert_equal 1, received_pending_column.get_answer(mentor)
    assert_equal 1, received_closed_column.get_answer(mentor)
    assert_equal 1, received_rejected_column.get_answer(mentor)

    assert_equal "NA", received_column.get_answer(student)
    assert_equal 7, sent_column.get_answer(student)
    assert_equal 4, sent_accepted_column.get_answer(student)
    assert_equal "NA", received_accepted_column.get_answer(student)
    assert_equal 0, sent_pending_column.get_answer(student)
    assert_equal "NA", received_pending_column.get_answer(student)
    assert_equal "NA", received_closed_column.get_answer(student)
    assert_equal "NA", received_rejected_column.get_answer(student)

    t1 = Time.current
    create_meeting(force_non_group_meeting: true, mentor_created_meeting: true)
    t2 = Time.current + 5.minutes

    assert_equal 9, received_column.get_answer(mentor)
    assert_equal "NA", sent_column.get_answer(mentor)
    assert_equal "NA", sent_accepted_column.get_answer(mentor)
    assert_equal 5, received_accepted_column.get_answer(mentor)
    assert_equal "NA", sent_pending_column.get_answer(mentor)
    assert_equal 1, received_pending_column.get_answer(mentor)
    assert_equal 1, received_closed_column.get_answer(mentor)
    assert_equal 1, received_rejected_column.get_answer(mentor)

    date_range = { date_ranges: { AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1 => t1..t2 } }
    meeting_requests_received_count = mentor.received_meeting_requests.created_in_date_range(date_range[:date_ranges][AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1]).count

    assert_equal meeting_requests_received_count, received_column.get_answer(mentor, {}, date_range)
    assert_equal "NA", sent_column.get_answer(mentor, {}, :date_ranges => {"meeting_requests_sent_v1" => t1..t2})
    assert_equal "NA", sent_accepted_column.get_answer(mentor, {}, :date_ranges => {"meeting_requests_sent_and_accepted_v1" => t1..t2})
    assert_equal 1, received_accepted_column.get_answer(mentor, {}, :date_ranges => {"meeting_requests_received_and_accepted_v1" => t1..t2})
    assert_equal "NA", sent_pending_column.get_answer(mentor, {}, :date_ranges => {"meeting_requests_sent_and_pending_v1" => t1..t2})
    assert_equal 0, received_pending_column.get_answer(mentor, {}, :date_ranges => {"meeting_requests_received_and_pending_v1" => t1..t2})
    assert_equal 0, received_rejected_column.get_answer(mentor, {}, :date_ranges => {"meeting_requests_received_and_rejected" => t1..t2})
    assert_equal 0, received_closed_column.get_answer(mentor, {}, :date_ranges => {"meeting_requests_received_and_closed" => t1..t2})

    assert_equal "NA", received_column.get_answer(student)
    assert_equal 8, sent_column.get_answer(student)
    assert_equal 5, sent_accepted_column.get_answer(student)
    assert_equal "NA", received_accepted_column.get_answer(student)
    assert_equal 0, sent_pending_column.get_answer(student)
    assert_equal "NA", received_pending_column.get_answer(student)
    assert_equal "NA", received_rejected_column.get_answer(student)
    assert_equal "NA", received_closed_column.get_answer(student)

    date_range = { date_ranges: { "meeting_requests_sent_v1" => t1..t2 } }
    meeting_requests_sent_count = student.sent_meeting_requests.created_in_date_range(date_range[:date_ranges]["meeting_requests_sent_v1"]).count

    assert_equal "NA", received_column.get_answer(student, {}, :date_ranges => {"meeting_requests_received_v1" => t1..t2})
    assert_equal meeting_requests_sent_count, sent_column.get_answer(student, {}, :date_ranges => {"meeting_requests_sent_v1" => t1..t2})
    assert_equal 1, sent_accepted_column.get_answer(student, {}, :date_ranges => {"meeting_requests_sent_and_accepted_v1" => t1..t2})
    assert_equal "NA", received_accepted_column.get_answer(student, {}, :date_ranges => {"meeting_requests_received_and_accepted_v1" => t1..t2})
    assert_equal 0, sent_pending_column.get_answer(student, {}, :date_ranges => {"meeting_requests_sent_and_pending_v1" => t1..t2})
    assert_equal "NA", received_pending_column.get_answer(student, {}, :date_ranges => {"meeting_requests_received_and_pending_v1" => t1..t2})
    assert_equal "NA", received_rejected_column.get_answer(student, {}, :date_ranges => {"meeting_requests_received_and_rejected" => t1..t2})
    assert_equal "NA", received_closed_column.get_answer(student, {}, :date_ranges => {"meeting_requests_received_and_closed" => t1..t2})
  end

  def test_rating_key
    assert_equal AdminViewColumn::Columns::Key::RATING, "rating"
    assert AdminViewColumn::Columns::Key.mentor_only.include?(AdminViewColumn::Columns::Key::RATING)
    assert AdminViewColumn::Columns::ProgramDefaults.non_defaults.keys.include?(AdminViewColumn::Columns::Key::RATING)
    assert AdminViewColumn::Columns::ProgramDefaults.coach_rating_column.include?(AdminViewColumn::Columns::Key::RATING)
    assert AdminViewColumn::Columns::ProgramDefaults.all.include?(AdminViewColumn::Columns::Key::RATING)
    assert AdminViewColumn::Columns::ProgramDefaults.count_columns.include?(AdminViewColumn::Columns::Key::RATING)
    assert AdminViewColumn::Columns::ProgramDefaults.count_columns.include?(AdminViewColumn::Columns::Key::RATING)
    assert_equal [AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1, AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_V1, AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_ACCEPTED, AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_PENDING, AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_PENDING, AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_REJECTED, AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_CLOSED], AdminViewColumn::Columns::Key.meeting_request_columns
  end
end