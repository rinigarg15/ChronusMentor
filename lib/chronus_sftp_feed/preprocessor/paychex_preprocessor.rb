module ChronusSftpFeed
  module Preprocessor

    class PaychexPreprocessor

      HEADERS_TO_IGNORE = ["User Full Name", "Section Title", "Training Form Template Name", "Question", "Question User Response", "Submit Date"]

      class << self

        def pre_process(file_name, options = {})
          start_time = Time.now
          primary_key_field = "User Email"
          ChronusSftpFeed::Migrator.logger "Starting file pre-processing #{start_time}\n"
          csv_options = ChronusSftpFeed::Constant::CSV_OPTIONS.merge({chunk_size: nil, file_encoding: UTF8_BOM_ENCODING, strings_as_keys: true, row_sep: "\n"})
          @csv_records = SmarterCSV.process(file_name, csv_options)
          @csv_records = @csv_records.select { |record| record[primary_key_field].present? }
          csv_headers = get_csv_headers
          import_file = Tempfile.new(["#{options[:organization_name]}_import", ".csv"])
          CSV.open(import_file, 'a+') do |writer|
            writer << csv_headers
            records_grouped_by_email = @csv_records.group_by {|csv_record| csv_record[primary_key_field].downcase }
            records_grouped_by_email.each do |email, records|
              compact_record = compact_records(records)
              compact_record.merge!(get_first_and_last_names(compact_record["User Full Name"]))
              compact_record.merge!(get_question_response_hash(records))
              writer << csv_headers.collect {|csv_header| compact_record[csv_header] || ""}
            end
          end
          ChronusSftpFeed::Migrator.logger "Total Time Taken in file preprocessing: #{((Time.now - start_time)/60).round(2)} minutes"
          import_file
        end

        def get_csv_headers
          [ChronusSftpFeed::Constant::FIRST_NAME, ChronusSftpFeed::Constant::LAST_NAME] + @csv_records.first.keys + get_question_headers - HEADERS_TO_IGNORE
        end

        def get_question_headers
          @csv_records.collect { |record| record["Question"] }.uniq.select(&:present?)
        end

        def get_question_response_hash(records)
          question_response_hash = {}
          records.each {|record| question_response_hash[record["Question"]] ||= record["Question User Response"] if record["Question"].present?}
          question_response_hash
        end

        def get_first_and_last_names(full_name)
          last_name, first_name = full_name.split(",").map(&:strip)
          {ChronusSftpFeed::Constant::FIRST_NAME => first_name, ChronusSftpFeed::Constant::LAST_NAME => last_name}
        end

        def compact_records(records)
          compact_record = records.first.except("Question", "Question User Response")
          compact_record.each_pair do |column,value|
            compact_record[column] = records.collect {|record| record[column] }.find(&:present?) if value.blank?
          end
          compact_record
        end
      end
    end
  end
end