module SolutionPack::ImporterUtils

  include SolutionPack::ExportImportCommonUtils

  def save_content_pack_to_be_imported(content_pack)
    content = content_pack.read
    name = content_pack.original_filename
    dir_path = "#{Rails.root.to_s}#{SolutionPack::PARENT_DIRECTORY_PATH}/#{rand(100000).to_s}"
    while Dir.exist?(dir_path) do
      dir_path = dir_path.rpartition('/').first + "_#{rand(10000).to_s}"
    end
    begin
      FileUtils.mkdir_p(dir_path, mode: 0777)
      File.chmod(0777, dir_path)
    rescue => e
      message_1 = SolutionPack.get_directory_permission_info("#{Rails.root.to_s}/tmp")
      message_2 = SolutionPack.get_directory_permission_info("#{Rails.root.to_s}#{SolutionPack::PARENT_DIRECTORY_PATH}")
      message_3 = SolutionPack.get_directory_permission_info(dir_path)
      Airbrake.notify("Custom Message: #{message_1} | #{message_2} | #{message_3}")
      raise e
    end
    full_file_path = "#{dir_path}/#{name}"
    outputFile = File.open(full_file_path, 'wb')
    outputFile.write(content)
    outputFile.close
    return full_file_path
  end

  def clean_up_solution_pack_file(file_path)
    dir = File.dirname(file_path)
    FileUtils.rm_rf(dir)
  end

  def import_solution_pack(program, options = {})
    solution_pack = program.solution_packs.new
    solution_pack.import(program.solution_pack_file, options)
    data_deleted = solution_pack.custom_errors.select {|error| error.type == SolutionPack::Error::TYPE::MentoringModel}.present?
    Airbrake.notify(StandardError.new("#{solution_pack.custom_errors.collect(&:errors).collect(&:full_messages).flatten}")) if data_deleted
    [solution_pack, data_deleted]
  end

  def handle_associated_attributes
  end

end