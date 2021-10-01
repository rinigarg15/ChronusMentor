class CsvImporter::GenerateCsv
  require "csv"

  class << self
    def for_data(processed_rows, user_csv_import, error_data)
      CSV.generate do |csv|
        csv << get_headers(user_csv_import, error_data)
        processed_rows.each do |processed_row|
          csv << get_row_data(processed_row, user_csv_import, error_data)
        end
      end
    end

    def get_headers(user_csv_import, error_data)
      headers = user_csv_import.original_csv_headers
      headers << "csv_import.content.csv_error_column".translate if error_data
      return headers
    end

    def get_row_data(processed_row, user_csv_import, error_data)
      row_data = processed_row.raw_data.values
      row_data << get_row_errors(processed_row, user_csv_import) if error_data
      return row_data
    end

    def get_row_errors(processed_row, user_csv_import)
      column_mapping = user_csv_import.field_to_csv_column_mapping
      processed_row.errors.map{|column_key, errors| "#{column_mapping[column_key.to_s]} #{errors.join(' ')}"}.join(" ")
    end
  end
end