module CsvImporter::Constants
  CHUNK_SIZE = 1
  FILE_ENCODING = 'UTF-8'
  ROW_SEPARATOR = :auto
  CSV_OPTIONS = {
    file_encoding: FILE_ENCODING,
    row_sep: ROW_SEPARATOR,
    remove_empty_values: false,
    remove_zero_values: false,
    convert_values_to_numeric: false
  }
  CACHE_KEY = Proc.new{|key| "csv-importer-validation-#{key}"}
  INDEXED_CACHE_KEY = Proc.new{|key, index| "csv-importer-validation-#{key}-#{index}"}
  FAILED_RECORDS_CACHE_KEY = Proc.new{|key| "csv-importer-failed-#{key}"}
  INDEXED_FAILED_RECORDS_CACHE_KEY = Proc.new{|key, index| "csv-importer-failed-#{key}-#{index}"}
  CACHE_TIME_TO_LIVE = 1.hour
  CACHE_BATCH_SIZE = 25
  PROGRESS_BATCH_SIZE = 25
end