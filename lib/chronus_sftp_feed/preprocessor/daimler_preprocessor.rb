module ChronusSftpFeed
  module Preprocessor

    class DaimlerPreprocessor

      JOB_GRADE = {
        "C"   => "",
        "001" => "E1",
        "002" => "E2",
        "003" => "E3",
        "004" => "E4",
        "005" => "L5",
        "999" => "L6-L10",
        "Plant Worker" => "Plant Worker"
      }  
      LOCATION_MAP = {
        "US97208A"   => "Portland, OR, USA",
        "US48239A"   => "Detroit, IL, USA",
        "US2971569A" => "Gastonia, NC, USA",
        "US28052A"   => "Gastonia, NC, USA",
        "US27261A"   => "Thomas Built Buses, NC, USA",
        "US27013C"   => "Gastonia, NC, USA",
        "US29341A"   => "Gaffney, SC, USA ",
        "US97208B"   => "Portland, OR, USA",
        "US28120B"   => "Gastonia, NC, USA",
        "CAL5N7J7A"  => "Mississauga, Ontario, Canada",
        "US44707A"   => "Detroit, IL, USA",
        "CAT2E8L8A"  => "Calgary, AB, Canada",
        "US66801A"   => "Emporia, KS, USA",
        "US84074A"   => "Tooele, UT, USA",
        "US43723A"   => "Byesville, OH, USA",
        "US49512A"   => "Kentwood, MI, USA",
        "CAL5T2A7A"  => "Mississauga ON, Canada",
        "US97210D"   => "Portland, OR, USA",
        "US97210A"   => "Portland, OR, USA",
        "US97210C"   => "Portland, OR, USA",
        "US55746A"   => "Hibbing, MN, USA",
        "US48239B"   => "Detroit, IL, USA",
        "US28120A"   => "Gastonia, NC, USA"
      }

      class << self

        def pre_process(file, options = {})
          start_time = Time.now
          ChronusSftpFeed::Migrator.logger "Starting file pre-processing #{start_time}\n"
          csv_records = SmarterCSV.process(file, ChronusSftpFeed::Constant::CSV_OPTIONS.merge({:chunk_size => nil, :col_sep => "\;"}))
          csv_records.each { |record_hash| record_hash.stringify_keys! }
          import_file = Tempfile.new(["#{options[:organization_name]}_import", ".csv"])
          CSV.open(import_file, 'a+') do |writer|
            writer << csv_records[0].keys
            csv_records.each do |record|
              record["dcxManagementLevel"] = JOB_GRADE.keys.include?(record["dcxManagementLevel"]) ? JOB_GRADE[record["dcxManagementLevel"]] : record["dcxManagementLevel"]
              record["dcxLocationID"] = LOCATION_MAP.keys.include?(record["dcxLocationID"]) ? LOCATION_MAP[record["dcxLocationID"]] : record["dcxLocationID"]
              writer << record.values
            end
          end
          ChronusSftpFeed::Migrator.logger "Total Time Taken in file preprocessing: #{((Time.now - start_time)/60).round(2)} minutes"
          import_file
        end
      end
    end
  end
end