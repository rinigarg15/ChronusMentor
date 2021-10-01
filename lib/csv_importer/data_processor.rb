class CsvImporter::DataProcessor
  include CsvImporter::Utils
  attr_accessor :filename, :organization, :program, :column_mapping, :options, :result, :validator, :user_csv_import

  def initialize(user_csv_import, organization, options={})
    @user_csv_import = user_csv_import
    @filename = user_csv_import.local_csv_file_path
    @organization = organization
    @program = options[:program]
    @column_mapping = user_csv_import.csv_column_to_field_mapping
    @options = options
    validate_params
  end

  def process
    rows = SmarterCSV.process(filename, CsvImporter::Constants::CSV_OPTIONS.merge(key_mapping: column_mapping))
    remove_empty_rows(rows)
    raw_data_rows = SmarterCSV.process(filename, CsvImporter::Constants::CSV_OPTIONS.merge(keep_original_headers: true))
    remove_empty_rows(raw_data_rows)
    @validator = CsvImporter::Validator.new(organization, program, csv_emails_count(rows), csv_uuid_occurance_count(rows), options[:profile_questions])
    processed_rows = get_processed_rows(rows, raw_data_rows)
    CsvImporter::Cache.write(user_csv_import, processed_rows)
    compute_result(processed_rows)
  end

  private

  def suspended_member_emails
    @suspended_member_emails ||= downcase(organization.members.suspended.pluck(:email))
  end

  def all_member_emails
    @all_member_emails ||= downcase(organization.members.pluck(:email))
  end

  def all_user_emails
    @all_user_emails ||= downcase(organization.members.where(id: program.users.pluck(:member_id)).pluck(:email))
  end

  def program_level?
    program.present?
  end

  def cannot_add_organization_members?
    options[:cannot_add_organization_members]
  end

  def get_processed_rows(rows, raw_data_rows)
    processed_rows = []
    rows.each_with_index do |row, i|
      processed_rows << get_processed_information(row, raw_data_rows[i])
    end
    return processed_rows
  end

  def get_processed_information(row, raw_data_row)
    processed_row = CsvImporter::ProcessedRow.new(row, raw_data_row)
    role_names = program_level? ? get_role(row): nil
    processed_row.errors = get_errors(row, role_names)
    processed_row.is_suspended_member = is_suspended_member?(row)
    processed_row.user_to_be_updated = will_update_user?(row)
    processed_row.set_program_level_information(*get_program_level_information(row, role_names)) if program_level?
    return processed_row
  end

  def get_program_level_information(row, role_names)
    [get_state(row, role_names), will_invite_user?(row)]
  end

  def get_errors(row, role_names=nil)
    validator.validate_row(row, role_names)
  end

  def get_state(row, role_names)
    validator.all_mandatory_questions_answered?(row, role_names) ? User::Status::ACTIVE : User::Status::PENDING
  end

  def is_suspended_member?(row)
    suspended_member_emails.include?(email(row))
  end

  def will_invite_user?(row)
    cannot_add_organization_members? && all_member_emails.include?(email(row)) && !all_user_emails.include?(email(row))
  end

  def will_update_user?(row)
    program_level? ? all_user_emails.include?(email(row)) : all_member_emails.include?(email(row))
  end

  def validate_params
    raise "Where is the csv?" unless File.exist?(filename)
    raise "The file is not a csv" unless File.extname(filename) == ".csv"
  end

  def csv_emails_count(rows)
    all_records(rows, UserCsvImport::CsvMapColumns::EMAIL.to_sym)
  end

  def csv_uuid_occurance_count(rows)
    uuid_rows = rows.select { |row| row[UserCsvImport::CsvMapColumns::UUID.to_sym].present? }
    csv_uuids_emails_hash = uuid_rows.each_with_object({}) do |row, hash|
      uuid = row[UserCsvImport::CsvMapColumns::UUID.to_sym].downcase
      hash[uuid] ||= []
      hash[uuid] << row[UserCsvImport::CsvMapColumns::EMAIL.to_sym].to_s.downcase
    end

    custom_auth_config_ids = organization.get_and_cache_custom_auth_config_ids
    login_identifiers_scope = LoginIdentifier.joins(:member).select("members.email, login_identifiers.identifier").where(login_identifiers: { auth_config_id: custom_auth_config_ids } )
    member_uuids_emails_hash = login_identifiers_scope.each_with_object({}) { |obj, hash| hash[obj.identifier.downcase] = obj.email.downcase }

    counts_hash = {}
    csv_uuids_emails_hash.each do |uuid, emails|
      counts_hash[uuid] = (emails + [member_uuids_emails_hash[uuid]]).select(&:present?).uniq.count
    end
    counts_hash
  end

  def all_records(rows, column)
    rows.each_with_object(Hash.new(0)) { |row, counts| counts[row[column].to_s.downcase] += 1 }
  end

  def compute_result(processed_rows)
    result = {}
    result[:errors_count] = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :can_show_errors?).size
    result[:suspended_members] = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :is_suspended_member?).size
    result[:updated_users] = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :is_user_to_be_updated?).size
    result.merge!(program_level_result(processed_rows)) if program_level?
    result[:total_added] = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :is_user_to_be_added?).size
    result[:imported_users] = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :to_be_imported?).size
    return result
  end

  def program_level_result(processed_rows)
    program_level_result = {}
    program_level_result[:active_profiles] = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :active_profile?).size
    program_level_result[:pending_profiles] = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :pending_profile?).size
    program_level_result[:invited_users] = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :is_user_to_be_invited?).size
    return program_level_result
  end

  def remove_empty_rows(rows)
    rows.reject!{|row| row.values.all? {|col| !col.present?}}
  end
end