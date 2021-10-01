require_relative './../../test_helper.rb'

class UserProfileFilterServiceTest < ActiveSupport::TestCase

  def test_initialize_filterable_and_summary_questions
    program = programs(:albers)
    organization = program.organization
    user = users(:f_admin)
    role1 = program.roles.for_mentoring.first
    role2 = program.roles.for_mentoring.last

    pq1 = ProfileQuestion.create!(:organization => programs(:org_primary), :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :section => organization.sections.first, :question_text => "Single choice")
    ["A", "B", "C", "D"].each{|text| pq1.question_choices.create!(text: text)}
    rq1_1 = role1.role_questions.create(filterable: true, profile_question_id: pq1.id, in_summary: true)
    rq1_2 = role2.role_questions.create(filterable: false, profile_question_id: pq1.id, in_summary: true, private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    assert rq1_2.in_summary

    pq2 = ProfileQuestion.create!(:organization => programs(:org_primary), :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :section => organization.sections.first, :question_text => "Single choice", :position => 8)
    ["A", "B", "C", "D"].each{|text| pq2.question_choices.create!(text: text)}
    rq2_1 = role1.role_questions.create(filterable: true, profile_question_id: pq2.id, in_summary: false)
    rq2_2 = role2.role_questions.create(filterable: true, profile_question_id: pq2.id, in_summary: false)

    pq3 = ProfileQuestion.create!(:organization => programs(:org_primary), :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :section => organization.sections.first, :question_text => "Single choice")
    ["A", "B", "C", "D"].each{|text| pq3.question_choices.create!(text: text)}
    rq3_1 = role1.role_questions.create(filterable: false, profile_question_id: pq3.id, in_summary: false)

    pq4 = ProfileQuestion.create!(:organization => programs(:org_primary), :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :section => organization.sections.first, :question_text => "Single choice", :position => 7)
    ["A", "B", "C", "D"].each{|text| pq4.question_choices.create!(text: text)}
    rq4_1 = role1.role_questions.create(filterable: true, profile_question_id: pq4.id, in_summary: false)
    rq4_2 = role2.role_questions.create(filterable: true, profile_question_id: pq4.id, in_summary: false)

    filter_service = UserProfileFilterService.new(program, nil, program.roles.for_mentoring.pluck(:name))

    assert filter_service.filter_questions.include?(pq1)
    assert filter_service.filter_questions.include?(pq2)
    assert_false filter_service.filter_questions.include?(pq3)

    assert filter_service.in_summary_questions.include?(rq1_1)
    assert_false filter_service.in_summary_questions.include?(rq2_1)
    assert_false filter_service.in_summary_questions.include?(rq3_1)

    assert filter_service.profile_filterable_questions.include?(pq1)
    assert_false filter_service.profile_filterable_questions.include?(pq2)
    assert_false filter_service.profile_filterable_questions.include?(pq3)

    assert_false filter_service.non_profile_filterable_questions.include?(pq1)
    assert filter_service.non_profile_filterable_questions.include?(pq2)
    assert_false filter_service.non_profile_filterable_questions.include?(pq3)
    assert_equal filter_service.non_profile_filterable_questions.group_by(&:section_id).values.first.collect(&:id), [pq4.id, pq2.id]


    filter_service = UserProfileFilterService.new(program, nil, [role2.name])
    assert_false filter_service.filter_questions.include?(pq1)
    assert filter_service.filter_questions.include?(pq2)
    assert_false filter_service.filter_questions.include?(pq3)
  end

  def test_get_profile_filters_to_be_applied
    filter_params = {
      :pq => {12 => "CS", 13 => "", 14 => "Hello"},
      :apple => "hello world"
    }
    custom_profile_filters = UserProfileFilterService.get_profile_filters_to_be_applied(filter_params)
    assert_equal_hash({12 => "CS", 14 => "Hello"}, custom_profile_filters)
  end

  def test_filter_based_on_question_type_for_email_type
    email_question = profile_questions(:profile_questions_2)
    program = programs(:albers)
    user_or_member_ids = program.users.pluck(:id)
    f_student = members(:f_student)
    rahim = members(:rahim)
    member_ids_with_email_rahim = [f_student.id, rahim.id]

    assert_equal_unordered member_ids_with_email_rahim, UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, email_question, "rahim")

    rahim.update_attribute(:email, "abc@example.com")
    user_or_member_ids = program.users.pluck(:id)
    assert_equal [f_student.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, email_question, "rahim")

    user_or_member_ids = program.users.pluck(:id)
    assert_equal [rahim.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, email_question, "abc@example.com")
  end

  def test_filter_based_on_question_type_for_date_question
    date_question = profile_questions(:date_question)
    program = programs(:albers)
    f_mentor = members(:f_mentor)
    f_mentor_student = members(:f_mentor_student)

    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [f_mentor.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, date_question, "06/23/2017 - 06/23/2017")
    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [f_mentor.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, date_question, "06/23/2000 - 06/23/2017")
    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [f_mentor.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, date_question, "06/23/2017 - 05/28/2018")

    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [f_mentor_student.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, date_question, "05/29/2019 - 05/29/2019")
    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [f_mentor_student.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, date_question, "06/23/2018 - 05/29/2019")
    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [f_mentor_student.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, date_question, "06/25/2017 - 05/29/2019")

    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, date_question, "03/25/2018 - 05/28/2018")
    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [f_mentor.id, f_mentor_student.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, date_question, "06/23/2017 - 05/29/2019")    
  end

  def test_filter_based_on_question_type_for_locations
    Location.create(city: "Salem", state: "Tamil Nadu", country: "India", full_address: "Salem, Tamil Nadu, India")
    program = programs(:albers)
    question = ProfileQuestion.find(3)
    delhi_user = Member.find(8).user_in_program(program)
    chennai_user = Member.find(3).user_in_program(program)
    salem_user, pondichery_user, ukraine_user = program.users.select{|u| u.profile_answers.where(profile_question_id: 3).empty? }
    salem_user.member.profile_answers.create(profile_question_id: question.id, location_id: Location.where(city: "Salem").first.id)
    pondichery_user.member.profile_answers.create(profile_question_id: question.id, location_id: Location.where(state: "Pondicherry").first.id)
    ukraine_user.member.profile_answers.create(profile_question_id: question.id, location_id: Location.where(country: "Ukraine").first.id)

    # prog level
    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [chennai_user.id, salem_user.id, pondichery_user.id, delhi_user.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, question, "India")
    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [chennai_user.id, salem_user.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, question, "Tamil Nadu, India")
    user_or_member_ids = program.users.pluck(:id)
    assert_equal_unordered [chennai_user.id], UserProfileFilterService.filter_based_on_question_type!(program, user_or_member_ids, question, "Chennai, Tamil Nadu, India")

    # org level
    organization = programs(:org_primary)
    user_or_member_ids = organization.members.pluck(:id)
    assert_equal_unordered [chennai_user.member.id, salem_user.member.id, pondichery_user.member.id, delhi_user.member.id, 69, 70], UserProfileFilterService.filter_based_on_question_type!(organization, user_or_member_ids, question, "India", filter_for_members: true)
    user_or_member_ids = organization.members.pluck(:id)
    assert_equal_unordered [chennai_user.member.id, salem_user.member.id, 70], UserProfileFilterService.filter_based_on_question_type!(organization, user_or_member_ids, question, "Tamil Nadu, India", filter_for_members: true)
    user_or_member_ids = organization.members.pluck(:id)
    assert_equal_unordered [chennai_user.member.id, 70], UserProfileFilterService.filter_based_on_question_type!(organization, user_or_member_ids, question, "Chennai, Tamil Nadu, India", filter_for_members: true)
  end

  def test_get_locations_ids
    Location.create(city: "Salem", state: "Tamil Nadu", country: "India", full_address: "Salem, Tamil nadu")
    assert_equal_unordered Location.where(city: "Chennai").pluck(:id) + [0], UserProfileFilterService.get_locations_ids(["Chennai", "Tamil Nadu", "India"].join(AdminView::LOCATION_SCOPE_SPLITTER))
    assert_equal_unordered Location.where(state: "Tamil Nadu").pluck(:id) + [0], UserProfileFilterService.get_locations_ids(["Tamil Nadu", "India"].join(AdminView::LOCATION_SCOPE_SPLITTER))
    assert_equal_unordered Location.where(country: "India").pluck(:id) + [0], UserProfileFilterService.get_locations_ids(["India"].join(AdminView::LOCATION_SCOPE_SPLITTER))
    def location_joiner(ary); ary.map{|x|x.join(AdminView::LOCATION_SCOPE_SPLITTER)}.join(AdminView::LOCATION_VALUES_SPLITTER); end
    assert_equal_unordered Location.where(city: ["Chennai", "Kiev"]).pluck(:id) + [0], UserProfileFilterService.get_locations_ids(location_joiner([["Chennai", "Tamil Nadu", "India"],["Kiev", "Kiev", "Ukraine"]]))
    assert_equal_unordered Location.where(state: ["Tamil Nadu", "Pondicherry"]).pluck(:id) + [0], UserProfileFilterService.get_locations_ids(location_joiner([["Tamil Nadu", "India"], ["Pondicherry", "India"]]))
    assert_equal_unordered Location.where(country: ["India", "Ukraine"]).pluck(:id) + [0], UserProfileFilterService.get_locations_ids(location_joiner([["India"], ["Ukraine"]]))
  end

  def test_apply_profile_filters 
    program = programs(:albers)
    organization = program.organization
    user1 = program.users.first
    user2 = program.users.last
    role1 = program.roles.for_mentoring.first
    role2 = program.roles.for_mentoring.last

    pq1 = ProfileQuestion.create!(:organization => organization, :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :section => organization.sections.first, :question_text => "Single choice")
    qc_ids_hash = {}
    ["A", "B", "C", "D"].each do |text|
      qc = pq1.question_choices.create!(text: text)
      qc_ids_hash[text] = qc.id
    end
    rq1 = role1.role_questions.create(filterable: true, profile_question_id: pq1.id, in_summary: true)
    rq2 = role2.role_questions.create(filterable: true, profile_question_id: pq1.id, in_summary: true)

    user1.member.profile_answers.create(profile_question_id: pq1.id, answer_value: "A")
    user2.member.profile_answers.create(profile_question_id: pq1.id, answer_value: "B")

    filter_questions = UserProfileFilterService.new(program, nil, [role1.name]).filter_questions

    custom_profile_filters = UserProfileFilterService.get_profile_filters_to_be_applied({:pq => {"#{pq1.id}" => [qc_ids_hash["B"]]}})
    user_ids = program.users.pluck(:id)
    UserProfileFilterService.apply_profile_filters!(program, user_ids, filter_questions, custom_profile_filters, nil)
    assert_equal [user2.id], user_ids

    custom_profile_filters = UserProfileFilterService.get_profile_filters_to_be_applied({:pq => {"#{pq1.id}" => [qc_ids_hash["A"], qc_ids_hash["B"]]}})
    user_ids = program.users.pluck(:id)
    UserProfileFilterService.apply_profile_filters!(program, user_ids, filter_questions, custom_profile_filters, nil)
    assert_equal [user1.id, user2.id], user_ids
  end

  def test_filter_based_on_regex_match
    program = programs(:albers)
    # options passed
    filtered_ids = UserProfileFilterService.filter_based_on_regex_match(program, members(:f_mentor, :robert).collect(&:id), profile_questions(:single_choice_q), ["opt_1"], filter_for_members: true)
    assert_equal [members(:f_mentor).id], filtered_ids

    filtered_ids = UserProfileFilterService.filter_based_on_regex_match(program, users(:f_mentor, :robert).collect(&:id), profile_questions(:single_choice_q), ["opt_1"])
    assert_equal [users(:f_mentor).id], filtered_ids
  end

  def test_add_location_parameters_to_options
    # search_filters_param, options, my_filters
    ProfileQuestion.where(:question_type => ProfileQuestion::Type::LOCATION).destroy_all
    location = Location.first
    location_name = location.full_address
    program = programs(:albers)
    organization = program.organization
    pq = ProfileQuestion.create!(:organization => organization,
        :question_type => ProfileQuestion::Type::LOCATION, 
        :section => organization.sections.first,
        :question_text => "Whats your location?")

    search_filters_param = {:location => {pq.id.to_s => {:name => location_name}}}

    with_options = {:role_ids => program.mentoring_role_ids}
    options = {:with=> with_options}
    location_params_hash = UserProfileFilterService.add_location_parameters_to_options(search_filters_param, options, nil)
    assert location_params_hash[:pivot_location]
    assert location_params_hash[:options][:location_filter].present?
    assert_equal location.full_city, location_params_hash[:options][:location_filter][:address].split(",").map{|loc| loc.strip}.join(",")

    search_filters_param = {:location => {pq.id.to_s => {:name => "IIT Madras"}}}
    chennai_details = Geokit::GeoLoc.new(
        :city => locations(:chennai).city,
        :state_name => locations(:chennai).state,
        :country_code => "IN",
        :lat => locations(:chennai).lat,
        :lng => locations(:chennai).lng,
        :full_address => locations(:chennai).full_address)

    Location.stubs(:geocode).returns(chennai_details)
    with_options = {:role_ids => program.mentoring_role_ids}
    options = {:with=> with_options}
    location_params_hash = UserProfileFilterService.add_location_parameters_to_options(search_filters_param, options, nil)
    assert true, location_params_hash[:pivot_location]
    assert location_params_hash[:options][:geo].present?
    assert_equal [chennai_details.lng, chennai_details.lat], location_params_hash[:options][:geo][:point]
    assert_equal location.full_city, location_params_hash[:options][:geo][:location_name]
    assert_equal "10mi", location_params_hash[:options][:geo][:distance]
  end

end