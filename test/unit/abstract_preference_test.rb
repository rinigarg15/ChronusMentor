require_relative './../test_helper.rb'

class AbstractPreferenceTest < ActiveSupport::TestCase

  def test_belongs_to_preference_marker
    favorite = abstract_preferences(:favorite_1)
    assert_equal users(:f_student), favorite.preference_marker_user

    ignored = abstract_preferences(:ignore_1)
    assert_equal users(:f_student), ignored.preference_marker_user

    favorite_1 = create_favorite_preference(preference_marker_user: users(:f_student), preference_marked_user: users(:f_mentor_student))
    assert_equal users(:f_mentor_student), favorite_1.preference_marked_user
    assert_equal users(:f_student), favorite_1.preference_marker_user
  end

  def test_belongs_to_preference_marked
    favorite = abstract_preferences(:favorite_1)
    assert_equal users(:f_mentor), favorite.preference_marked_user

    ignored = abstract_preferences(:ignore_1)
    assert_equal users(:f_mentor), ignored.preference_marked_user

    ignored_1 = create_ignore_preference(preference_marker_user: users(:f_student), preference_marked_user: users(:f_mentor_student))
    assert_equal users(:f_mentor_student), ignored_1.preference_marked_user
    assert_equal users(:f_student), ignored_1.preference_marker_user
  end

  def test_validations
    favorite = abstract_preferences(:favorite_1)
    favorite.update_attribute(:preference_marked_user, nil)
    assert_false favorite.valid?
    assert_equal ["can't be blank"],  favorite.errors.messages[:preference_marked_user_id]

    favorite_1 = FavoritePreference.new
    favorite_1.preference_marked_user = users(:f_student)
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :preference_marker_user_id, "can't be blank" do
      favorite_1.save!
    end

    ignored = abstract_preferences(:ignore_1)
    ignored.update_attribute(:preference_marker_user, nil)
    assert_false ignored.valid?
    assert_equal ["can't be blank"],  ignored.errors.messages[:preference_marker_user_id]

    ignored_1 = IgnorePreference.new
    ignored_1.preference_marker_user = users(:f_student)
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :preference_marked_user_id, "can't be blank" do
      ignored_1.save!
    end

    favorite2 = abstract_preferences(:favorite_1)
    favorite2.update_attributes(preference_marked_user: nil, preference_marker_user: nil)
    assert_false favorite2.valid?
    assert_equal ["can't be blank"],  favorite2.errors.messages[:preference_marked_user_id]
    assert_equal ["can't be blank"],  favorite2.errors.messages[:preference_marker_user_id]
  end

  def test_uniqueness_validations
    favorite3 = abstract_preferences(:favorite_1)
    favorite3.update_attribute(:preference_marked_user, users(:robert))
    assert_false favorite3.valid?
    assert_equal ["has already been taken"],  favorite3.errors.messages[:type]

    ignored2 = abstract_preferences(:ignore_1)
    ignored2.update_attribute(:preference_marked_user, users(:ram))
    assert_false ignored2.valid?
    assert_equal ["has already been taken"],  ignored2.errors.messages[:type]
  end

  def test_role_validations
    favorite3 = abstract_preferences(:favorite_1)
    favorite3.update_attribute(:preference_marked_user, users(:mkr_student))
    assert_false favorite3.valid?
    assert_equal ["is not mentor"], favorite3.errors.messages[:preference_marked_user]

    ignored2 = abstract_preferences(:ignore_1)
    ignored2.update_attribute(:preference_marked_user, users(:mkr_student))
    assert_false ignored2.valid?
    assert_equal ["is not mentor"], ignored2.errors.messages[:preference_marked_user]
  end

  def test_program_integrity_validations
    favorite3 = abstract_preferences(:favorite_1)
    favorite3.update_attribute(:preference_marker_user, users(:moderated_student))
    assert_false favorite3.valid?
    assert_equal ["Preference marker and preference marked users cannot belong to different programs"], favorite3.errors.messages[:base]

    ignored2 = abstract_preferences(:ignore_1)
    ignored2.update_attribute(:preference_marker_user, users(:moderated_student))
    assert_false ignored2.valid?
    assert_equal ["Preference marker and preference marked users cannot belong to different programs"], ignored2.errors.messages[:base]
  end
end