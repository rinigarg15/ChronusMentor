require_relative './../../test_helper.rb'

class UserPreferencesHashTest < ActiveSupport::TestCase
  include UserPreferencesHash

  def test_set_user_preferences_hash
    self.instance_variable_set("@current_user", users(:f_student))
    set_user_preferences_hash
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:ignore_1).id, users(:ram).id=>abstract_preferences(:ignore_3).id}, self.instance_variable_get("@ignore_preferences_hash"))
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:favorite_1).id, users(:robert).id=>abstract_preferences(:favorite_3).id}, self.instance_variable_get("@favorite_preferences_hash"))
  end

  def test_set_user_preferences_hash_no_ignore_preferences
    self.instance_variable_set("@current_user", users(:f_student))
    set_user_preferences_hash(false)
    assert_nil self.instance_variable_get("@ignore_preferences_hash")
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:favorite_1).id, users(:robert).id=>abstract_preferences(:favorite_3).id}, self.instance_variable_get("@favorite_preferences_hash"))
  end
end