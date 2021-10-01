module Matching
  # The abstract base class for the data types used by matching.
  class AbstractType
    #
    # Converts the object to type that are stored in MySQL representation.
    #
    def self.to_mysql_type(instance)
      # Return if the instance is already in the marshalled form.
      return instance unless instance.is_a?(self)

      # Construct a 2 item array with the following entries
      #   * class name of the data type (ChronusString, etc.,)
      #   * marshalled data returned by the sub class's +get_marshalled_data+.
      [instance.class.name, instance.class.get_marshalled_data(instance)]
    end

    #
    # Create AbstractType object from value(data_fields fetched from MySQL).
    #
    def self.from_mysql_type(db_value)
      return db_value if db_value.is_a?(self)

      # +marthalled_value+ will be a 2 item array with marthalled_value[0] containing the
      # actual data type sub-class name and marthalled_value[1], the marshalled data.
      #
      # Call +create_object_from_marshalled_data+ on the sub class to construct the actual object back.
      db_value[0].constantize.create_object_from_marshalled_data(db_value[1])
    end

    # Asserts that val1 is of self type, and invokes do_match
    #
    # If the either of the fields or fields' values is nil, returns default
    # weight of EMPTY_WEIGHT.
    #
    # Params:
    # *<tt>other_field</tt> - another <code>AbstractType<code> to compare with;
    # typically that of a student.
    #
    def match(other_field, options = {})
      (self.no_data? || other_field.no_data?) ? Matching::EMPTY_WEIGHT : do_match(other_field, options)
    end

    # Returns a match compatibility value in the range (0..1) for the two
    # values.
    #
    # To be implemented by the sub classes.
    def do_match(other_field, options = {})
      # This method is just a stub. The custom field type classes *must*
      # implement this method
      raise NotImplementedError
    end

    # Returns the internal value of this type.
    def value
      raise NotImplementedError
    end

    # Returns whether the internal value is empty.
    def no_data?
      raise NotImplementedError
    end

    def set_matching(map_to_choices, map_from_choices, options = {})
      matching_hash = options[:matching_details]
      return Matching::EMPTY_WEIGHT if map_from_choices.empty? || map_to_choices.empty?
      can_be_matched_choices = [map_from_choices].flatten.flat_map{|choice| matching_hash[choice]}
      common_values = can_be_matched_choices.flatten & map_to_choices
      score = compute_set_matching_score(common_values, can_be_matched_choices)
      return common_values_with_score_hash(common_values, matching_hash, score) if options[:get_common_data]
      return score
    end

    protected

    def common_values_with_score_hash(common_values, matching_hash, score)
      student_common_values = matching_hash.keys.select{ |key| (matching_hash[key].try(:flatten) & common_values).present? }
      {score: score, common_values: common_values, student_common_values: student_common_values}
    end

    # Score is computed based on among all the sets available for mentor and mentee choices, in how many sets match is found.
    def compute_set_matching_score(common_values, can_be_matched_choices)
      matched_sets_count = can_be_matched_choices.count { |match_set| (Array(match_set).compact & common_values).any? }
      (matched_sets_count.to_f/can_be_matched_choices.size).round(2)
    end

    def string_array_distance(string, array, options = {})
      return Matching::EMPTY_WEIGHT if array.empty? || string.blank?
      common_values = array.select{|ele| (string =~ /\b#{ele}\b/).present?}
      score = common_values.size/array.size.to_f
      get_score_or_hash(score, options.merge(common_values: common_values))
    end

    def string_ordered_array_distance(string, ordered_array, options = {})
      return Matching::EMPTY_WEIGHT if ordered_array.empty? || string.blank?
      ordered_array.each_with_index do |element, index|
        if (string =~ /\b#{element}\b/).present?
          score = 1/(index+1).to_f
          return get_score_or_hash(score, options.merge(common_values: [element]))
        end
      end
      return 0.0
    end

    # Computes the textual distance between the given two arrays.
    def array_distance(arr1, arr2, options = {})
      return Matching::EMPTY_WEIGHT if arr1.empty? || arr2.empty?

      # Ignore duplicates, case and remove white spaces.      

      # Values common between both the arrays.
      common_values = (arr1 & arr2)
      common_values_size = common_values.size

      # Fraction of arr1 that is matching.
      val1_match = common_values_size / arr1.size.to_f

      # Fraction of arr2 that is matching.
      val2_match = common_values_size / arr2.size.to_f

      # Consider the following cases
      #
      #   val1    | val2
      #   ----------------
      #   [a,b,c] | [a,b,c]
      #   [a,b,c] | [a,b,c,d]
      #   [a,b,c] | [a,b,c,d,e]
      #
      # Here, #1 is a better match than #2 since val2 has exactly what val1 is
      # looking for, hence relatively better than val2. Similar argument appies
      # to #2 and #3. So, the differentiating factor here is the val2 match with
      # val1, which is nothing but our val2_match.
      # So, use val1_match as the primary value and add val2_match to it in such
      # a way that it will help us differentiate the above mentioned cases.
      #
      # We assign a higher weight to val1_match compared to val2_match.
      # It might turn out that for some cases, the coefficient 10 is not
      # sufficient enough for val1_match to get higher precedence than val2_match
      # and we are ignoring such cases.
      #
      score = (val2_match * 10 + val1_match) / 11.0
      get_score_or_hash(score, options.merge(common_values: common_values))
    end

    # Computes the textual distance between the given array and ordered array.
    def array_ordered_array_distance(arr1, arr2, base_arr_index, options = {})
      #arr2 is the value of the mentee field
      #arr1 is the value of the mentor field

      return Matching::EMPTY_WEIGHT if arr1.empty? || arr2.empty?

      #base_arr is the value of the array that should be treated as base either arr1 or arr2
      base_arr, other_arr = base_arr_index == 0 ? [arr1, arr2] : [arr2, arr1]

      # Ignore duplicates, case and remove white spaces.

      # Consider the following cases
      #
      #   val2    | val1
      #   ----------------
      #   [a,b,c] | [a,b]
      #   [a,b,c] | [b,a]
      #   [a,b,c] | [a]
      #
      # Here, #1 and #2 get equal preference since they have top two priorities of
      # val2 in other order. Since val1 is not an ordered one, they both have value
      # which val2 has in his top two preferences. #3 gets the lesser score here
      # because it has only the first preference of val2
      score = 0.0
      common_values = []
      other_arr.each do |element|
        base_arr_index = base_arr.index(element)
        score = score + 1/(base_arr_index+1).to_f if base_arr_index.present?
        common_values << element if (options[:get_common_data] && base_arr_index.present?)
      end

      max_score = 0.0
      #Max score is always considered with respect to mentee field
      arr2.each_with_index do |element, index|
        max_score = max_score + 1/(index+1).to_f
      end
      new_score = score/max_score.to_f
      get_score_or_hash(new_score, options.merge(common_values: common_values))
    end

    # Computes the textual distance between the given two ordered arrays.
    def ordered_array_distance(arr1, arr2, options = {})
      #arr2 is the value of the viewing mentee(current user)
      #arr1 is the mentor with whom match happens

      return Matching::EMPTY_WEIGHT if arr1.empty? || arr2.empty?

      # Convert val2 to array form.
      arr2 = [arr2].flatten

      # Ignore duplicates, case and remove white spaces.
      score = 0.0
      max_score = 0.0
      common_values = []

      # Consider the following cases
      #
      #   val2    | val1
      #   ----------------
      #   [a,b,c] | [a,b,c]
      #   [a,b,c] | [a,b]
      #   [a,b,c] | [a,c,b]
      #
      # Here, #1 is a better match than #2 since val1 has exactly what val2 is
      # looking.  #2 and #3 will get the same score here. Since #2 has first two
      # same but #3 has all 3 preferences but #2 and #3 and interchanged priority
      arr2.each_with_index do |val2_element, val2_index|
        val1_index = arr1.index(val2_element)
        score = score + 1/((val1_index+val2_index)/2.to_f+1).to_f if val1_index.present?
        common_values << val2_element if (options[:get_common_data] && val1_index.present?)
        max_score = max_score + 1/(val2_index+1).to_f
	    end

      final_score = score/max_score.to_f
      get_score_or_hash(final_score, options.merge(common_values: common_values))
    end

    # A very rudimentary comparison that returns match in terms of the number of
    # common words in the two values.
    #
    # TODO: Use Yahoo! Keyword search?
    #
    def text_distance(text1, text2, options = {})
      return Matching::EMPTY_WEIGHT if text1.nil? || text2.nil?

      # Convert text2 to a string from Array if required.
      text_1_parts = text1.split(/\s+/).uniq
      text_2_parts = text2.split(/\s+/).uniq
      array_distance(text_1_parts, text_2_parts, options)
    end

    def get_score_or_hash(score, options = {})
      options[:get_common_data] ? {score: score, common_values: options[:common_values]} : score
    end
  end
end
