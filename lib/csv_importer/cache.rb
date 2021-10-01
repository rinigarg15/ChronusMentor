class CsvImporter::Cache
  class << self
    def write(user_csv_import, processed_rows)
      write_data(user_csv_import, processed_rows, CsvImporter::Constants::CACHE_KEY, CsvImporter::Constants::INDEXED_CACHE_KEY)
    end

    def read(user_csv_import)
      read_data(user_csv_import, CsvImporter::Constants::CACHE_KEY, CsvImporter::Constants::INDEXED_CACHE_KEY)
    end

    def delete(user_csv_import)
      delete_data(user_csv_import, CsvImporter::Constants::CACHE_KEY, CsvImporter::Constants::INDEXED_CACHE_KEY)
    end

    def write_failures(user_csv_import, processed_rows)
      write_data(user_csv_import, processed_rows, CsvImporter::Constants::FAILED_RECORDS_CACHE_KEY, CsvImporter::Constants::INDEXED_FAILED_RECORDS_CACHE_KEY)
    end

    def read_failures(user_csv_import)
      read_data(user_csv_import, CsvImporter::Constants::FAILED_RECORDS_CACHE_KEY, CsvImporter::Constants::INDEXED_FAILED_RECORDS_CACHE_KEY)
    end

    def delete_failures(user_csv_import)
      delete_data(user_csv_import, CsvImporter::Constants::FAILED_RECORDS_CACHE_KEY, CsvImporter::Constants::INDEXED_FAILED_RECORDS_CACHE_KEY)
    end

    private

    def write_data(user_csv_import, processed_rows, primary_key_proc, batch_key_proc)
      processed_rows_batches  = processed_rows.each_slice(CsvImporter::Constants::CACHE_BATCH_SIZE).to_a
      processed_rows_batches.each_with_index do |processed_rows_batch, index|
        Rails.cache.write(batch_key_proc.call(user_csv_import.id, index), processed_rows_batch, :time_to_live => CsvImporter::Constants::CACHE_TIME_TO_LIVE)
      end
      Rails.cache.write(primary_key_proc.call(user_csv_import.id), processed_rows_batches.size)
    end

    def read_data(user_csv_import, primary_key_proc, batch_key_proc)
      batches_size = Rails.cache.read(primary_key_proc.call(user_csv_import.id))
      return nil unless batches_size.present?
      processed_rows = []
      batches_size.times do |batch_no|
        processed_rows << Rails.cache.read(batch_key_proc.call(user_csv_import.id, batch_no)) || []
      end
      processed_rows.flatten
    end

    def delete_data(user_csv_import, primary_key_proc, batch_key_proc)
      batches_size = Rails.cache.read(primary_key_proc.call(user_csv_import.id))
      return unless batches_size.present?
      batches_size.times do |batch_no|
        Rails.cache.delete(batch_key_proc.call(user_csv_import.id, batch_no))
      end
      Rails.cache.delete(primary_key_proc.call(user_csv_import.id))
    end
  end
end