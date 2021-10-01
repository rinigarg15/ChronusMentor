require_relative './../../test_helper.rb'

class ProfileQuestion::ImporterTest < ActiveSupport::TestCase
  def setup
    super
    Section.delete_all
    ProfileQuestion.delete_all
    RoleQuestion.delete_all
    RoleQuestionPrivacySetting.delete_all
  end

  def test_build_from_hash_should_success
    data = [{
      attributes: {
        title: "Section"
      },
      profile_questions: [{
        attributes: {
          question_text: "Location",
          question_type: ProfileQuestion::Type::LOCATION,
        },
        role_questions: [{
          role_name: RoleConstants::MENTOR_NAME,
          attributes: {
            available_for: RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS,
            private: RoleQuestion::PRIVACY_SETTING::RESTRICTED
          },
          privacy_settings: [
            {role_name: nil, attributes: {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS}},
            {role_name: RoleConstants::MENTOR_NAME, attributes: {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role: Role.new}},
          ]
        }],
        question_choices: []
      }]
    }]
    ProfileQuestion::Importer.build_from_hash(data, target_organization)
    target_organization.save!

    assert_not_empty target_organization.sections

    section = target_organization.sections[0]
    assert_equal "Section", section.title
    assert_not_empty section.profile_questions

    question = section.profile_questions[0]
    assert_equal "Location", question.question_text
    assert_equal ProfileQuestion::Type::LOCATION, question.question_type
    assert_not_empty question.role_questions

    role_question = question.role_questions.first
    assert_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, role_question.private
    assert role_question.show_connected_members?
    assert role_question.show_for_roles?(role_question.program.get_role(RoleConstants::MENTOR_NAME))
    assert_false role_question.show_for_roles?(role_question.program.get_role(RoleConstants::STUDENT_NAME))
  end

  def test_invalid_header_should_not_raise
    s = [
      %{Section Name,Section Description",Field Name,Field Type,Allow Multiple Responses,Options,Options Count,Allow to Specify Different Answer,Field Description,Include for Mentor|Mentee,Include in Profile,Include in Membership Form,Visibility,Editable by Admin Only,Mendatory,Show in Listing,Available for Search},
      %{,,Location 1,location,,,,,,yes,yes,yes|no,everyone,no,no|yes,yes,yes},
    ].join("\n")
    stubs_uploaded_file_read(s, s)
    assert !import_stream(s)
    assert_not_empty ProfileQuestion::Importer.error_messages
    assert_instance_of Array, ProfileQuestion::Importer.error_messages
    assert_equal 1, ProfileQuestion::Importer.error_messages.size
    error_message = ProfileQuestion::Importer.error_messages[0]
    assert_match /^Parsing error: /, error_message
  end

  def test_unexpected_header_should_not_raise
    # "Mndatory" instead of "Mandatory"
    s = [
      "Section Name,Section Description,Field Name,Field Type,Allow Multiple Responses,Options,Options Count,Allow to Specify Different Answer,Field Description,Include for Mentor|Mentee,Include in Profile,Include in Membership Form,Visibility,Editable by Admin Only,Mendatory,Show in Listing,Available for Search",
      ",,Location 1,location,,,,,,yes,yes,yes|no,everyone,no,no|yes,yes,yes",
    ].join("\n")
    stubs_uploaded_file_read(s, s)
    assert !import_stream(s)
    assert_not_empty ProfileQuestion::Importer.error_messages
    assert_instance_of Array, ProfileQuestion::Importer.error_messages
    assert_equal 1, ProfileQuestion::Importer.error_messages.size
    error_message = ProfileQuestion::Importer.error_messages[0]
    assert_match /^Error at line 1: missing headers - Mandatory, invalid headers - Mendatory/, error_message
  end

  def test_missing_header_should_not_raise
    # no "Section Name"
    s = [
      "Section Description,Field Name,Field Type,Allow Multiple Responses,Options,Options Count,Allow to Specify Different Answer,Field Description,Include for Mentor|Mentee,Include in Profile,Include in Membership Form,Visibility,Editable by Admin Only,Mendatory,Show in Listing,Available for Search",
      ",,Location 1,location,,,,,,yes,yes,yes|no,everyone,no,no|yes,yes,yes",
    ].join("\n")
    stubs_uploaded_file_read(s, s)
    assert !import_stream(s)
    assert_not_empty ProfileQuestion::Importer.error_messages
    assert_instance_of Array, ProfileQuestion::Importer.error_messages
    assert_equal 1, ProfileQuestion::Importer.error_messages.size
    error_message = ProfileQuestion::Importer.error_messages[0]
    assert_match /^Error at line 1: missing headers - Section Name/, error_message
  end

  def test_location_should_be_uniq
    s = [
      "Section Name,Section Description,Field Name,Field Type,Allow Multiple Responses,Options,Options Count,Allow to Specify Different Answer,Field Description,Include for Mentor|Mentee,Include in Profile,Include in Membership Form,Visibility,Editable by Admin Only,Mandatory,Show in Listing,Available for Search",
      ",,Location 1,location,,,,,,yes,yes,yes|no,everyone,no,no|yes,yes,yes",
      ",,Location 2,location,,,,,,yes,yes,yes|no,everyone,no,no|yes,yes,yes",
    ].join("\n")
    stubs_uploaded_file_read(s, s)
    assert !import_stream(s)
    assert_not_empty ProfileQuestion::Importer.error_messages
    assert_instance_of Array, ProfileQuestion::Importer.error_messages
    assert_equal 1, ProfileQuestion::Importer.error_messages.size
    error_message = ProfileQuestion::Importer.error_messages[0]
    assert_match /^Error at line 3: organization should has one 'location' question/, error_message
  end

  def test_email_question_should_be_failed
    h = basic_hash_for_question.merge({
      "Field Type" => "email",
    })
    assert !import_stream(hash_to_stream(h))
    assert_not_empty ProfileQuestion::Importer.error_messages
    assert_instance_of Array, ProfileQuestion::Importer.error_messages
    assert_equal 1, ProfileQuestion::Importer.error_messages.size
    error_message = ProfileQuestion::Importer.error_messages[0]
    assert_match /^Error at line 2: Field Type can't be email/, error_message
  end

  def test_admin_only_viewable_should_switch_fields
    # If Visibility is RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE then
    h = basic_hash_for_question.merge({
      "Visibility"                 => "administrators",
      "Include in Profile"         => "no",
      "Include in Membership Form" => "yes",
      "Editable by Admin Only"     => "no",
      "Mandatory"                  => "yes",
      "Show in Listing"            => "yes",
      "Available for Search"       => "yes",
    })
    import_stream(hash_to_stream(h))

    init_created_role_questions
    role_question = @role_questions[0]

    # it is editable only by administrator
    assert role_question.admin_only_editable
    # it is available only for profile form
    assert_equal RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS, role_question.available_for
    # it cannot be mandatory
    assert !role_question.required?
    # it is not available in listing
    assert role_question.in_summary?
    assert_false role_question.show_in_summary?
    # it is not available for advanced search
    assert !role_question.filterable?
  end

  def test_user_and_mentors_should_switch_filterable_field
    # If Visibility is restricted to mentors then
    h = basic_hash_for_question.merge({
      "Visibility"           => "user_and_mentors",
      "Available for Search" => "yes",
    })
    import_stream(hash_to_stream(h))

    init_created_role_questions
    role_question = @role_questions[0]

    # it is not available for advanced search
    assert !role_question.filterable?
  end

  def test_connected_members_should_switch_fields
    # If Visibility is restricted to connected members then
    h = basic_hash_for_question.merge({
      "Visibility"           => "user_and_his_members",
      "Show in Listing"      => "yes",
      "Available for Search" => "yes",
    })
    import_stream(hash_to_stream(h))

    init_created_role_questions
    role_question = @role_questions[0]

    # it is not available in listing
    assert role_question.in_summary?
    assert_false role_question.show_in_summary?
    # it is not available for advanced search
    assert !role_question.filterable?
  end

  def test_only_admin_should_switch_fields
    # If Visibility is restricted to user and admin only then
    h = basic_hash_for_question.merge({
      "Visibility"           => "user",
      "Show in Listing"      => "yes",
      "Available for Search" => "yes",
    })
    import_stream(hash_to_stream(h))

    init_created_role_questions
    role_question = @role_questions[0]

    # it is not available in listing
    assert role_question.in_summary?
    assert_false role_question.show_in_summary?
    # it is not available for advanced search
    assert !role_question.filterable?
  end

  # Invalid data test
  def test_should_collect_errors
    res = import_file('profile_questions_invalid.csv')

    assert !res

    assert_not_empty ProfileQuestion::Importer.errors
    assert_instance_of Array, ProfileQuestion::Importer.errors
    assert_equal 1, ProfileQuestion::Importer.errors.size
    
    error = ProfileQuestion::Importer.errors[0]
    assert_instance_of ProfileQuestion::Importer::Error, error
    assert_equal 2, error.line
    assert_instance_of ActiveModel::Errors, error.errors
    assert_not_nil error.errors[:title]

    assert_not_empty ProfileQuestion::Importer.error_messages
    assert_instance_of Array, ProfileQuestion::Importer.error_messages
    assert_equal 1, ProfileQuestion::Importer.error_messages.size

    error_message = ProfileQuestion::Importer.error_messages[0]
    assert_instance_of String, error_message
    assert_match /^Error at line 2: Field Name can't be blank/, error_message
  end

  def test_should_build_attributes_hash_if_success
    res = import_file

    assert_instance_of Array, res
    assert_equal 2, res.size

    section_hash = res[1]
    assert section_hash.has_key?(:attributes)
    assert section_hash.has_key?(:profile_questions)

    pq_hash = section_hash[:profile_questions][0]
    assert pq_hash.has_key?(:attributes)
    assert pq_hash.has_key?(:role_questions)

    rq_hash = pq_hash[:role_questions][0]
    assert rq_hash.has_key?(:role_name)
    assert rq_hash.has_key?(:attributes)
  end

  # Normal scope test
  def test_should_create_all_roles
    assert_difference 'Role.count', 3 do
      import_file_for_new_organization
    end
  end

  def test_should_create_sections
    assert_difference 'target_organization.sections.count', 2 do
      assert import_file
    end
    init_created_sections

    assert_not_nil @sections[0]
    assert_not_nil @sections[1]
  end

  def test_should_assign_section_title
    import_file
    init_created_sections
    assert_equal "Basic Information",  @sections[0].title
    assert_equal "Work and Education", @sections[1].title
  end

  def test_should_assign_section_description
    import_file
    init_created_sections
    assert_blank @sections[0].description
    assert_equal "Work and Education information", @sections[1].description
  end

  def test_should_assign_section_position
    import_file
    init_created_sections
    assert_equal 1, @sections[0].position
    assert_equal 2, @sections[1].position
  end

  def test_should_assign_section_default_field
    import_file
    init_created_sections
    assert  @sections[0].default_field?
    assert !@sections[1].default_field?
  end

  def test_should_assign_help_text
    import_file
    init_created_questions

    assert_equal "",                              @questions[0].help_text
    assert_equal "",                              @questions[1].help_text
    assert_equal "",                              @questions[2].help_text
    assert_equal "What is your education?",       @questions[3].help_text
    assert_equal "Describe you working industry", @questions[4].help_text
  end

  def test_should_assign_position
    import_file
    init_created_questions

    assert_equal 1, @questions[0].position
    assert_equal 2, @questions[1].position
    assert_equal 3, @questions[2].position
    assert_equal 4, @questions[3].position
    assert_equal 5, @questions[4].position
  end

  def test_should_assign_allow_other_option
    import_file
    init_created_questions

    assert !@questions[0].allow_other_option?
    assert !@questions[1].allow_other_option?
    assert !@questions[2].allow_other_option?
    assert !@questions[3].allow_other_option?
    assert  @questions[4].allow_other_option?
  end

  def test_should_assign_correct_options_count
    import_file
    init_created_questions

    assert_equal 0, @questions[0].options_count
    assert_equal 0, @questions[1].options_count
    assert_equal 0, @questions[2].options_count
    assert_equal 0, @questions[3].options_count
    assert_equal 2, @questions[4].options_count
  end

  def test_should_assign_question_choices
    import_file
    init_created_questions

    assert_empty @questions[0].question_choices
    assert_empty @questions[1].question_choices
    assert_empty @questions[2].question_choices
    assert_empty @questions[3].question_choices
    assert_equal ["Accounting", "Airlines/Aviation", "Alternative Dispute Resolution"], @questions[4].question_choices.map(&:text)
  end

  def test_should_assign_question_type
    import_file
    init_created_questions

    assert_equal ProfileQuestion::Type::NAME,            @questions[0].question_type
    assert_equal ProfileQuestion::Type::EMAIL,           @questions[1].question_type
    assert_equal ProfileQuestion::Type::LOCATION,        @questions[2].question_type
    assert_equal ProfileQuestion::Type::MULTI_EDUCATION, @questions[3].question_type
    assert_equal ProfileQuestion::Type::MULTI_CHOICE,    @questions[4].question_type
  end

  def test_should_assign_question_text
    import_file
    init_created_questions

    assert_equal "Name",      @questions[0].question_text
    assert_equal "Email",     @questions[1].question_text
    assert_equal "Location",  @questions[2].question_text
    assert_equal "Education", @questions[3].question_text
    assert_equal "Industry",  @questions[4].question_text
  end

  def test_should_assign_sections
    import_file
    init_created_questions
    init_created_sections

    assert_equal @sections[0], @questions[0].section
    assert_equal @sections[0], @questions[1].section
    assert_equal @sections[0], @questions[2].section
    assert_equal @sections[1], @questions[3].section
    assert_equal @sections[1], @questions[4].section
  end

  def test_should_create_questions
    assert_difference 'target_organization.profile_questions.count', 6 do
      assert_difference 'target_organization.profile_questions_with_email_and_name.count', 8 do
        import_file
      end
    end
    init_created_questions

    assert_not_nil @questions[0]
    assert_not_nil @questions[1]
    assert_not_nil @questions[2]
    assert_not_nil @questions[3]
    assert_not_nil @questions[4]
    assert_not_nil @questions[5]
  end

  def test_should_create_role_questions
    assert_difference 'RoleQuestion.count', 12 do
      import_file
    end
    init_created_questions

    assert_equal 2, @questions[0].role_questions.count
    assert_equal 2, @questions[1].role_questions.count
    assert_equal 2, @questions[2].role_questions.count
    assert_equal 2, @questions[3].role_questions.count
    assert_equal 1, @questions[4].role_questions.count
    assert_equal 1, @questions[5].role_questions.count
  end

  def test_should_assign_role_questions_required
    import_file
    init_created_role_questions

    assert !@role_questions[0].required?
    assert !@role_questions[1].required?
  end

  def test_should_assign_role_questions_private
    import_file
    init_created_role_questions
    role_question = @role_questions[0]
    assert_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, role_question.private
    assert role_question.show_connected_members?
    assert_false role_question.show_for_roles?(role_question.program.roles)


    role_question = @questions[5].role_questions.last
    assert_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, role_question.private
    assert_false role_question.show_connected_members?
    assert role_question.show_for_roles?(role_question.program.roles)

    role_question = @questions[6].role_questions.last
    assert_equal RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, role_question.private

    role_question = @questions[7].role_questions.last
    assert_equal RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, role_question.private
  end

  def test_should_assign_role_questions_filterable
    import_file
    init_created_role_questions

    assert !@role_questions[0].filterable?
    assert !@role_questions[1].filterable?
  end

  def test_should_assign_role_questions_in_summary
    import_file
    init_created_role_questions

    assert @role_questions[0].in_summary?
    assert_false @role_questions[0].show_in_summary?
    assert @role_questions[1].in_summary?
    assert_false @role_questions[1].show_in_summary?
  end

  def test_should_assign_role_questions_available_for
    import_file
    init_created_role_questions

    assert_equal RoleQuestion::AVAILABLE_FOR::BOTH, @role_questions[0].available_for
    assert_equal RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS, @role_questions[1].available_for
  end

  def test_should_correct_available_for
    import_file
    init_created_role_questions(true)
    assert_equal RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS, @role_questions[6].available_for
  end

  def test_should_assign_role_questions_admin_only_editable
    import_file
    init_created_role_questions

    assert !@role_questions[0].admin_only_editable?
    assert  @role_questions[1].admin_only_editable?
  end

  def test_compute_private_value
    program = target_organization.programs.new
    program.build_default_roles

    member_setting = {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS}
    mentor_setting = {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role: program.get_role(RoleConstants::MENTOR_NAME)}
    mentee_setting = {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role: program.get_role(RoleConstants::STUDENT_NAME)}

    assert_equal RoleQuestion::PRIVACY_SETTING::ALL, ProfileQuestion::Importer.compute_private_value(program, "user_and_his_members , everyone  , administrators, user")
    assert_equal RoleQuestion::PRIVACY_SETTING::ALL, ProfileQuestion::Importer.compute_private_value(program, "everyone")

    assert_equal RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, ProfileQuestion::Importer.compute_private_value(program, "user, administrators")
    assert_equal RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, ProfileQuestion::Importer.compute_private_value(program, "user")

    assert_equal RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, ProfileQuestion::Importer.compute_private_value(program, "administrators")
    assert_equal RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, ProfileQuestion::Importer.compute_private_value(program, "")

    assert_equal [RoleQuestion::PRIVACY_SETTING::RESTRICTED, [member_setting]], ProfileQuestion::Importer.compute_private_value(program, "user_and_his_members, user")
    assert_equal [RoleQuestion::PRIVACY_SETTING::RESTRICTED, [mentor_setting, mentee_setting]], ProfileQuestion::Importer.compute_private_value(program, "user_and_mentors, user_and_mentees")
  end

  def test_compute_restricted_privacy_settings
    program = target_organization.programs.new
    program.build_default_roles

    member_setting = {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS}
    mentor_setting = {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role: program.get_role(RoleConstants::MENTOR_NAME)}
    mentee_setting = {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role: program.get_role(RoleConstants::STUDENT_NAME)}

    assert_equal [], ProfileQuestion::Importer.compute_restricted_privacy_settings(program, [])
    assert_equal [member_setting], ProfileQuestion::Importer.compute_restricted_privacy_settings(program, ['his_members'])
    assert_equal [mentor_setting], ProfileQuestion::Importer.compute_restricted_privacy_settings(program, ['mentors'])
    assert_equal [mentee_setting], ProfileQuestion::Importer.compute_restricted_privacy_settings(program, ['mentees'])
    assert_equal [member_setting, mentor_setting, mentee_setting], ProfileQuestion::Importer.compute_restricted_privacy_settings(program, ['his_members', 'mentors', 'mentees'])
  end

protected
  def target_organization
    @organization ||= programs(:org_primary)
  end

  def init_created_questions
    @questions = target_organization.profile_questions_with_email_and_name.all
  end

  def init_created_sections
    @sections = target_organization.sections.all
  end

  def init_created_role_questions(all = false)
    init_created_questions
    @role_questions = if all
      @questions.inject([]) { |res, q| res += q.role_questions.all }
    else
      # 2 - for first non-default question
      @questions[2].role_questions.all
    end
  end

  def basic_hash_for_question
    {
      "Section Name"                      => "",
      "Section Description"               => "",
      "Field Name"                        => "Line",
      "Field Type"                        => "string",
      "Allow Multiple Responses"          => "",
      "Options"                           => "",
      "Options Count"                     => "",
      "Allow to Specify Different Answer" => "no",
      "Field Description"                 => "",
      "Include for Mentor|Mentee"         => "yes",
      "Include in Profile"                => "no",
      "Include in Membership Form"        => "yes",
      "Visibility"                        => "everyone",
      "Editable by Admin Only"            => "no",
      "Mandatory"                         => "yes",
      "Show in Listing"                   => "yes",
      "Available for Search"              => "yes",
    }
  end

  def hash_to_stream(params)
    s = [params.keys.join(","), params.values.join(",")].join("\n")
    stubs_uploaded_file_read(s, s)
    return s
  end

  def import_stream(stream)
    res = ProfileQuestion::Importer.import_csv(stream, target_organization)
    target_organization.save
    res
  end

  def import_file(filename = 'profile_questions.csv')
    stream = fixture_file_upload(File.join('files', filename), 'text/csv')
    res = ProfileQuestion::Importer.import_csv(stream, target_organization)
    target_organization.save
    res
  end

  def import_file_for_new_organization(filename = 'profile_questions.csv')
    program = target_organization.programs.build(name: "new") do |p|
      p.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
      p.root = "new"
    end
    stream = fixture_file_upload(File.join('files', filename), 'text/csv')
    res = ProfileQuestion::Importer.import_csv(stream, target_organization, program)
    assert program.valid?
    puts program.errors.full_messages
    target_organization.save!
    res
  end
end
