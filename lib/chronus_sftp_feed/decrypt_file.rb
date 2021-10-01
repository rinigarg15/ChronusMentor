module ChronusSftpFeed
  module DecryptFile
    private
    def decrypt_feed_data(file, public_key_file, private_key_file)
      output_path = get_output_path(file, true)
      output_file = get_output_path(file, false)
      system("gpg --import  #{output_path}/#{public_key_file}")
      system("gpg --allow-secret-key-import --import #{output_path}/#{private_key_file}")
      file_output = Time.now.utc.strftime('%Y%m%d%H%M%S') + "_output.csv"
      system("gpg --output #{output_path}/#{file_output} --decrypt #{output_path}/#{output_file}")
      return "#{output_path}/#{file_output}"
    end

    def get_output_path(file, path = true)
      arr = file.split("/")
      path ? arr.take(arr.size-1).join("/") : arr.last
    end
  end
end