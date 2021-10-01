# == Schema Information
#
# Table name: user_csv_imports
#
#  id                      :integer          not null, primary key
#  member_id               :integer
#  program_id              :integer
#  info                    :text(65535)
#  local_csv_file_path     :string(255)
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  imported                :boolean
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#

class UserCsvImport < ActiveRecord::Base

  belongs_to_program_or_organization
  belongs_to :member
  has_many :progress_statuses, :as => :ref_obj, :dependent => :destroy

  has_attached_file :attachment, USER_CSV_STORAGE_OPTIONS

  validates_attachment_presence :attachment
  validates_attachment_size :attachment, less_than: AttachmentSize::ADMIN_ATTACHMENT_SIZE, :message => Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::ADMIN_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_attachment_content_type :attachment, :content_type => DEFAULT_ALLOWED_FILE_UPLOAD_TYPES
  validates_presence_of :program_id, :member_id

  scope :not_imported, -> { where("imported = 0 OR imported IS NULL")}

  PARENT_DIRECTORY_PATH = "/tmp/user_csv_import"
  PROFILE_QUESTION_COLUMN_KEY_SPLITTER = "_"

  module RoleOption
    SelectRoles = 'select_roles'
    MapRoles = 'map_roles'
  end

  module CsvMapColumns
    FIRST_NAME = 'first_name'
    LAST_NAME = 'last_name'
    EMAIL = 'email'
    ROLES = 'roles'
    PROFILE_QUESTION_COLUMN_KEY = Proc.new{|pq_id| "profile_question_#{pq_id}"}
    UUID = 'uuid'
    DONT_MAP = 'dont_map'

    def self.mandatory
      [FIRST_NAME, LAST_NAME, EMAIL]
    end

    def self.role_columns
      [ROLES]
    end

    def self.non_profile_columns
      [FIRST_NAME, LAST_NAME, EMAIL, ROLES, UUID, DONT_MAP]
    end
  end

  def self.save_csv_file(program, member, csv_stream)
    user_csv_import = program.user_csv_imports.new
    user_csv_import.member = member
    user_csv_import.attachment = csv_stream
    if csv_stream.present? && user_csv_import.save
      user_csv_import.local_csv_file_path = UserCsvImport.save_user_csv_to_be_imported(File.read(csv_stream.path, encoding: UTF8_BOM_ENCODING), csv_stream.original_filename, user_csv_import.id)
      valid_encoding = UserCsvImport.handle_file_encoding(user_csv_import.local_csv_file_path, user_csv_import.id)
    end

    return user_csv_import, valid_encoding
  end

  def self.handle_file_encoding(file_path, csv_import_id)
    local_csv_file_name = File.basename(file_path, ".*")
    temp_file_path = "#{Rails.root.to_s}#{UserCsvImport::PARENT_DIRECTORY_PATH}/#{csv_import_id.to_s}/#{local_csv_file_name}_tempfile.csv"
    f = File.open(temp_file_path, 'w+')
    f.close()
    File.chmod(0600, temp_file_path)
    from_encoding = `file -b --mime-encoding #{file_path}`.strip
    to_encoding = CsvImporter::Constants::FILE_ENCODING

    sampler = EncodingSampler::Sampler.new(file_path, [to_encoding])
    if sampler.valid_encodings.include? to_encoding
      system("rm -f #{temp_file_path}")
      return true
    elsif system("iconv -f #{from_encoding} -t #{to_encoding} #{file_path} -o #{temp_file_path}")
      system("mv -f #{temp_file_path} #{file_path}")
      return true
    else
      system("rm -f #{temp_file_path}")
      return false
    end
  end

  def self.save_user_csv_to_be_imported(csv_content, file_name, csv_import_id)
    dir_path = "#{Rails.root.to_s}#{UserCsvImport::PARENT_DIRECTORY_PATH}/#{csv_import_id.to_s}"
    begin
      FileUtils.mkdir_p(dir_path, mode: 0700)
      File.chmod(0700, dir_path)
      FileUtils.chown_R "app","app", dir_path unless Rails.env.development? || Rails.env.test?
    rescue => e
      message_1 = UserCsvImport.get_directory_permission_info("#{Rails.root.to_s}/tmp")
      message_2 = UserCsvImport.get_directory_permission_info("#{Rails.root.to_s}#{UserCsvImport::PARENT_DIRECTORY_PATH}")
      message_3 = UserCsvImport.get_directory_permission_info(dir_path)
      Airbrake.notify("Custom Message: #{message_1} | #{message_2} | #{message_3}")
      raise e
    end
    file_name = file_name.split(" ").join("_")
    full_file_path = "#{dir_path}/#{file_name}"
    outputFile = File.open(full_file_path, 'wb')
    File.chmod(0600, full_file_path)
    outputFile.write(csv_content)
    outputFile.close
    return full_file_path
  end

  def self.clean_up_user_csv_file(file_path)
    return unless file_path.present?
    dir = File.dirname(file_path)
    FileUtils.rm_rf(dir)
  end

  def self.column_key_dropdown_heading(key)
    if CsvMapColumns.non_profile_columns.include?(key)
      return "csv_import.import_user_csv_headers.#{key}".translate
    else
      pq_id = key.split(PROFILE_QUESTION_COLUMN_KEY_SPLITTER).last
      pq = ProfileQuestion.find_by(id: pq_id)
      return pq.question_text
    end
  end

  def self.get_directory_permission_info(dir_path)
    return Dir.exist?(dir_path) ? "#{dir_path}:#{"%o" % File.stat(dir_path).mode}" : "#{dir_path} do not exist"
  end

  def self.get_processed_saved_mapping(prev_import_mapping, user_csv_import_mapping, csv_column_headers, mandatory_column_keys)
    return {} unless prev_import_mapping.present? || user_csv_import_mapping.present?
    saved_mapping = user_csv_import_mapping
    saved_mapping = prev_import_mapping.clone if prev_import_mapping.present? && !saved_mapping.present?
    csv_column_headers.each do |header|
      saved_mapping[header] ||= ""
    end
    saved_mapping.reject!{|k,v| !csv_column_headers.include?(k)}
    saved_mapping = Hash[saved_mapping.sort_by{|k,v| csv_column_headers.index(k) + (mandatory_column_keys.include?(v) || v.blank? ? CsvImportsController::MAX_NUMBER : 0)}] unless user_csv_import_mapping.present?
    saved_mapping = {} if (mandatory_column_keys & saved_mapping.values) != mandatory_column_keys
    return saved_mapping
  end

  def local_csv_file_path
    old_local_file_path = read_attribute(:local_csv_file_path)
    if File.exists?(old_local_file_path)
      return old_local_file_path
    else
      csv_content = Paperclip.io_adapters.for(self.attachment).read
      new_local_file_path = UserCsvImport.save_user_csv_to_be_imported(csv_content, self.attachment_file_name, self.id)
      self.update_attribute(:local_csv_file_path, new_local_file_path)
      return new_local_file_path
    end
  end

  def get_header_and_key_mapping
    info_hash = self.info_hash
    csv_headers = self.csv_headers_for_dropdown
    return {} unless info_hash[:processed_params].present?
    csv_header_mapping_hash = {}
    info_hash[:processed_params].each do |dropdown_index, mapped_key|
      csv_header_mapping_hash[csv_headers[dropdown_index.to_i]] = mapped_key
    end
    return csv_header_mapping_hash
  end

  def save_mapping_params(csv_dropdown_choices, profile_dropdown_choices)
    info_hash = self.info_hash
    info_hash.merge!({:csv_dropdown_choices => csv_dropdown_choices, :profile_dropdown_choices => profile_dropdown_choices, :processed_params => process_params(csv_dropdown_choices, profile_dropdown_choices)})
    self.info = info_hash.to_yaml
    self.save
  end

  def save_processed_csv_import_params
    info_hash = self.info_hash
    info_hash.merge!({:processed_csv_import_params => self.get_header_and_key_mapping})
    self.info = info_hash.to_yaml
    self.save
  end

  def info_hash
    ActiveSupport::HashWithIndifferentAccess.new(YAML.load(self.info||""))
  end

  def update_or_save_role(roles)
    info_hash = self.info_hash
    info_hash.merge!({:roles => roles})
    self.info = info_hash.to_yaml
    self.save
  end

  def selected_roles
    self.info_hash[:roles] if self.info_hash[:roles].present?
  end

  def csv_content(options = {})
    options.reverse_merge!(CsvImporter::Constants::CSV_OPTIONS)
    SmarterCSV.process(self.local_csv_file_path, options)
  end

  def example_column_values
    sample_values_hash = {}
    csv_content = self.csv_content(keep_original_headers: true)
    return if csv_content.size == 0
    csv_headers = self.csv_headers_for_dropdown
    csv_headers.each_with_index do |header, index|
      first_row_val = h(csv_content[0][header].to_s)
      second_row_val = h(csv_content[1][header].to_s) if csv_content.size > 1
      sample_values_hash[(index).to_s] = first_row_val||second_row_val ? "csv_import.content.example".translate + [first_row_val, second_row_val].select(&:present?).join(", ") : ""
    end
    return sample_values_hash
  end

  def csv_headers_for_dropdown
    first_row = "\n"
    file = CSV.open(self.local_csv_file_path, 'r')
    while (first_row == "\n")
      first_row = file.readline
    end
    csv_headers = first_row.map{|word| word.to_s.strip}
    csv_headers.delete_if{|header| !header.present?}
  end

  def map_non_mandatory_columns_keys(roles, options = {})
    pqs = self.program.profile_questions_for_user_csv_import(roles)
    column_keys = pqs.map{ |pq| CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(pq.id) }

    column_keys << CsvMapColumns::UUID if options[:is_super_console]
    column_keys << CsvMapColumns::DONT_MAP
    return column_keys
  end

  def map_mandatory_column_keys(program_view, roles)
    column_keys = []
    column_keys += CsvMapColumns.mandatory
    column_keys += CsvMapColumns.role_columns if program_view && !roles.present?
    return column_keys
  end

  def original_csv_headers
    self.csv_headers_for_dropdown
  end

  def csv_headers_as_symbols
    self.csv_content.first.keys
  end

  def mapping_info
    info_hash[:processed_params]
  end

  def csv_column_to_field_mapping
    return {} unless mapping_info.present?
    csv_header_to_field_hash = {}
    csv_headers_as_symbols.each_with_index do |symbol, index|
      csv_header_to_field_hash[symbol] = mapping_info[index.to_s]
    end
    return csv_header_to_field_hash
  end

  def field_to_csv_column_mapping
    field_to_csv_header_map = {}
    headers_hash = self.csv_headers_as_symbols.inject({}){|hash, val| hash[val] = hash.size;hash}
    csv_column_to_field_mapping.each do |key, value|
      field_to_csv_header_map[value] = original_csv_headers[headers_hash[key]] if value != CsvMapColumns::DONT_MAP
    end
    return field_to_csv_header_map
  end

  def instruction_message_for_map_column(roles)
    pqs = self.program.profile_questions_for_user_csv_import(roles)
    available_question_types = pqs.collect(&:question_type).uniq & [ProfileQuestion::Type::EDUCATION, ProfileQuestion::Type::MULTI_EDUCATION, ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE, ProfileQuestion::Type::FILE, ProfileQuestion::Type::MANAGER, ProfileQuestion::Type::PUBLICATION, ProfileQuestion::Type::MULTI_PUBLICATION]

    profile_question_type_text = available_question_types.map{|type| "csv_import.content.profile_question_type_#{type}".translate}.uniq

    profile_question_type_text = profile_question_type_text.size > 1 ? (profile_question_type_text[0..-2].join(", ") + "csv_import.content.join_with_and".translate + profile_question_type_text[-1]) : profile_question_type_text[0]

    if available_question_types.size > 0
      "csv_import.content.map_user_columns_message_with_question_type_html".translate(:program => self.program.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase, :question_types_text => profile_question_type_text)
    else
      "csv_import.content.map_user_columns_message_html".translate(:program => self.program.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase)
    end
  end

  def profile_questions
    keys = self.mapping_info.values.reject!{|key| CsvMapColumns.non_profile_columns.include?(key)}
    ids = keys.map{|key| key.split(PROFILE_QUESTION_COLUMN_KEY_SPLITTER).last}
    ProfileQuestion.where(id: ids).includes(question_choices: :translations)
  end

  private

  def process_params(csv_dropdown_choices, profile_dropdown_choices)
    processed_hash = {}
    mandatory_keys = self.map_mandatory_column_keys(self.program.is_a?(Program), info_hash[:roles])
    csv_dropdown_choices.reject{|k,v| v=="select_a_column"}.each do |column_position_in_ui, csv_column_value|
      if column_position_in_ui.to_i < mandatory_keys.size
        processed_hash[csv_column_value] = mandatory_keys[column_position_in_ui.to_i]
      else
        processed_hash[csv_column_value] = profile_dropdown_choices[column_position_in_ui]
      end
    end

    return processed_hash
  end
end
