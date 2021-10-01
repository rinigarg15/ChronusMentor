require_relative './../../../test_helper'

class CsvImporter::ValidatorTest < ActiveSupport::TestCase
  def setup
    super
    @organization = programs(:org_primary)
    @program = programs(:albers)
    @csv_emails_occurance_count = {"email1@example.com" => 1, "email2@example.com" => 2, "email3@example.com" => 1, "email4@gmail.com" => 1, "badformat@1" => 1, "invaliddomain@chronus123somethingthatdoesntexist.com" => 1}
    @csv_uuid_occurance_count = {"uuid1" => 1, "uuid2" => 2}
  end

  def test_validate_row
    row = "Something"
    v = CsvImporter::Validator.new(@organization, nil, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    v.stubs(:validate_email).with(row).once
    v.stubs(:validate_first_and_last_name).with(row).once
    v.stubs(:validate_profile_answers).with(row).once
    v.stubs(:validate_uuid).with(row).once
    v.stubs(:validate_role).never
    v.stubs(:get_and_clear_errors).once.returns("something else")
    assert_equal "something else", v.validate_row(row)

    v1 = CsvImporter::Validator.new(@organization, @program, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    v1.stubs(:validate_email).with(row).once
    v1.stubs(:validate_first_and_last_name).with(row).once
    v1.stubs(:validate_profile_answers).with(row).once
    v1.stubs(:validate_uuid).with(row).once
    v1.stubs(:validate_role).with("role names").once
    v1.stubs(:get_and_clear_errors).once.returns("something else")
    assert_equal "something else", v1.validate_row(row, "role names")
  end

  def test_validate_email
    v = CsvImporter::Validator.new(@organization, @program, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    row = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => ""}
    v.validate_email(row)
    assert_equal ["csv_import.errors.missing_field".translate], v.errors[UserCsvImport::CsvMapColumns::EMAIL.to_sym]
    v.errors.clear

    row = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1@example.com"}
    v.validate_email(row)
    assert_false v.errors.present?

    #Uniqueness
    row = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email2@example.com"}
    v.validate_email(row)
    assert_equal ["csv_import.errors.email.not_unique".translate], v.errors[UserCsvImport::CsvMapColumns::EMAIL.to_sym]
    v.errors.clear

    row = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "EmAil2@Example.com"}
    v.validate_email(row)
    assert_equal ["csv_import.errors.email.not_unique".translate], v.errors[UserCsvImport::CsvMapColumns::EMAIL.to_sym]
    v.errors.clear

    #Format and domain
    row = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "badformat@1"}
    v.validate_email(row)
    assert_equal ["csv_import.errors.email.invalid_format".translate], v.errors[UserCsvImport::CsvMapColumns::EMAIL.to_sym]
    v.errors.clear

    row = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "invaliddomain@chronus123somethingthatdoesntexist.com"}
    v.validate_email(row)
    assert_equal ["csv_import.errors.email.invalid_format".translate], v.errors[UserCsvImport::CsvMapColumns::EMAIL.to_sym]
    v.errors.clear

    #Security Setting
    ss = @organization.security_setting
    ss.email_domain = "gmail.com"
    ss.save
    v = CsvImporter::Validator.new(@organization.reload, @program, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    row = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email1@example.com"}
    v.validate_email(row)
    assert_equal ["flash_message.password_flash.invalid_email_domain".translate(email_domain: "gmail.com")], v.errors[UserCsvImport::CsvMapColumns::EMAIL.to_sym]
    v.errors.clear

    row = {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "email4@gmail.com"}
    v.validate_email(row)
    assert_false v.errors.present?
  end

  def test_validate_first_and_last_name
    v = CsvImporter::Validator.new(@organization, @program, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    v.validate_first_and_last_name({UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "", UserCsvImport::CsvMapColumns::LAST_NAME.to_sym => ""})
    assert_equal ["csv_import.errors.missing_field".translate], v.errors[UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym]
    assert_equal ["csv_import.errors.missing_field".translate], v.errors[UserCsvImport::CsvMapColumns::LAST_NAME.to_sym]
    v.errors.clear

    row = {UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "Some", UserCsvImport::CsvMapColumns::LAST_NAME.to_sym => "Name"}
    v.validate_first_and_last_name(row)
    assert_false v.errors.present?

    row = {UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "Some1", UserCsvImport::CsvMapColumns::LAST_NAME.to_sym => "Name"}
    v.validate_first_and_last_name(row)
    assert_equal ["csv_import.errors.name.invalid".translate], v.errors[UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym]
    assert_false v.errors[UserCsvImport::CsvMapColumns::LAST_NAME.to_sym].present?
    v.errors.clear

    row = {UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "Some", UserCsvImport::CsvMapColumns::LAST_NAME.to_sym => "Nameaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
    v.validate_first_and_last_name(row)
    assert_equal ["csv_import.errors.name.invalid".translate], v.errors[UserCsvImport::CsvMapColumns::LAST_NAME.to_sym]
    assert_false v.errors[UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym].present?
    v.errors.clear

    row = {UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym => "Some1", UserCsvImport::CsvMapColumns::LAST_NAME.to_sym => "Name2"}
    v.validate_first_and_last_name(row)
    assert_equal ["csv_import.errors.name.invalid".translate], v.errors[UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym]
    assert_equal ["csv_import.errors.name.invalid".translate], v.errors[UserCsvImport::CsvMapColumns::LAST_NAME.to_sym]
    v.errors.clear
  end

  def test_validate_profile_answers
    pq1 = profile_questions(:profile_questions_9)
    assert pq1.choice_based?
    pq1.question_choices.create!(text: "Choice, with, comma")
    pq2 = profile_questions(:profile_questions_10)
    assert pq2.choice_based?
    pq2.update_attribute(:allow_other_option, true)
    pq3 = profile_questions(:profile_questions_4)
    pq3.update_attribute(:text_only_option, true)
    date_question = profile_questions(:date_question)
    assert pq3.text_type?
    assert pq3.text_only_allowed?
    ordered_options_question = create_question(question_choices: ["A","B" ,"C"], question_type: ProfileQuestion::Type::ORDERED_OPTIONS, options_count: 1)
    ordered_options_question.question_choices.create!(text: "Choice, with, ordered comma")

    assert ordered_options_question.ordered_options_type?

    v = CsvImporter::Validator.new(@organization, @program, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    suffix = UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call('')

    row = {}
    v.validate_profile_answers(row)
    assert_false v.errors.present?

    row = {"#{suffix}#{pq1.id}".to_sym => "", "#{suffix}#{pq2.id}".to_sym => "", "#{suffix}#{pq3.id}".to_sym => "", "#{suffix}#{date_question.id}".to_sym => ""}
    v.validate_profile_answers(row)
    assert_false v.errors.present?

    row = {"#{suffix}#{pq1.id}".to_sym => "Choice, with, comma", "#{suffix}#{pq2.id}".to_sym => "Accounting", "#{suffix}#{pq3.id}".to_sym => "Only text", "#{suffix}#{ordered_options_question.id}".to_sym => "'Choice, with, ordered comma'", "#{suffix}#{date_question.id}".to_sym => "23 June, 2018"}
    v.validate_profile_answers(row)
    assert_false v.errors.present?

    row = { "#{suffix}#{pq1.id}".to_sym => "Something that is not an option", "#{suffix}#{pq2.id}".to_sym => "Something that is not an option", "#{suffix}#{pq3.id}".to_sym => "Not only text 1", "#{suffix}#{ordered_options_question.id}".to_sym => "Something that is not an option", "#{suffix}#{date_question.id}".to_sym => "hello" }
    v.validate_profile_answers(row)
    assert_equal ["contains invalid choice(s)."], v.errors["#{suffix}#{pq1.id}".to_sym]
    assert_false v.errors["#{suffix}#{pq2.id}".to_sym].present?
    assert_equal ["only text allowed."], v.errors["#{suffix}#{pq3.id}".to_sym]
    assert_equal ["contains invalid choice(s)."], v.errors["#{suffix}#{ordered_options_question.id}".to_sym]
    assert_equal ["contains invalid date"], v.errors["#{suffix}#{date_question.id}".to_sym]
  end

  def test_validate_role
    v = CsvImporter::Validator.new(@organization, @program, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    v.validate_role([])
    assert_equal ["csv_import.errors.missing_field".translate], v.errors[UserCsvImport::CsvMapColumns::ROLES.to_sym]
    v.errors.clear

    v.validate_role([RoleConstants::MENTOR_NAME])
    assert_false v.errors.present?

    v.validate_role([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert_false v.errors.present?

    v.validate_role([RoleConstants::MENTOR_NAME, "something"])
    assert_equal ["csv_import.errors.role.invalid_v1".translate], v.errors[UserCsvImport::CsvMapColumns::ROLES.to_sym]
    v.errors.clear

    @program.roles.create!(:name => "something")
    v = CsvImporter::Validator.new(@organization, @program.reload, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    v.validate_role([RoleConstants::MENTOR_NAME, "something"])
    assert_false v.errors.present?
  end

  def test_validate_uuid
    row = {}
    v = CsvImporter::Validator.new(@organization, @program, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    v.validate_uuid(row)
    assert_false v.errors.present?

    row = {UserCsvImport::CsvMapColumns::UUID.to_sym => "uuid1"}
    v.validate_uuid(row)
    assert_false v.errors.present?

    row = {UserCsvImport::CsvMapColumns::UUID.to_sym => "uuid2"}
    v.validate_uuid(row)
    assert_equal ["csv_import.errors.uuid.not_unique".translate], v.errors[UserCsvImport::CsvMapColumns::UUID.to_sym]
  end

  def test_get_and_clear_errors
    v = CsvImporter::Validator.new(@organization, @program, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    v.errors.add(:something, "Something Else")
    v.errors.add(:nothing, "Nothing Else 1")
    v.errors.add(:nothing, "Nothing Else 2")
    assert v.errors.present?
    errors = {:something => ["Something Else"], :nothing => ["Nothing Else 1", "Nothing Else 2"]}
    assert_equal errors, v.get_and_clear_errors
    assert_false v.errors.present?
  end

  def test_all_mandatory_questions_answered
    assert @program.required_profile_questions_except_default_for([RoleConstants::MENTOR_NAME]).empty?
    v = CsvImporter::Validator.new(@organization, @program, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    row = {}
    assert v.all_mandatory_questions_answered?(row, [RoleConstants::MENTOR_NAME])

    rq1 = @program.role_questions_for([RoleConstants::MENTOR_NAME]).role_profile_questions.includes(:profile_question => :translations).find { |q| q.profile_question.non_default_type? }
    rq1.required = true
    rq1.save!

    v = CsvImporter::Validator.new(@organization, @program.reload, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    assert_false v.all_mandatory_questions_answered?(row, [RoleConstants::MENTOR_NAME])

    row[UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(rq1.profile_question_id).to_sym] = "something"
    assert v.all_mandatory_questions_answered?(row, [RoleConstants::MENTOR_NAME])

    rq2 = @program.role_questions_for([RoleConstants::STUDENT_NAME]).role_profile_questions.includes(:profile_question => :translations).select { |q| q.profile_question.non_default_type?}.last
    rq2.required = true
    rq2.save!
    v = CsvImporter::Validator.new(@organization, @program.reload, @csv_emails_occurance_count, @csv_uuid_occurance_count, @organization.profile_questions)
    assert v.all_mandatory_questions_answered?(row, [RoleConstants::MENTOR_NAME])
    assert_false v.all_mandatory_questions_answered?(row, [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])

    row[UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(rq2.profile_question_id).to_sym] = "something else"
    assert v.all_mandatory_questions_answered?(row, [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
  end
end