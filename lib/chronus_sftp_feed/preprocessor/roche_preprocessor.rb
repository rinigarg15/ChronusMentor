module ChronusSftpFeed
  module Preprocessor

    class RochePreprocessor
      def self.pre_process(file, options = {})
        start_time = Time.now
        ChronusSftpFeed::Migrator.logger "Starting file pre-processing #{start_time}\n"
        csv_records = SmarterCSV.process(file, ChronusSftpFeed::Constant::CSV_OPTIONS.merge({:chunk_size => nil}))
        csv_records.each { |record_hash| record_hash.stringify_keys! }
        import_file = Tempfile.new(["#{options[:organization_name]}_import", ".csv"])
        CSV.open(import_file, 'a+') do |writer|
          writer << csv_records[0].keys
          csv_records.each do |record|
            writer << record.values
          end
        end
        ChronusSftpFeed::Migrator.logger "Total Time Taken in file preprocessing: #{((Time.now - start_time)/60).round(2)} minutes"
        import_file
      end
    end
  end
end
