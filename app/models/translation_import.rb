class TranslationImport < ActiveRecord::Base

  belongs_to_program_or_organization
  has_attached_file :attachment

  validates_attachment_presence :attachment
  validates_attachment_size :attachment, less_than: AttachmentSize::ADMIN_ATTACHMENT_SIZE, :message => Proc.new { "flash_message.message.file_attachment_too_big".translate(AttachmentSize::ADMIN_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_attachment_content_type :attachment, :content_type => DEFAULT_ALLOWED_FILE_UPLOAD_TYPES
  validates_presence_of :program_id

  PARENT_DIRECTORY_PATH = "/tmp/translation_import"

  module ErrorOption
    Interpolation_key_error = 0
    HTML_tag_error = 1
    ErrorStatements = {
      Interpolation_key_error => "interpolation_key",
      HTML_tag_error => "html_tag"
    }
  end

  def self.save_csv_file(program, csv_stream)
    translation_import = program.translation_imports.new
    translation_import.attachment = csv_stream
    if csv_stream.present? && translation_import.save
      translation_import.local_csv_file_path = TranslationImport.save_translation_csv_to_be_imported(CSV.read(csv_stream.path), csv_stream.original_filename, translation_import.id)
      valid_encoding = TranslationImport.handle_file_encoding(translation_import.local_csv_file_path, translation_import.id)
    end
    return translation_import, valid_encoding
  end

  def self.handle_file_encoding(file_path, translation_id)
    local_csv_file_name = File.basename(file_path, ".*")
    temp_file_path = "#{Rails.root.to_s}#{TranslationImport::PARENT_DIRECTORY_PATH}/#{translation_id.to_s}/#{local_csv_file_name}_tempfile.csv"
    f = File.open(temp_file_path, 'w+')
    f.close()
    File.chmod(0600, temp_file_path)
    from_encoding = `file -b --mime-encoding #{file_path}`.strip
    to_encoding = CsvImporter::Constants::FILE_ENCODING
    
    sampler = EncodingSampler::Sampler.new(file_path, [to_encoding])
    if sampler.valid_encodings.include? to_encoding
      FileUtils.rm temp_file_path, force: true
      return true
    elsif system("iconv -f #{from_encoding} -t #{to_encoding} #{file_path} -o #{temp_file_path}")
      FileUtils.mv temp_file_path, file_path, force: true
      return true
    else
      FileUtils.rm temp_file_path, force: true
      return false
    end
  end

  def self.save_translation_csv_to_be_imported(csv_content, file_name, translation_id)
    dir_path = "#{Rails.root.to_s}#{TranslationImport::PARENT_DIRECTORY_PATH}/#{translation_id.to_s}"
    begin
      FileUtils.mkdir_p(dir_path, mode: 0700)
      File.chmod(0700, dir_path)
      FileUtils.chown_R "app","app", dir_path unless Rails.env.development? || Rails.env.test?
    rescue => e
      message_1 = TranslationImport.get_directory_permission_info("#{Rails.root.to_s}/tmp")
      message_2 = TranslationImport.get_directory_permission_info("#{Rails.root.to_s}#{TranslationImport::PARENT_DIRECTORY_PATH}")
      message_3 = TranslationImport.get_directory_permission_info(dir_path)
      Airbrake.notify("Custom Message: #{message_1} | #{message_2} | #{message_3}")
      raise e
    end
    file_name = file_name.split(" ").join("_")
    full_file_path = "#{dir_path}/#{file_name}"
    CSV.open(full_file_path, "w:utf-8") do |csv|
      csv_content.each do |attribute|
        csv << attribute
      end
    end
    return full_file_path
  end

  def self.get_directory_permission_info(dir_path)
    return Dir.exist?(dir_path) ? "#{dir_path}:#{"%o" % File.stat(dir_path).mode}" : "#{dir_path} do not exist"
  end

end
