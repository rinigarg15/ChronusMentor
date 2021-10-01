require_relative '../test_helper'

class ViewedObjectTest < ActiveSupport::TestCase
  def test_validations
    viewed_object = ViewedObject.new
    assert_false viewed_object.valid?
    assert_equal ["can't be blank"], viewed_object.errors.messages[:user_id]
    assert_equal ["can't be blank"], viewed_object.errors.messages[:ref_obj]

    viewed_object.user_id = users(:not_requestable_mentor).id
    viewed_object.ref_obj_id = 2
    viewed_object.ref_obj_type = "Announcement"
    assert viewed_object.valid?
    viewed_object.save!

    viewed_object_2 = ViewedObject.new(user_id: users(:f_mentor).id, ref_obj_id: 1, ref_obj_type: "Announcement")
    assert_false viewed_object_2.valid?
    assert_equal ["has already been taken"], viewed_object_2.errors.messages[:user_id]

    viewed_object_2.ref_obj_id = 4
    assert viewed_object_2.valid?
  end
end