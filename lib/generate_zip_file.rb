module GenerateZipFile
  require 'zip/filesystem'
  require 'zip'
  # This makes a temporary file, converts it to zip format, and deletes the temporary file.
  # It does not leave the temporary file behind on the file system.
  # The filename here is the name of the original file
  def self.generate_zip_file(data, filename)
    zip_file_path = "/tmp/rubyzip-#{rand 32768}"
    zip_file = Zip::File.open(zip_file_path, Zip::File::CREATE)
    file_name = File.basename(filename)
    Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
      zipfile.file.open(file_name, "w") { |f| f.puts data }
    end
    return_data = open(zip_file_path).read
    File.delete(zip_file_path)
    return return_data
  end
end
