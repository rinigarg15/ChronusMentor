require_relative './../../test_helper.rb'

class CoreExtensionsTest < ActiveSupport::TestCase
  def test_average
    assert_equal 0.0, [].average
    assert_equal 2.5, [2,3].average
    assert_equal 2.0, [1,3].average
  end

  def test_stringify_keys
    a = {1 => "hi", "2" => "ce", 3 => "by"}
    a.stringify_keys!
    assert_equal({"1" => "hi", "2" => "ce", "3" => "by"}, a)
  end

  def test_regex_scan
    assert_false "Sample".regex_scan?("sample")
    assert "Sample".regex_scan?("sample", true)
    assert "Manjunathsample123".regex_scan?("manjunath", true)
  end

  def test_get_week_of_month
    assert_equal 1, Time.zone.parse("March 1 2014").get_week_of_month
    assert_equal 1, Time.zone.parse("March 2 2014").get_week_of_month
    assert_equal 2, Time.zone.parse("March 10 2014").get_week_of_month
    assert_equal 5, Time.zone.parse("March 31 2014").get_week_of_month
    assert_equal 5, Time.zone.parse("March 30 2014").get_week_of_month
  end

  def test_string_constantize_only
    assert_raise(Authorization::PermissionDenied, "Tried to constantize unsafe string Invalid") do
      "Invalid".constantize_only(['valid', 'something else valid'])
    end

    assert_raise(Authorization::PermissionDenied, "Tried to constantize unsafe string Invalid") do
      "Invalid".constantize_only(['invalid'])
    end

    assert_raise(Authorization::PermissionDenied, "Tried to constantize unsafe string Invalid") do
      "Invalid".constantize_only([])
    end

    assert_raise(NameError, "wrong constant name Invalid") do
      "Invalid".constantize_only(["Invalid", "Valid"])
    end

    assert_equal User, "User".constantize_only(["User", "Other Valid"])
  end

  def test_send_only
    assert_raise(Authorization::PermissionDenied, "Tried to call restricted method name via send") do
      users(:f_admin).send_only('name', ['id'])
    end

    assert_equal users(:f_admin).name, users(:f_admin).send_only('name', ['name'])
    assert_equal users(:f_admin).name, users(:f_admin).send_only(:name, ['name'])
    assert_equal users(:f_admin).name, users(:f_admin).send_only('name', [:name])
    assert_equal users(:f_admin).name, users(:f_admin).send_only(:name, [:name])

    assert_raise(Authorization::PermissionDenied, "Tried to call restricted method round via send") do
      2.45.send_only('round', ['not round'], 1)
    end

    assert_equal 2.5, 2.45.send_only('round', ['round', 'not round'], 1)
  end

  def test_split_by_comma
    assert_equal ["A", "B'C", "'C,F,G'", "'H,K'"], "A, B'C, '\'C,F,G\'', '\'H,K\''".split_by_comma
    assert_equal ["A", "B", "c,F,G", "H,K"], "A, B, 'c,F,G', 'H,K',  ".split_by_comma
    assert_equal ["A", "B',C", "B',C'", "'F,G'", "H,K", "'"], "A, 'B\\',C', 'B\\',C\\'', '\'F,G\'', 'H,K',  '\\'',  ".split_by_comma
    assert_equal ["A,B,C"], "A,B,C".split_by_comma(true)
  end

  def test_join_by_seperator
    assert_equal "A, B'C, '\\'C,F,G\\'', '\\'H,K\\''", ["A", "B'C", "'C,F,G'", "'H,K'"].join_by_separator
    assert_equal "A, B, 'c,F,G', 'H,K'", ["A", "B", "c,F,G", "H,K"].join_by_separator(", ")
    assert_equal "A, 'B',C', 'B',C'', '\\'F,G\\'', 'H,K'", ["A", "B',C", "B',C'", "'F,G'", "H,K"].join_by_separator(", ")
    assert_equal "A | B | 'c,F,G' | 'H,K'", ["A", "B", "c,F,G", "H,K"].join_by_separator(" | ")
    assert_equal "A | 'B',C' | 'B',C'' | '\\'F,G\\'' | 'H,K'", ["A", "B',C", "B',C'", "'F,G'", "H,K"].join_by_separator(" | ")
  end

  def test_sort_translated_contents
    assert_equal [1, 2, 3], [2, 1, 3].sort_translated_contents
    assert_equal ["a", "b", "z"], ["a", "z", "b"].sort_translated_contents
    assert_equal ["Schöler", "Schwertner"], ["Schwertner", "Schöler"].sort_translated_contents
    run_in_another_locale("fr-CA") do
      assert_equal ["Annuler", "Non", "Oui", "Soumettre"], ["display_string.Submit".translate, "display_string.Yes".translate, "display_string.No".translate, "display_string.Cancel".translate].sort_translated_contents
    end
  end
end