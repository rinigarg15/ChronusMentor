module SolutionPack::ExportImportCommonUtils

  def self.zip_all_files_in_dir(path)
    path.sub!(%r[/$],'')
    archive = File.join(File.dirname(path), File.basename(path))+'.zip'

    Zip::File.open(archive, 'w') do |zipfile|
      Dir["#{path}/**/**"].each do |file|
        zipfile.add(file.sub(path+'/',''),file)
      end
    end
    return archive
  end

  def self.unzip_file(file_path, new_dir_name=nil)
    dir_path = File.dirname(file_path)
    new_dir_name = new_dir_name.present? ? new_dir_name : File.basename(file_path, ".zip")
    new_dir_path = File.join(dir_path, new_dir_name)
    unencrypted_file_path = file_path

    SolutionPack.create_if_not_exist_with_permission(new_dir_path, 0777)
    Zip::File.open(unencrypted_file_path) do |zip_file|
      zip_file.each do |f|
        f_path=File.join(new_dir_path, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        File.chmod(0777, File.dirname(f_path))
        zip_file.extract(f, f_path) unless File.exist?(f_path)
      end
    end
    return new_dir_path
  end
end