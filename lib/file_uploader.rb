class FileUploader
  attr_reader :owner_id, :type_id, :file_name, :file_dir, :errors, :uniq_code, :options

  def initialize(type_id, owner_id, stream, options = {})
    @type_id = type_id
    @owner_id = owner_id
    @stream = stream
    @errors = []
    @options = options

    #Please pass max_file_size option while handling with LOGO, BANNER, MOBILE_LOGO
    @options[:max_file_size] ||= AttachmentSize::END_USER_ATTACHMENT_SIZE
  end

  def save
    @errors = []
    if is_valid_file?
      file = save_file
      unless ClamScanner.scan_file(file.path)
        @errors << 'feature.profile_question.file_uploader.errors.file_infected'.translate
        FileUtils.rm_rf(file.path)
      else
        ChronusS3Utils::S3Helper.store_in_s3(file, file_dir, file_name: file_name, skip_link_generation: true, content_type: MIME::Types.type_for(file_name)[0].try(:content_type))
      end
    else
      @errors << get_file_upload_errors
    end
    valid?
  end

  def valid?
    @errors.empty?
  end

  def path_to_file
    File.join(file_dir, file_name)
  end

  def self.get_file_path(type_id, owner_id, base_path, file_details)
    file_dir = get_directory(type_id, owner_id, file_details[:code], base_path)
    s3_object_key = File.join(file_dir, file_details[:file_name])
    s3_object = ChronusS3Utils::S3Helper.get_bucket(APP_CONFIG[:chronus_mentor_common_bucket]).objects[s3_object_key]
    return unless (s3_object.exists? rescue nil)
    file = write_to_file(s3_object, file_dir, file_details[:file_name])
    file.path
  end

  def self.uniq_code(type_id, owner_id)
    params = [Time.now.to_f, type_id, salt, owner_id].join('---')
    Digest::MD5.hexdigest(params)
  end

  def set_base_path_mode
    FileUtils.chmod_R(0777, @options[:base_path])
  end

  def self.get_file_upload_options(uploaded_class, options = {})
    case uploaded_class
      when ProgramAsset.name
        { base_path: "#{DROPZONE::TEMP_BASE_PATH}/#{ProgramAsset::TEMP_BASE_PATH}", max_file_size: ProgramAsset::MAX_SIZE[options[:program_asset_type].to_i] }
    end
  end

  private

  def self.salt
    SecureRandom.hex(16)
  end

  def self.get_directory(type_id, owner_id, code, base_path)
    File.join(base_path, type_id.to_s, owner_id.to_s, code.to_s)
  end

  def self.write_to_file(object, file_dir, file_name)
    file_dir = File.join(Rails.root, "tmp", file_dir)
    FileUtils.mkdir_p(file_dir, mode: 0777)
    file = File.open("#{file_dir}/#{file_name}", 'wb')
    file.write(object.read)
    file.close
    file
  end

  def save_file
    @file_name = @stream.original_filename
    @uniq_code = self.class.uniq_code(type_id, owner_id)
    @file_dir = self.class.get_directory(type_id, owner_id, uniq_code, @options[:base_path])
    self.class.write_to_file(@stream, file_dir, file_name)
  end

  def is_valid_file?
    is_valid_stream? && is_file_type_allowed? && @stream.size < @options[:max_file_size]
  end

  def is_file_type_allowed?
    DEFAULT_ALLOWED_FILE_UPLOAD_TYPES.include?(@stream.content_type) && (@stream.original_filename !~ DISALLOWED_FILE_EXTENSIONS)
  end

  def is_valid_stream?
    @stream && @stream.respond_to?(:read) && @stream.respond_to?(:original_filename)
  end

  def get_file_upload_errors
    get_type_and_size_erros || get_validity_errors
  end

  def get_type_and_size_erros
    return unless @stream.respond_to?(:content_type)

    if !is_file_type_allowed?
      'flash_message.profile_answer.file_attachment_invalid'.translate(file_list: (DEFAULT_ALLOWED_FILE_UPLOAD_TYPES))
    elsif (DEFAULT_ALLOWED_FILE_UPLOAD_TYPES.include?(@stream.content_type) && @stream.size > @options[:max_file_size])
      'flash_message.profile_answer.file_attachment_profile_answer_v1'.translate(file_size:  @options[:max_file_size]/ONE_MEGABYTE)
    end
  end

  def get_validity_errors
    if @stream.respond_to?(:original_filename) && (DISALLOWED_FILE_EXTENSIONS.match(@stream.original_filename))
       'flash_message.profile_answer.file_attachment_invalid'.translate
    else
      'feature.profile_question.file_uploader.errors.invalid_stream'.translate
    end
  end
end