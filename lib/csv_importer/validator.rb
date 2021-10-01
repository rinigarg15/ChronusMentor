class CsvImporter::Validator
  extend ActiveModel::Naming
  include EmailFormatCheck
  include Authentication
  include DateTranslationHelper

  attr_accessor :organization, :program, :errors, :required_profile_question_role_mapping, :roles, :csv_emails_occurance_count, :csv_uuid_occurance_count, :mapped_profile_questions

  def initialize(organization, program, csv_emails_occurance_count, csv_uuid_occurance_count, mapped_profile_questions)
    @organization = organization
    @program = program
    @errors = ActiveModel::Errors.new(self)
    set_variables(csv_emails_occurance_count, csv_uuid_occurance_count, mapped_profile_questions)
    set_program_variables if program.present?
  end

  def validate_row(row, role_names=nil)
    validate_email(row)
    validate_first_and_last_name(row)
    validate_profile_answers(row)
    validate_role(role_names) if program.present?
    validate_uuid(row)
    return get_and_clear_errors
  end

  def all_mandatory_questions_answered?(row, role_names)
    role_names.all? do |role_name|
      required_question_ids = required_profile_question_role_mapping[role_name].to_a
      required_question_ids.all? do |id|
        row[UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(id).to_sym].present?
      end
    end
  end

  def get_and_clear_errors
    row_errors = errors.to_hash
    errors.clear
    row_errors
  end

  def validate_email(row)
    email = row[UserCsvImport::CsvMapColumns::EMAIL.to_sym].to_s.downcase
    errors.add(UserCsvImport::CsvMapColumns::EMAIL.to_sym, "csv_import.errors.missing_field".translate) and return unless email.present?
    check_email_uniqueness(email)
    validate_format_of_email(email)
    check_email_of_allowed_domain(email)
  end

  def validate_first_and_last_name(row)
    [UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym, UserCsvImport::CsvMapColumns::LAST_NAME.to_sym].each do |key|
      errors.add(key, "csv_import.errors.missing_field".translate) and next unless row[key].present?
      errors.add(key, "csv_import.errors.name.invalid".translate) unless valid_name?(row[key])
    end
  end

  def validate_profile_answers(row)
    mapped_profile_questions.each do |pq|
      ans = row[UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(pq.id).to_sym]
      next unless ans.present?
      check_profile_answer_based_on_question_type(ans, pq)
    end
  end

  def validate_role(role_names)
    valid_roles = true
    errors.add(UserCsvImport::CsvMapColumns::ROLES.to_sym, "csv_import.errors.missing_field".translate) and return unless role_names.present?
    role_names.each do |role_name|
      valid_roles &= roles.include?(role_name)
    end
    errors.add(UserCsvImport::CsvMapColumns::ROLES.to_sym, "csv_import.errors.role.invalid_v1".translate) unless valid_roles
  end

  def validate_uuid(row)
    errors.add(UserCsvImport::CsvMapColumns::UUID.to_sym, "csv_import.errors.uuid.not_unique".translate) if row[UserCsvImport::CsvMapColumns::UUID.to_sym].present? && csv_uuid_occurance_count[row[UserCsvImport::CsvMapColumns::UUID.to_sym].downcase] > 1
  end

  def read_attribute_for_validation(attr)
    send(attr)
  end

  private

  def check_email_uniqueness(email)
    errors.add(UserCsvImport::CsvMapColumns::EMAIL.to_sym, "csv_import.errors.email.not_unique".translate) if csv_emails_occurance_count[email] > 1
  end

  def check_profile_answer_based_on_question_type(ans, pq)
    check_if_answer_is_valid(ans, pq) if pq.choice_or_select_type? && !pq.allow_other_option?
    check_text_only_answer(ans, pq) if pq.text_only_allowed?
    check_date_only_answer(ans, pq)  if pq.date?
  end

  def validate_format_of_email(email)
    errors.add(UserCsvImport::CsvMapColumns::EMAIL.to_sym, "csv_import.errors.email.invalid_format".translate) if ValidatesEmailFormatOf::validate_email_format(email, check_mx: true)
  end

  def check_email_of_allowed_domain(email)
    security_setting = organization.security_setting
    validate_email_format(true, email, security_setting)
  end

  def valid_name?(name)
    (name =~ RegexConstants::RE_NO_NUMBERS) && name.length < 100
  end

  def check_if_answer_is_valid(answer, profile_question)
    answer = answer.split_by_comma(profile_question.single_option_choice_based?)
    errors.add(UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(profile_question.id).to_sym, "csv_import.errors.profile_answer.invalid_choice_v2".translate) if (answer - profile_question.default_choices).present?
  end

  def check_text_only_answer(answer, profile_question)
    errors.add(UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(profile_question.id).to_sym, "csv_import.errors.profile_answer.text_only".translate) if answer =~ /\d/
  end

  def check_date_only_answer(answer, profile_question)
    ans_text = get_datetime_str_in_en(answer)
    errors.add(UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(profile_question.id).to_sym, "csv_import.errors.profile_answer.invalid_date".translate) unless (valid_date?(ans_text) || ans_text.blank?) 
  end

  def set_variables(csv_emails_occurance_count, csv_uuid_occurance_count, mapped_profile_questions)
    @csv_emails_occurance_count = csv_emails_occurance_count
    @csv_uuid_occurance_count = csv_uuid_occurance_count
    @mapped_profile_questions = mapped_profile_questions
  end

  def set_program_variables
    set_required_profile_question_role_mapping
    set_program_roles
  end

  def set_required_profile_question_role_mapping
    @required_profile_question_role_mapping = {}
    program.roles.non_administrative.each do |role|
      @required_profile_question_role_mapping[role.name] = program.required_profile_questions_except_default_for([role.name]).collect(&:id)
    end
  end

  def set_program_roles
    @roles = program.roles.pluck(:name)
  end
end