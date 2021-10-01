class Array
  # Computes the numeric average of all the values in the arrray.
  def average
    # Return 0.0 if array is empty so as to avoid Divide by Zero
    self.empty? ? 0.0 : (self.sum.to_f) / self.size
  end

  # Join the array elements by the given separator
  # For example: ["a", "b", "c"] => "a,b,c"
  #  ["a", "b,c", "d"] => "a,'b,c',d"
  # ["a", "'b,c'", "d"] => "a,'\'b,c,d\''"
  def join_by_separator(separator = COMMON_SEPARATOR)
    joined_string = ""
    self.each_with_index do |item, index|
      item.strip!
      joined_string << enclose_item_by_quotes(item)
      joined_string << separator if index != self.size-1
    end
    joined_string
  end

  # To sort arrays with translated texts.
  def sort_translated_contents
    self.sort_by{|item| I18n.transliterate(item.to_s).downcase }
  end

  private
  def enclose_item_by_quotes(item)
    unless item.index(COMMA_SEPARATOR).nil?
      if item[0] == "'" && item[-1] == "'"
        "'\\'#{item[1..-2]}\\''"
      else
        "'#{item}'"
      end
    else
      item
    end
  end
end

class String

  def shellescape
    # An empty argument will be skipped, so return empty quotes.
    return "''" if self.empty?

    str = self.dup

    # Process as a single byte sequence because not all shell
    # implementations are multibyte aware.
    str.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/n, "\\\\\\1")

    # A LF cannot be escaped with a backslash because a backslash + LF
    # combo is regarded as line continuation and simply ignored.
    str.gsub!(/\n/, "'\n'")

    return str
  end

  def regex_scan?(regex, case_insensitive = false)
    formatted_regex = Regexp.new(regex, case_insensitive)
    self.force_encoding("UTF-8").scan(formatted_regex).present?
  end

  def to_boolean
    self.downcase == 'true'
  end

  # Poor man's version of adding an article to a word.
  def articleize
    first_char = self.first
    is_vowel = %w(a e i o u).include?(first_char.downcase)
    is_vowel ? "an #{self}" : "a #{self}"
  end

  # Remove HTML tags from the given string - http://snippets.dzone.com/posts/show/3689
  def strip_html
    self.gsub(/<\/?[^>]*>/, "")
  end

  # Capitalize only first char in a string. String#capitalize downcases every other char in the string
  def capitalize_only_first_char
    # String#first returns the first char of the string
    # String#from(n) returns string[1..-1]
    self.first.capitalize + self.from(1)
  end

  # Converts to a string that can be used as HTML id. Replaces all spaces
  # and underscores the string.
  def to_html_id
    self.capitalize.downcase.underscore.gsub(/[\s,:,\/,\']/, '_')
  end

  def remove_braces_and_downcase
    self.gsub(/\[|\]|\)|\(/i, '').strip.downcase
  end

  def term
    self
  end

  def term_downcase
    UnicodeUtils.downcase(self)
  end

  def term_titleize
    UnicodeUtils.titlecase(self)
  end

  def pluralized_term
    self.pluralize
  end

  def pluralized_term_downcase
    UnicodeUtils.downcase(self).pluralize
  end

  def articleized_term
    self.articleize
  end

  def articleized_term_downcase
    UnicodeUtils.downcase(self).articleize
  end

  def format_for_mysql_query(options = {})
    string_to_escape = options[:delimit_with_percent] ? "%%".insert(1, self) : self
    ActiveRecord::Base.connection.quote(string_to_escape)
  end

  def constantize_only(allowed_strings)
    allowed_strings.include?(self) ? self.constantize : raise(Authorization::PermissionDenied.new("Tried to constantize unsafe string #{self}"))
  end

  # Split the given choices string by commas. If the choice itself has comma,
  # then enclose the choice in single quotes.
  # Note: enclosed single quotes will be removed while saving the choice.
  # If the choice needs to be saved with enclosed single_quotes, then pass the choice by escaping the quotes.
  # For example: "a,b,c" => ["a", "b", "c"]
  # "a,'b,c',d" => ["a", "b,c", "d"]
  # "a,'\'b,c,d\''" => ["a", "'b,c'", "d"]
  def split_by_comma(single_choice_based = false)
    return Array(self).map(&:strip).reject(&:blank?) if single_choice_based

    str = ""
    quotes_begin = false
    result_arr = []
    (self.length).times do |i|
      if self[i] == COMMA_SEPARATOR && !quotes_begin
        result_arr << str
        str = ""
      elsif self[i] == "'"
        str, quotes_begin = check_string_enclosed_in_quotes(str, quotes_begin, self, i)
      elsif self[i] == "\\" && self[i + 1] == "'"
        next
      else
        str << self[i]
      end
    end
    result_arr << str
    result_arr.map(&:strip).reject(&:blank?)
  end

  private

  def check_string_enclosed_in_quotes(str, quotes_begin, answer_texts, index)
    if !quotes_begin && str.blank? && answer_texts[index-1] != "\\"
      quotes_begin = true
    elsif quotes_begin && str.present? && answer_texts[index-1] != "\\"
      quotes_begin = false
    else
      str << answer_texts[index]
    end
    [str, quotes_begin]
  end

end

class Hash
  # This method will do the normal Hash#slice functionality only, 
  # Did not remove this method for backward compatibility
  def pick(*keys)
    self.slice(*keys)
  end
end

class Range
  def intersection(other)
    raise ArgumentError, 'value must be a Range' unless other.kind_of?(Range)

    my_min, my_max = first, exclude_end? ? max : last
    other_min, other_max = other.first, other.exclude_end? ? other.max : other.last

    new_min = self.cover?(other_min) ? other_min : other.cover?(my_min) ? my_min : nil
    new_max = self.cover?(other_max) ? other_max : other.cover?(my_max) ? my_max : nil

    new_min && new_max ? new_min..new_max : nil
  end
  alias_method :&, :intersection
end

class ActiveSupport::TimeWithZone
  def get_week_of_month
    self.week_split[0][self.wday].nil? ? (self.week_of_month - 1) : self.week_of_month
  end
end

class Object
  def set_instance_variable_within_block_and_reset(instance_variable_name, value)
    initial_value = instance_variable_get :"@#{instance_variable_name}"
    instance_variable_set :"@#{instance_variable_name}", value
    return_value = yield
    instance_variable_set :"@#{instance_variable_name}", initial_value
    return_value
  end

  def send_only(method, allowed_methods, *args)
    allowed_methods.map(&:to_sym).include?(method.to_sym) ? send(method, *args) : raise(Authorization::PermissionDenied.new("Tried to call restricted method #{method} via send"))
  end
end