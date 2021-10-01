require_relative './../../../test_helper'

class Feedback::ResponseObserverTest < ActiveSupport::TestCase

  def setup
    super
    @feedback_form = programs(:albers).feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
  end

  def test_after_create
    assert_difference 'UserStat.count', 1 do
      Feedback::Response.create!(:rating_giver => users(:student_2), :rating_receiver => users(:not_requestable_mentor), :group => groups(:group_2), :feedback_form => @feedback_form, :rating => 4)
    end
    user_stat = UserStat.last
    assert_equal user_stat.user_id, users(:not_requestable_mentor).id
    assert_equal user_stat.average_rating, 4.0
    assert_equal user_stat.rating_count, 1
  end

  def test_after_update
    response = Feedback::Response.create!(:rating_giver => users(:student_2), :rating_receiver => users(:not_requestable_mentor), :group => groups(:group_2), :feedback_form => @feedback_form, :rating => 4)

    user_stat = UserStat.last
    assert_equal user_stat.user_id, users(:not_requestable_mentor).id
    assert_equal user_stat.average_rating, 4.0
    assert_equal user_stat.rating_count, 1

    assert_no_difference 'UserStat.count' do
      response.update_attribute(:rating, 5)
    end

    user_stat.reload
    assert_equal user_stat.user_id, users(:not_requestable_mentor).id
    assert_equal user_stat.average_rating, 5.0
    assert_equal user_stat.rating_count, 1
  end

  def test_after_destroy
    response = Feedback::Response.create!(:rating_giver => users(:student_2), :rating_receiver => users(:not_requestable_mentor), :group => groups(:group_2), :feedback_form => @feedback_form, :rating => 4)
    assert_difference 'UserStat.count', -1 do
      response.destroy
    end
  end
end