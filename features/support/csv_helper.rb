require "csv"

module CSVHelper

  def verify_headers_for_csv(fields, file)
    csv = CSV.read(file, headers: true, encoding: UTF8_BOM_ENCODING)
    headers = csv.to_a[0]
    fields = fields.split(",")
    assert(headers.sort == fields.uniq.sort)
  end

  def verify_value_for_column(value, column, file)
    CSV.foreach(file, headers: true, encoding: UTF8_BOM_ENCODING) do |csv|
      assert_not_nil(csv[column])
      assert(csv[column].include?(value), "mismatch found expected #{value} but #{csv[column]}")
    end
  end

  def verify_atleast_one_value_for_column(values, column, file)
    values.each do |value|
      value.gsub! /"/,''
    end
    CSV.foreach(file, headers: true, encoding: UTF8_BOM_ENCODING) do |csv|
      assert_not_nil(csv[column])
      assert(values.any?{|s| csv[column].include?(s)},"mismatch #{csv[column]} contains none of the expected values")
    end
  end

  def verify_match_row(values, file)
    CSV.foreach(file, headers: true, encoding: UTF8_BOM_ENCODING) do |csv|
      match = false
      values.each_pair { |key,value|
        assert(csv[key].include?(value), "not matching value found")
      }
    end
  end

  def verify_column_contains(value, column, file)
    match = false
    CSV.foreach(file, headers: true, encoding: UTF8_BOM_ENCODING) do |csv|
      if(csv[column].include?(value))
        match = true
      end
    end
    assert(match,"no such value #{value} under #{column}")
  end
end

World(CSVHelper)