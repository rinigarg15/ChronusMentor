require_relative './../../test_helper'

class QuestionChoiceExtensionsTest < ActiveSupport::TestCase
  def test_split_by_separator
    str = "hello,world,,"
    assert_equal ["hello", "world", "", ""], ProfileQuestion.split_by_separator(str)
  end

  def test_zip_arrays_to_hash
    keys = ["key1", "key2"]
    values = ["val1", "val2"]
    expected_hash = {"key1" => "val1", "key2" => "val2"}
    assert_equal expected_hash, ProfileQuestion.zip_arrays_to_hash(keys, values)
  end
end