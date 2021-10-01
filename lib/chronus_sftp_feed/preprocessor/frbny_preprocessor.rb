module ChronusSftpFeed
  module Preprocessor

    class FrbnyPreprocessor
      
      INT_DATA_LIST = ["Salary Grade"]     
      DATA_MERGE_HASH = { "Education" => ["College/School Name", "Degree", "Major", "Graduation"] }

      class << self
        
        def pre_process(file, options = {})
          start_time = Time.now
          ChronusSftpFeed::Migrator.logger "Starting file pre-processing #{start_time}\n"

          file = decrypt_feed_data(file) if options[:is_encrypted]
          csv_records = SmarterCSV.process(file, ChronusSftpFeed::Constant::CSV_OPTIONS.merge(:chunk_size => nil))
          uniq_record_map = csv_records.group_by{|x| x["Email"].try(:downcase)}
          import_file = Tempfile.new(["#{options[:organization_name]}_import", ".csv"])
          CSV.open(import_file, 'a+') do |writer|
            header = csv_records[0].keys + DATA_MERGE_HASH.keys - DATA_MERGE_HASH.values.flatten
            writer << header
            uniq_record_map.each do |email, records|
              records.each do |data|
                INT_DATA_LIST.each {|key| data[key] = data[key].to_i.to_s if data[key].present?}
              end
              data = records[0].slice(*header)
              DATA_MERGE_HASH.each_pair do |question_text, answer_sub_fields|
                data[question_text] = records.collect {|record| record.slice(*answer_sub_fields).values.join(",")}.join(ChronusSftpFeed::Constant::MULTIPLE_ANSWER_DELIMITER)
              end
              writer << data.values
            end
          end
          ChronusSftpFeed::Migrator.logger "Total Time Taken in file preprocessing: #{((Time.now - start_time)/60).round(2)} minutes"
          import_file
        end

        def decrypt_feed_data(file)
          output_path = get_output_path(file, true)
          output_file = get_output_path(file, false)
          system("7za e #{file} -pCHr0N_us! -o#{output_path}")
          system("gpg --import  #{output_path}/FRBChronusPub.key")
          system("gpg --allow-secret-key-import --import #{output_path}/FRBChronusSec.key")
          file_output = Time.now.utc.strftime('%Y%m%d%H%M%S') + "_output.txt"
          system("gpg --output #{output_path}/#{file_output} --decrypt #{output_path}/#{output_file}")
          return "#{output_path}/#{file_output}"
        end

        def get_output_path(file, path = true)
          arr = file.split("/")
          path ? arr.take(arr.size-1).join("/") : arr.last
        end
      end
    end

  end
end
