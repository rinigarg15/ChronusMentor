module ChronusSftpFeed
  module Preprocessor

    class CokePreprocessor

      PUBLIC_KEY_FILE = "Coke_Chronus_Public_Key.asc"
      PRIVATE_KEY_FILE = "Coke_Chronus_Private_Key.asc"
      INT_DATA_COLUMN = "PersonNo"

      class << self
        include ChronusSftpFeed::DecryptFile

        def pre_process(file, options = {})
          file = decrypt_feed_data(file, PUBLIC_KEY_FILE, PRIVATE_KEY_FILE)  if options[:is_encrypted]
          # Fix: CSV::MalformedCSVError => Unclosed quoted field
          text = File.open(file, "r:ISO-8859-1").read.encode("UTF-8")
          rows = text.split("\n")
          CSV.open(file, "w") do |writer|
            headers = CSV.parse(rows[0].strip)[0]
            writer << headers
            # "PersonNo" column value should be converted to int after decryption
            int_column = headers.index(INT_DATA_COLUMN)
            rows[1..rows.size].each do |row|
              data = CSV.parse(row.strip)[0]
              data[int_column] = data[int_column].to_i.to_s if int_column.present? && data[int_column].present?
              writer << data
            end
          end
          file
        end
      end
    end

  end
end
