# == Schema Information
#
# Table name: solution_packs
#
#  id                      :integer          not null, primary key
#  description             :string(255)
#  program_id              :integer
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  created_by              :string(255)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#

class SolutionPack < ActiveRecord::Base

  attr_accessor :id_mappings, :base_directory_path, :parent_directory_path, :exported_ck_assets, :imported_ck_assets, :ckeditor_old_base_url, :all_ck_assets, :invalid_ck_assets_in, :metadata_hash, :ck_editor_column_names, :ck_editor_rows, :custom_errors, :sales_demo_mapper, :is_sales_demo
  # Error object
  class Error
    attr_reader :line, :errors, :type
    module TYPE
      MailerTemplate = 1
      MentoringModel = 2
      AdminViewColumn = 3
    end
    def initialize(type, errors)
      @type = type
      @errors = errors
    end
  end
  # errors indicator
  def custom_errors
    @custom_errors ||= []
  end
  # error message
  def custom_errors_messages
    @custom_errors.map do |e|
      %{#{e.errors.full_messages.join(", ")}}
    end
  end

  def reset_custom_errors
    @custom_errors = []
  end

  PARENT_DIRECTORY_PATH = "/tmp/solution_pack"
  METADATA_FILE_NAME = "metadata.json"
  CHILD_DIRECTORIES = [:ckeditor, :post_attachment]

  belongs_to_program

  has_attached_file :attachment, SOLUTION_PACK_STORAGE_OPTIONS

  validates_attachment_presence :attachment
  validates_attachment_size :attachment, less_than: AttachmentSize::ADMIN_ATTACHMENT_SIZE, :message => Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::ADMIN_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_attachment_content_type :attachment, :content_type => DEFAULT_ALLOWED_COMPRESSED_FILE_TYPES
  validates_presence_of :program_id, :created_by, :description

  default_scope -> { order('created_at DESC') }

  def import(zip_file_path, options = {})
    new_dir_name = self.initialize_solution_pack_for_import(zip_file_path)
    SolutionPack::ExportImportCommonUtils.unzip_file(zip_file_path, new_dir_name)
    ckeditor_file_path = base_directory_path+CkeditorAssetExporter::FileName+".csv"
    self.read_metadata
    handle_ck_editor_files(ckeditor_file_path)
    ProgramImporter.new(self, options).import
    Airbrake.notify(StandardError.new("Solution Pack import successful with error for program with id = #{self.program_id}. #{self.custom_errors_messages.join(', ')}")) if self.custom_errors.present?
    FileUtils.rm zip_file_path
    FileUtils.rm_rf self.base_directory_path
    File.open(options[:dump_location], "w"){|f| f.write(self.id_mappings.to_yaml)} if options[:dump_location]
  end

  def export(options = {})
    self.initialize_solution_pack_for_export(options)
    ProgramExporter.new(self.program, self, options).export
    self.write_metadata
    zip_file_path = SolutionPack::ExportImportCommonUtils.zip_all_files_in_dir(base_path)
    return zip_file_path if options[:return_zip_file].present?
    unless is_sales_demo
      self.attachment = File.open(zip_file_path)
      self.save!
      FileUtils.rm zip_file_path
    else
      FileUtils.mv zip_file_path, options[:target_location]
    end
    FileUtils.rm_rf base_path
  end

  def initialize_solution_pack_for_export(options = {})
    reset_custom_errors
    self.metadata_hash = {}
    self.exported_ck_assets = []
    self.all_ck_assets = Ckeditor::Asset.where(program_id: self.program.organization.id)
    self.initialize_base_path
    self.create_directories(options)
    self.metadata_hash[:ckeditor] = {assets_base_url: "#{program.organization.url}"}
  end

  def initialize_solution_pack_for_import(zip_file_path)
    reset_custom_errors
    self.imported_ck_assets = {}
    self.initialize_base_path(zip_file_path)
  end

  def initialize_base_path(zip_file_path=nil)
    self.parent_directory_path = zip_file_path.present? ? File.dirname(zip_file_path) : "#{Rails.root.to_s}#{PARENT_DIRECTORY_PATH}"
    new_dir_name = zip_file_path.nil? ? "SolutionPack_#{Time.now.to_i.to_s}_#{rand(10000).to_s}" : "#{File.basename(zip_file_path, '.zip')}_#{rand(10000).to_s}"
    self.base_directory_path = "#{self.parent_directory_path}/#{new_dir_name}/"
    new_dir_name
  end

  def base_path
    "#{self.base_directory_path}"
  end

  def metadata_file_path
    "#{base_path}#{METADATA_FILE_NAME}"
  end

  SolutionPack::CHILD_DIRECTORIES.each do |folder|
    define_method "#{folder}_base_path" do |*args|
      "#{base_path}#{folder}/"
    end
  end

  def write_metadata
    File.open(self.metadata_file_path,"wb") do |f|
      f.write(self.metadata_hash.to_json)
    end
  end

  def read_metadata
    self.metadata_hash = {}
    return unless File.exists?(self.metadata_file_path)
    file = File.read(self.metadata_file_path)
    self.metadata_hash = ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(file))
  end

  def create_directories(options = {})
    begin
      permission = 0777
      SolutionPack.create_if_not_exist_with_permission(self.parent_directory_path, permission)
      SolutionPack.create_if_not_exist_with_permission(self.base_path, permission)
      SolutionPack.create_if_not_exist_with_permission(self.ckeditor_base_path, permission) if self.is_sales_demo
      SolutionPack.create_if_not_exist_with_permission(self.post_attachment_base_path, permission) unless options[:skip_post_attachment]
    rescue => e
      message_1 = SolutionPack.get_directory_permission_info("#{Rails.root.to_s}/tmp")
      message_2 = SolutionPack.get_directory_permission_info(self.parent_directory_path)
      message_3 = SolutionPack.get_directory_permission_info(self.base_path)
      message_4 = SolutionPack.get_directory_permission_info(self.ckeditor_base_path)
      message_5 = SolutionPack.get_directory_permission_info(self.post_attachment_base_path)
      Airbrake.notify("Custom Message: #{message_1} | #{message_2} | #{message_3} | #{message_4} | #{message_5}")
      raise e
    end
  end

  def self.get_directory_permission_info(dir_path)
    return Dir.exist?(dir_path) ? "#{dir_path}:#{"%o" % File.stat(dir_path).mode}" : "#{dir_path} do not exist"
  end

  def self.create_if_not_exist_with_permission(dir_path, permission)
    unless Dir.exist?(dir_path)
      Dir.mkdir(dir_path, permission)
    end
    File.chmod(permission, dir_path)
  end

  private

  def handle_ck_editor_files(ckeditor_file_path)
    if File.exist?(ckeditor_file_path)
      ck_editor_rows_with_column_names = CSV.read(ckeditor_file_path)
      self.ck_editor_column_names = ck_editor_rows_with_column_names[0]
      self.ck_editor_rows = ck_editor_rows_with_column_names[1..-1]
      self.ckeditor_old_base_url = self.metadata_hash[:ckeditor].try(:[], :assets_base_url)
    end
  end
end