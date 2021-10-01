module DateTranslationHelper

  def get_datetime_str_in_en(datetime_str)
    datetime_str = datetime_str.to_s
    "date.month_names_array".translate.each_with_index {|month, i| datetime_str.gsub!(month, "date.month_names_array".translate(locale: :en)[i])}
    datetime_str
  end

  def valid_date?(date_string, options = {})
    date = Date.parse(date_string.to_s)
    date.present? ? (options[:get_date] ? date : true) : false
  rescue ArgumentError
    false
  end
end
  
