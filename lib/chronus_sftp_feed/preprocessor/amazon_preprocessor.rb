module ChronusSftpFeed
  module Preprocessor
    class AmazonPreprocessor

      PUBLIC_KEY_FILE = "amazon_chronus_public_key.asc"
      PRIVATE_KEY_FILE = "amazon_chronus_private_key.asc"

      class << self
        include ChronusSftpFeed::DecryptFile

        def pre_process(file, options = {})
          start_time = Time.now
          ChronusSftpFeed::Migrator.logger "Starting file pre-processing #{start_time}\n"
          import_file = decrypt_feed_data(file, PUBLIC_KEY_FILE, PRIVATE_KEY_FILE)  if options[:is_encrypted]
          ChronusSftpFeed::Migrator.logger "Total Time Taken in file preprocessing: #{((Time.now - start_time)/60).round(2)} minutes"
          import_file
        end
      end
    end
  end
end