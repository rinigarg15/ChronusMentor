module ChronusSftpFeed
  module Preprocessor

    class BbvaPreprocessor
      
      PROFILE_QUESTIONS_MAP = {
        "FIRSTNAME" => "First Name",
        "LASTNAME" => "Last Name",
        "EMAIL" => "Email",
        "NETWORK_ID" => "Network ID",
        "JOB_TITLE" => "Job title",
        "DEPARTMENT" => "Department",
        "WORK_PHONE" => "Work phone",
        "WORK_CITY_AND_STATE" => "Work city and state",
        "ENUMBER_EMPLOYEECODE" => "enumber_employeeCode",
        "JOB_CODE" => "Job code",
        "ENTERPRISEDESC_DIV1" => "Line of Business",
        "ENTERPRISEDESC_DIV2" => "enterpriseDesc_div2",
        "ENTERPRISEDESC_DIV3" => "enterpriseDesc_div3",
        "ENTERPRISEDESC_DIV4" => "enterpriseDesc_div4",
        "HIRE_DATE" => "hire_date",
        "PROMOSTAT" => "PROMOSTAT"
      }
      IGNORE_MAILS = ["xxx@compass.com"]

      class << self

        def pre_process(file, options = {})
          start_time = Time.now
          puts "Starting file pre-processing #{start_time}\n"
          csv_records = SmarterCSV.process(file, ChronusSftpFeed::Constant::CSV_OPTIONS.merge(:key_mapping => PROFILE_QUESTIONS_MAP, :chunk_size => nil))
          csv_records.each { |record_hash| record_hash.stringify_keys! }
          select_records = csv_records.select{|x| !IGNORE_MAILS.include?(x["Email"])}
          import_file = Tempfile.new(["#{options[:organization_name]}_import", ".csv"])
          CSV.open(import_file, 'a+') do |writer|
            writer << select_records[0].keys
            select_records.each do |record|
              values = record.values.map{|value| value == "." ? "" : value}
              writer << values
            end
          end
          puts "Total Time Taken in file preprocessing: #{((Time.now - start_time)/60).round(2)} minutes"
          import_file       
        end
      end
    end
  end
end