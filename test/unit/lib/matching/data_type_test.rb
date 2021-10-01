require_relative './../../../test_helper'

class DataTypeTest < ActiveSupport::TestCase
  class DummyCollectionType < Matching::CollectionType
    def field_weights
      {'field_1' => 0.35, 'field_2' => 0.3, 'field_3' => 0.9}
    end
  end

  def test_chronus_array
    chr_arr_1 = Matching::ChronusArray.new([])
    chr_arr_2 = Matching::ChronusArray.new(['a','b','c','d','e'])

    assert_equal Matching::EMPTY_WEIGHT, chr_arr_1.do_match(chr_arr_2)

    chr_arr_1 = Matching::ChronusArray.new(['a','b','c'])
    chr_arr_2 = Matching::ChronusArray.new([])
    assert_equal Matching::EMPTY_WEIGHT, chr_arr_1.do_match(chr_arr_2)

    chr_arr_1 = Matching::ChronusArray.new('a')
    chr_arr_2 = Matching::ChronusArray.new('a')
    assert_equal 1.0, chr_arr_1.do_match(chr_arr_2)

    chr_arr_1 = Matching::ChronusArray.new([])
    chr_arr_2 = Matching::ChronusArray.new([])
    assert_equal Matching::EMPTY_WEIGHT, chr_arr_1.do_match(chr_arr_2)

    chr_arr_1 = Matching::ChronusArray.new(['b', 'a'])
    chr_arr_2 = Matching::ChronusArray.new(['x', 'y', 'm'])
    assert_equal 0.0, chr_arr_1.do_match(chr_arr_2)

    chr_arr_1 = Matching::ChronusArray.new(['a', 'b', 'c', 'd', 'e'])
    chr_arr_2 = Matching::ChronusArray.new(['b', 'a'])
    assert_equal 0.95, chr_arr_1.do_match(chr_arr_2).round(2)

    chr_arr_1 = Matching::ChronusArray.new(['a', 'b', 'c', 'd', 'e'])
    chr_arr_2 = Matching::ChronusArray.new(['b', 'a'])
    result = chr_arr_1.do_match(chr_arr_2, get_common_data: true)
    assert result.is_a?(Hash)
    assert_equal 0.95, result[:score].round(2)
    assert_equal_unordered ["a", "b"], result[:common_values]

    chr_arr_1 = Matching::ChronusArray.new(['b', 'a'])
    chr_arr_2 = Matching::ChronusArray.new(['a', 'b', 'c', 'd', 'e'])
    assert_equal 1 / 2.2, chr_arr_1.do_match(chr_arr_2)

    chr_arr_1 = Matching::ChronusArray.new(['d','e','c','b','a'])
    chr_arr_2 = Matching::ChronusArray.new(['a','b','c','d','e'])
    assert_equal 1.0, chr_arr_1.do_match(chr_arr_2)

    chr_arr_1 = Matching::ChronusArray.new(['b','a'])
    chr_arr_2 = Matching::ChronusArray.new(['d','c'])
    assert_equal 0, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a"]], "b" => [["b"]], "c" => [["c"]], "d" => [["d"]]}})
    assert_equal 0, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["c", "d"]], "d" => [["d"]]}})
    assert_equal 0.5, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["c", "d"]], "d" => [["d", "a"]]}})
    assert_equal 1, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["c", "b"]], "d" => [["d", "a"]]}})
    assert_equal 0.5, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["c", "d"]], "d" => [["d", "a", "b"]]}})
    assert_equal 0, chr_arr_1.do_match(Matching::ChronusArray.new([]),  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["c", "d"]], "d" => [["d"]]}})

    chr_arr_1 = Matching::ChronusArray.new(['b','a'])
    chr_arr_2 = Matching::ChronusOrderedArray.new(['d','c'])
    assert_equal 0, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a"]], "b" => [["b"]], "c" => [["c"]], "d" => [["d"]]}})
    assert_equal 0, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["c", "d"]], "d" => [["d"]]}})
    assert_equal 0.5, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["c", "d"]], "d" => [["d", "a"]]}})
    assert_equal 0.5, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["c", "d"]], "d" => [["d", "a", "b"]]}})
    assert_equal 0, chr_arr_1.do_match(Matching::ChronusOrderedArray.new([]),  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["c", "d"]], "d" => [["d"]]}})
    result = chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["c", "d"]], "d" => [["d", "a", "b"]]}, get_common_data: true})
    assert_equal_unordered ["a", "b"], result[:common_values]
    assert_equal_unordered ["a", "b", "d"], result[:student_common_values]

    chr_arr_1 = Matching::ChronusArray.new(['b','a'])
    chr_arr_2 = Matching::ChronusString.new("c")
    assert_equal 0, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a"]], "b" => [["b"]], "c" => [["c"]]}})
    assert_equal 1, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["a", "b"]]}})
    assert_equal 1, chr_arr_1.do_match(chr_arr_2,  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["b"]]}})
    assert_equal 0, chr_arr_1.do_match(Matching::ChronusString.new(""),  {:matching_details => {"a" => [["a", "b"]], "b" => [["b", "c"]], "c" => [["b"]]}})
  end

  def test_to_mysql_type
    chr_arr_1 = Matching::ChronusArray.new(['a', 'b', 'c', 'd', 'e'])
    assert_equal ["Matching::ChronusArray", ["a", "b", "c", "d", "e"]], Matching::AbstractType.to_mysql_type(chr_arr_1)
    
    chr_string_1 = Matching::ChronusString.new("super")
    assert_equal ["Matching::ChronusString", "super"], Matching::AbstractType.to_mysql_type(chr_string_1)
    
    chr_text_1 = Matching::ChronusArray.new(["personality development"])
    assert_equal ["Matching::ChronusArray", ["personality development"]], Matching::AbstractType.to_mysql_type(chr_text_1)
    
    chr_text_1 = Matching::ChronusText.new("india is a great country")
    assert_equal ["Matching::ChronusText", "india is a great country"], Matching::AbstractType.to_mysql_type(chr_text_1)
    
    chr_text_1 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    assert_equal ["Matching::ChronusOrderedArray", ["project management", "personality development"]], Matching::AbstractType.to_mysql_type(chr_text_1)
    
    loc_1 = locations(:chennai)
    chr_location_1 = Matching::ChronusLocation.new([loc_1.lat, loc_1.lng])
    assert_equal ["Matching::ChronusLocation", [13.0604, 80.2496]], Matching::AbstractType.to_mysql_type(chr_location_1)

    chr_mgr_1 = Matching::ChronusMisMatch.new([1,3,4,5])
    assert_equal ["Matching::ChronusMisMatch", [1, 3, 4, 5]], Matching::AbstractType.to_mysql_type(chr_mgr_1) 

    data_1 = DummyCollectionType.new(
      [{:field_1 => 'Man', :field_2 => 'World', :field_3 => 'Monkey'}]
    )
    assert_equal ["DataTypeTest::DummyCollectionType", [{:field_1=>"Man", :field_2=>"World", :field_3=>"Monkey"}]], Matching::AbstractType.to_mysql_type(data_1)
  end

  def test_from_mysql_type
    chr_arr_1 = Matching::ChronusArray.new(['a', 'b', 'c', 'd', 'e'])
    to_sql_type = Matching::AbstractType.to_mysql_type(chr_arr_1)
    assert_equal chr_arr_1.class, Matching::AbstractType.from_mysql_type(to_sql_type).class

    chr_arr_1 = Matching::ChronusString.new("super")
    to_sql_type = Matching::AbstractType.to_mysql_type(chr_arr_1)
    assert_equal chr_arr_1.class, Matching::AbstractType.from_mysql_type(to_sql_type).class

    chr_arr_1 = Matching::ChronusArray.new(["personality development"])
    to_sql_type = Matching::AbstractType.to_mysql_type(chr_arr_1)
    assert_equal chr_arr_1.class, Matching::AbstractType.from_mysql_type(to_sql_type).class

    chr_arr_1 =  Matching::ChronusText.new("india is a great country")
    to_sql_type = Matching::AbstractType.to_mysql_type(chr_arr_1)
    assert_equal chr_arr_1.class, Matching::AbstractType.from_mysql_type(to_sql_type).class

    chr_arr_1 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    to_sql_type = Matching::AbstractType.to_mysql_type(chr_arr_1)
    assert_equal chr_arr_1.class, Matching::AbstractType.from_mysql_type(to_sql_type).class

    loc_1 = locations(:chennai)
    chr_arr_1 = Matching::ChronusLocation.new([loc_1.lat, loc_1.lng])
    to_sql_type = Matching::AbstractType.to_mysql_type(chr_arr_1)
    assert_equal chr_arr_1.class, Matching::AbstractType.from_mysql_type(to_sql_type).class

    chr_arr_1 = Matching::ChronusMisMatch.new([1,3,4,5])
    to_sql_type = Matching::AbstractType.to_mysql_type(chr_arr_1)
    assert_equal chr_arr_1.class, Matching::AbstractType.from_mysql_type(to_sql_type).class

    chr_arr_1 = DummyCollectionType.new(
      [{:field_1 => 'Man', :field_2 => 'World', :field_3 => 'Monkey'}]
    )
    to_sql_type = Matching::AbstractType.to_mysql_type(chr_arr_1)
    assert_equal chr_arr_1.class, Matching::AbstractType.from_mysql_type(to_sql_type).class
  end

  def test_chronus_string
    chr_string_1 = Matching::ChronusString.new("super")
    chr_string_2 = Matching::ChronusString.new("better")
    assert_equal 0, chr_string_1.do_match(chr_string_2)

    chr_string_1 = Matching::ChronusString.new("")
    chr_string_2 = Matching::ChronusString.new("")
    assert_equal 0, chr_string_1.do_match(chr_string_2)

    chr_string_1 = Matching::ChronusString.new("super")
    chr_string_2 = Matching::ChronusString.new("super")
    assert_equal 1, chr_string_1.do_match(chr_string_2)

    chr_string_1 = Matching::ChronusString.new("super")
    chr_string_2 = Matching::ChronusArray.new(["super"])
    assert_equal 1, chr_string_1.do_match(chr_string_2)

    chr_string_1 = Matching::ChronusString.new("super")
    chr_string_2 = Matching::ChronusArray.new(["super", "great"])
    assert_equal 0.5, chr_string_1.do_match(chr_string_2)
    result = chr_string_1.do_match(chr_string_2, get_common_data: true)
    assert result.is_a?(Hash)
    assert_equal 0.5, result[:score]
    assert_equal_unordered ["super"], result[:common_values]

    chr_string_1 = Matching::ChronusString.new("super better")
    chr_string_2 = Matching::ChronusString.new("better")
    result = chr_string_1.do_match(chr_string_2, get_common_data: true)
    assert_equal ["better"], result[:common_values]

    # white space
    chr_string_1 = Matching::ChronusString.new("super")
    chr_string_2 = Matching::ChronusArray.new(["super", "great "])
    assert_equal 0.5, chr_string_1.do_match(chr_string_2)

    chr_string_1 = Matching::ChronusString.new("super")
    chr_string_2 = Matching::ChronusString.new("super")
    assert_equal 0, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [["better"]]}})
    assert_equal 1, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [["super"]]}})

    chr_string_1 = Matching::ChronusString.new("super")
    chr_string_2 = Matching::ChronusString.new("better")
    assert_equal 0, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [["better"]]}})
    assert_equal 1, chr_string_1.do_match(chr_string_2, {:matching_details => {"better" => [["super"]]}})
    assert_equal 0, chr_string_1.do_match(chr_string_2, {:matching_details => {"better" => [["better"]]}})

    chr_string_1 = Matching::ChronusString.new("super")
    chr_string_2 = Matching::ChronusArray.new(["super", "better"])
    assert_equal 0.5, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [["super"]], "better" => [["better"]]}})
    assert_equal 1, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [["super"]], "better" => [["super"]]}})
    assert_equal 0, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [["better"]], "better" => [["better"]]}})
    assert_equal 0, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [[]], "better" => [["better"]]}})

    chr_string_1 = Matching::ChronusString.new("super")
    chr_string_2 = Matching::ChronusOrderedArray.new(["better", "super"])
    assert_equal 0.5, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [["super"]], "better" => [["better"]]}})
    assert_equal 0, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [[]], "better" => [["better"]]}})
    assert_equal 0.5, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [[]], "better" => [["better", "super"]]}})
    assert_equal 0, chr_string_1.do_match(chr_string_2, {:matching_details => {"super" => [["best"]], "better" => [["best"]]}})
    assert_equal 0, chr_string_1.do_match(Matching::ChronusString.new(""), {:matching_details => {"super" => [["best"]], "better" => [["best"]]}})
  end

  def test_chronus_text
    chr_text_1 = Matching::ChronusText.new("india is a great country")
    chr_text_2 = Matching::ChronusString.new("great country")
    assert_equal 0.95, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusText.new("india is a great country")
    chr_text_2 = Matching::ChronusString.new("great country")
    result = chr_text_1.do_match(chr_text_2, get_common_data: true)
    assert result.is_a?(Hash)
    assert_equal_unordered ["great", "country"], result[:common_values]

    chr_text_1 = Matching::ChronusText.new("india is a great country")
    chr_text_2 = Matching::ChronusString.new("india is a great country")
    assert_equal 1, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusText.new("india is a great country")
    chr_text_2 = Matching::ChronusString.new("india is an amazing country")
    assert_equal 0.6, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusText.new("")
    chr_text_2 = Matching::ChronusString.new("")
    assert_equal Matching::EMPTY_WEIGHT, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusText.new("india is a great country")
    chr_text_2 = Matching::ChronusString.new("india india india")
    assert_equal 0.93, chr_text_1.do_match(chr_text_2).round(2)
  end

  def test_chronus_text_array
    chr_text_1 = Matching::ChronusText.new("project management personality development")
    chr_text_2 = Matching::ChronusArray.new(["project management", "personality development"])
    assert_equal 1.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusText.new("project management")
    chr_text_2 = Matching::ChronusArray.new(["project"])
    assert_equal 1.0, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusText.new("project management")
    chr_text_2 = Matching::ChronusArray.new(["project management"])
    assert_equal 1.0, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusText.new("project management")
    chr_text_2 = Matching::ChronusArray.new(["personality development"])
    assert_equal 0.0, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusText.new("project management")
    chr_text_2 = Matching::ChronusArray.new(["project development", "personality management"])
    assert_equal 0.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusText.new("")
    chr_text_2 = Matching::ChronusArray.new(["", ""])
    assert_equal Matching::EMPTY_WEIGHT, chr_text_1.do_match(chr_text_2).round(2)
  end

  def test_chronus_array_text
    chr_text_1 = Matching::ChronusArray.new(["project management", "personality development"])
    chr_text_2 = Matching::ChronusText.new("project management personality development")
    assert_equal 1.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusArray.new(["project"])
    chr_text_2 = Matching::ChronusText.new("project management")
    assert_equal 1.0, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusArray.new(["project management"])
    chr_text_2 = Matching::ChronusText.new("project management")
    assert_equal 1.0, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusArray.new(["personality development"])
    chr_text_2 = Matching::ChronusText.new("project management")
    assert_equal 0.0, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusArray.new(["project development", "personality management"])
    chr_text_2 = Matching::ChronusText.new("project management")
    assert_equal 0.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusArray.new(["", ""])
    chr_text_2 = Matching::ChronusText.new("")
    assert_equal Matching::EMPTY_WEIGHT, chr_text_1.do_match(chr_text_2).round(2)
  end

  def test_chronus_ordered_array
    chr_text_1 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    chr_text_2 = Matching::ChronusOrderedArray.new(["personality development"])
    assert_equal 0.67, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    chr_text_2 = Matching::ChronusOrderedArray.new(["project management"])
    assert_equal 1.0, chr_text_1.do_match(chr_text_2)
    
    chr_text_1 = Matching::ChronusOrderedArray.new(["personality development"])
    chr_text_2 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    assert_equal 0.44, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new(["project management"])
    chr_text_2 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    assert_equal 0.67, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new(["unmatched text"])
    chr_text_2 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    assert_equal 0.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new([])
    chr_text_2 = Matching::ChronusOrderedArray.new([])
    assert_equal Matching::EMPTY_WEIGHT, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new(["project management"])
    chr_text_2 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    assert_equal 0.5, chr_text_1.do_match(chr_text_2, {:matching_details => {"project management" => [["project management"]]}})
    assert_equal 0, chr_text_1.do_match(chr_text_2, {:matching_details => {"project management" => [["personality development"]]}})
    assert_equal 0.5, chr_text_1.do_match(chr_text_2, {:matching_details => {"personality development" => [["project management"]]}})
    assert_equal 1, chr_text_1.do_match(chr_text_2, {:matching_details => {"project management" => [["project management"]], "personality development" => [["project management"]]}})
    assert_equal 0, chr_text_1.do_match(chr_text_2, {:matching_details => {"project management" => [[]], "personality development" => [[]]}})
    assert_equal 0, chr_text_1.do_match(Matching::ChronusOrderedArray.new([]), {:matching_details => {"project management" => [[]], "personality development" => [[]]}})

    chr_text_1 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    chr_string_2 = Matching::ChronusString.new("project management")
    assert_equal 0.5, chr_text_1.do_match(chr_text_2, {:matching_details => {"project management" => [["project management"]]}})
    assert_equal 0.5, chr_text_1.do_match(chr_text_2, {:matching_details => {"project management" => [["personality development"]]}})
    assert_equal 0.5, chr_text_1.do_match(chr_text_2, {:matching_details => {"personality development" => [["project management"]]}})
    assert_equal 0, chr_text_1.do_match(chr_text_2, {:matching_details => {"project management" => [[]], "personality development" => [[]]}})
    assert_equal 0, chr_text_1.do_match(Matching::ChronusString.new(""), {:matching_details => {"project management" => [[]], "personality development" => [[]]}})

    chr_text_1 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    chr_string_2 = Matching::ChronusArray.new(["project management"])
    assert_equal 0.5, chr_text_1.do_match(chr_text_2, {:matching_details => {"project management" => [["project management"]]}})
    assert_equal 0.5, chr_text_1.do_match(chr_text_2, {:matching_details => {"project management" => [["personality development"]]}})
    assert_equal 0.5, chr_text_1.do_match(chr_text_2, {:matching_details => {"personality development" => [["project management"]]}})
    assert_equal 1, chr_text_1.do_match(chr_text_2, {:matching_details => {"personality development" => [["project management"]], "project management" => [["personality development"]]}})
    assert_equal 0, chr_text_1.do_match(chr_text_2, {:matching_details => {"project management" => [[]], "personality development" => [[]]}})
    assert_equal 0, chr_text_1.do_match(Matching::ChronusArray.new([]), {:matching_details => {"project management" => [[]], "personality development" => [[]]}})
  end

  def test_chronus_string_ordered_array
    chr_text_1 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    chr_text_2 = Matching::ChronusText.new("project management personality development")
    assert_equal 1.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new(["project"])
    chr_text_2 = Matching::ChronusText.new("project management")
    assert_equal 1.0, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusText.new("project management")
    chr_text_2 = Matching::ChronusOrderedArray.new(["project management"])
    assert_equal 1.0, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    chr_text_2 = Matching::ChronusText.new("personality development")
    assert_equal 0.5, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusText.new("project management")
    chr_text_2 = Matching::ChronusOrderedArray.new(["personality development"])
    assert_equal 0.0, chr_text_1.do_match(chr_text_2)

    chr_text_1 = Matching::ChronusText.new("personality development")
    chr_text_2 = Matching::ChronusOrderedArray.new(["project development", "personality management"])
    assert_equal 0.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new([])
    chr_text_2 = Matching::ChronusText.new("")
    assert_equal Matching::EMPTY_WEIGHT, chr_text_1.do_match(chr_text_2).round(2)
  end

  def test_chronus_array_ordered_array
    chr_text_1 = Matching::ChronusArray.new(["personality development"])
    chr_text_2 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    assert_equal 0.33, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusArray.new(["project management", "personality development"])
    chr_text_2 = Matching::ChronusOrderedArray.new(["personality development"])
    assert_equal 1.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusArray.new(["project management", "personality development"])
    chr_text_2 = Matching::ChronusOrderedArray.new(["project management"])
    assert_equal 1.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusArray.new(["personality development", "project management"])
    chr_text_2 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    assert_equal 1.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    chr_text_2 = Matching::ChronusArray.new(["personality development", "project management"])
    assert_equal 1.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new(["project management", "personality development", "talent development"])
    chr_text_2 = Matching::ChronusArray.new(["personality development", "project management"])
    assert_equal 1.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new(["project management", "personality development"])
    chr_text_2 = Matching::ChronusArray.new(["personality development", "project management", "talent development"])
    assert_equal 0.82, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new(["project development", "personality management"])
    chr_text_2 = Matching::ChronusArray.new(["project management", "personality development"])
    assert_equal 0.0, chr_text_1.do_match(chr_text_2).round(2)

    chr_text_1 = Matching::ChronusOrderedArray.new([])
    chr_text_2 = Matching::ChronusArray.new([])
    assert_equal Matching::EMPTY_WEIGHT, chr_text_1.do_match(chr_text_2).round(2)
  end

  def test_chronus_location
    # Some random locations. Anyway we are going to stub the distance.
    loc_1 = locations(:chennai)
    loc_2 = locations(:delhi)

    chr_location_1 = Matching::ChronusLocation.new([loc_1.lat, loc_1.lng])
    chr_location_2 = Matching::ChronusLocation.new([loc_2.lat, loc_2.lng])

    # Test each of the location ranges in
    # <code>Matching::ChronusLocation::DISTANCE_METRICS</code> and check whether
    # we get the match value specified in it.
    ranges = [[50, 1], [100, 0.75], [200, 0.5], [1000, 0.25]]
    ranges.each_with_index do |metric, i|
      cur_dist = metric[0]
      prev_dist = (i == 0) ? 0 : ranges[i-1][0]

      # Return some distance in this match range.
      dist_range = ((prev_dist + 1)...cur_dist)
      v = dist_range.to_a.sample
      chr_location_1.expects(:distance_in_miles).with(chr_location_2).returns(v)
      assert_equal metric[1], chr_location_1.do_match(chr_location_2)
    end

    #test for match label
    dist_range = (1...50)
    v = dist_range.to_a.sample
    chr_location_1.expects(:distance_in_miles).with(chr_location_2).returns(v)
    result = {score: 1, common_values: [chr_location_1.latitude, chr_location_1.longitude]}
    assert_equal_hash result, chr_location_1.do_match(chr_location_2, {get_common_data: true})
  end

  def test_chronus_educations
    edu1 = Education.new(
      :school_name => 'Anna University',
      :degree => "B.E.",
      :major => "Computers",
      :graduation_year => 1965)

    edu2 = Education.new(
      :school_name => 'anna university',
      :degree => "B.E.",
      :major => "Computers Science",
      :graduation_year => 1980)

    edu3 = Education.new(
      :school_name => 'MIT',
      :degree => "B.E.",
      :major => "Computers Science",
      :graduation_year => 1980)

    chr_edu_1 = Matching::ChronusEducations.new([edu1])
    chr_edu_2 = Matching::ChronusEducations.new([edu2, edu3])

    # Hit on only school name since major is not exactly matching. The LHS is
    # hard code by simulating the array_distance method on the school_name
    # values.
    assert_equal(((6.0 / 11) * 0.3 ), chr_edu_1.do_match(chr_edu_2))

    edu1 = Education.new(
      :school_name => 'Anna University',
      :degree => "B.E.",
      :major => "Computers Science",
      :graduation_year => 1965)

    edu2 = Education.new(
      :school_name => 'anna university',
      :degree => "B.E.",
      :major => "Computers Science",
      :graduation_year => 1980)

    chr_edu_1 = Matching::ChronusEducations.new([edu1])
    chr_edu_2 = Matching::ChronusEducations.new([edu2])

    # Hit on only school name since major is not exactly matching.
    assert_equal 1, chr_edu_1.do_match(chr_edu_2)

    result = chr_edu_1.do_match(chr_edu_2, get_common_data: true)
    assert result.is_a?(Hash)
    assert_equal 1, result[:score]
    assert_equal_unordered [["anna university"], ["computers science"]], result[:common_values]
  end

  def test_chronus_experiences
    work_1 = Experience.new(
      :job_title => 'Launch analyst',
      :company => "ISRO",
      :start_year => 1960,
      :end_year => 1975)

    work_2 = Experience.new(
      :job_title => 'Weather analyst',
      :company => "ISRO",
      :start_year => 1965,
      :end_year => 1990)

    chr_exp_1 = Matching::ChronusExperiences.new([work_1])
    chr_exp_2 = Matching::ChronusExperiences.new([work_2])

    assert_equal 0.5, chr_exp_1.do_match(chr_exp_2)

    work_1 = Experience.new(
      :job_title => 'Weather analyst',
      :company => "ISRO",
      :start_year => 1960,
      :end_year => 1975)

    work_2 = Experience.new(
      :job_title => 'Weather analyst',
      :company => "ISRO India",
      :start_year => 1965,
      :end_year => 1990)

    chr_exp_1 = Matching::ChronusExperiences.new([work_1])
    chr_exp_2 = Matching::ChronusExperiences.new([work_2])

    assert_equal 0.5, chr_exp_1.do_match(chr_exp_2)

    result = chr_exp_1.do_match(chr_exp_2, get_common_data: true)
    assert result.is_a?(Hash)
    assert_equal [["weather analyst"]], result[:common_values].reject(&:empty?)
  end

  def test_chronus_mismatch
    chr_mgr_1 = Matching::ChronusMisMatch.new([1,3,4,5])
    chr_mgr_2 = Matching::ChronusMisMatch.new(2)
    chr_mgr_3 = Matching::ChronusMisMatch.new(1)
    
    assert chr_mgr_1.match(chr_mgr_2)
    assert_false chr_mgr_1.match(chr_mgr_3)
  end

  def test_complex_fields_mapping
    obj_1_arr = []
    obj_2_arr = []
    obj_1_arr << mock
    obj_1_arr[0].expects(:send).with(:field_1).at_least(0).returns("Man")
    obj_1_arr[0].expects(:send).with(:field_2).at_least(0).returns("World")
    obj_1_arr[0].expects(:send).with(:field_3).at_least(0).returns("Monkey")

    obj_2_arr << mock
    obj_2_arr[0].expects(:send).with(:field_1).at_least(0).returns("Man")
    obj_2_arr[0].expects(:send).with(:field_2).at_least(0).returns("Road")
    obj_2_arr[0].expects(:send).with(:field_3).at_least(0).returns("Monkey")

    obj_2_arr << mock
    obj_2_arr[1].expects(:send).with(:field_1).at_least(0).returns("Women")
    obj_2_arr[1].expects(:send).with(:field_2).at_least(0).returns("World")
    obj_2_arr[1].expects(:send).with(:field_3).at_least(0).returns("Key")

    expected_val = ((0.55 * 0.35) + ((6.0/11.0) * 0.3) + ((6.0/11.0) * 0.9)) / (1.55)
    data_1 = DummyCollectionType.new(
      [{:field_1 => 'Man', :field_2 => 'World', :field_3 => 'Monkey'}]
    )

    data_2 = DummyCollectionType.new(
      [{:field_1 => 'Man', :field_2 => 'Road', :field_3 => 'Monkey'},
        {:field_1 => 'Women', :field_2 => 'World', :field_3 => 'Key'}
      ]
    )

    assert_equal expected_val.round(2), data_1.do_match(data_2).round(2)
  end

  def test_complex_fields_mapping_with_nil
    obj_1_arr = []
    obj_2_arr = []
    obj_1_arr << mock
    obj_1_arr[0].expects(:send).with(:field_1).at_least(0).returns(nil)
    obj_1_arr[0].expects(:send).with(:field_2).at_least(0).returns(nil)
    obj_1_arr[0].expects(:send).with(:field_3).at_least(0).returns(nil)

    obj_2_arr << mock
    obj_2_arr[0].expects(:send).with(:field_1).at_least(0).returns(nil)
    obj_2_arr[0].expects(:send).with(:field_2).at_least(0).returns(nil)
    obj_2_arr[0].expects(:send).with(:field_3).at_least(0).returns("abc")

    obj_2_arr << mock
    obj_2_arr[1].expects(:send).with(:field_1).at_least(0).returns(nil)
    obj_2_arr[1].expects(:send).with(:field_2).at_least(0).returns(nil)
    obj_2_arr[1].expects(:send).with(:field_3).at_least(0).returns("abc")

    expected_val = ((0.55 * 0.35) + ((6.0/11.0) * 0.3) + 0) / (1.55)
    data_1 = DummyCollectionType.new(
      [{:field_1 => nil, :field_2 => nil, :field_3 => nil}]
    )

    data_2 = DummyCollectionType.new(
      [{:field_1 => nil, :field_2 => nil, :field_3 => "abc"},
        {:field_1 => nil, :field_2 => nil, :field_3 => "abc"}
      ]
    )

    assert_equal expected_val.round(2), data_1.do_match(data_2).round(2)
  end

  def test_complex_matching
    chr_arr = Matching::ChronusArray.new(['a','b','c','d','e'])
    chr_string = Matching::ChronusString.new("better")
    chr_text = Matching::ChronusText.new("great country")

    assert_nothing_raised do
      chr_arr.do_match(chr_string)
      chr_arr.do_match(chr_text)

      chr_string.do_match(chr_arr)
      chr_string.do_match(chr_text)

      chr_text.do_match(chr_arr)
      chr_text.do_match(chr_string)
    end
  end
end