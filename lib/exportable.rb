module Exportable
  extend ActiveSupport::Concern

  module ClassMethods
    def export_to_csv(file_path, *columns)
      columns = column_names if columns.empty?
      CSV.open(file_path, "w") do |csv|
        csv << columns
        select(columns).all.find_each(batch_size: 10000) do |activity|
          csv << columns.map{ |column| activity.send(column) }
        end
      end
    end
  end
end