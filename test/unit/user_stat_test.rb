require_relative './../test_helper.rb'

class UserStatTest < ActiveSupport::TestCase

  def test_user_association
    user = users(:f_mentor)
    user_stat = UserStat.create!(:user => user, :rating_count => 10, :average_rating => 4)
    assert_equal user_stat.user, user
  end

  def test_validation_for_user
    user_stat = UserStat.new(:rating_count => 10, :average_rating => 4)
    assert_false user_stat.valid?
    assert user_stat.errors[:user].include?("can't be blank")
  end

  def test_validation_for_rating_count
    # we are adding default value
    user_stat = UserStat.new(:user => users(:f_mentor), :average_rating => 4)
    assert user_stat.valid?

    # cannot be less than 0
    user_stat = UserStat.new(:rating_count => -1, :user => users(:f_mentor), :average_rating => 4)
    assert_false user_stat.valid?
    assert user_stat.errors[:rating_count].include?("must be greater than or equal to 0")
  end

  def test_validation_for_average_rating
    # we are adding default value
    user_stat = UserStat.new(:user => users(:f_mentor), :rating_count => 10)
    assert user_stat.valid?

    # cannot be less than 0
    user_stat = UserStat.new(:rating_count => 1, :user => users(:f_mentor), :average_rating => -1)
    assert_false user_stat.valid?
    assert user_stat.errors[:average_rating].include?("must be greater than or equal to 0.5")

    # cannot be more than 100
    user_stat = UserStat.new(:rating_count => 1, :user => users(:f_mentor), :average_rating => 6)
    assert_false user_stat.valid?
    assert user_stat.errors[:average_rating].include?("must be less than or equal to 5")
  end

  def test_update_rating_stat_for_response_actions
    feedback_form = programs(:albers).feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first

    assert_difference 'UserStat.count', 1 do
      Feedback::Response.create!(:rating_giver => users(:student_2), :rating_receiver => users(:not_requestable_mentor), :group => groups(:group_2), :feedback_form => feedback_form, :rating => 4)
    end
    user_stat = UserStat.last
    assert_equal user_stat.user_id, users(:not_requestable_mentor).id
    assert_equal user_stat.average_rating, 4.0
    assert_equal user_stat.rating_count, 1

    user_stat.update_rating_on_response_create(3)
    user_stat.reload
    assert_equal user_stat.average_rating, 3.5
    assert_equal user_stat.rating_count, 2

    #updating the response
    response = Feedback::Response.last
    response.update_attribute(:rating, 2)
    user_stat.reload
    assert_equal user_stat.average_rating, 2.5
    assert_equal user_stat.rating_count, 2

    #destroying the response
    response.destroy
    user_stat.reload
    assert_equal user_stat.average_rating, 3.0
    assert_equal user_stat.rating_count, 1  
  end

  def test_observers_reindex_es
    u = users(:not_requestable_mentor)
    feedback_form = programs(:albers).feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(3).with(User, [u.id])
    Feedback::Response.create!(rating_giver: users(:student_2), rating_receiver: users(:not_requestable_mentor), group: groups(:group_2), feedback_form: feedback_form, rating: 4) # 1st time

    user_stat = UserStat.last
    user_stat.update_attribute(:average_rating, 3)  # 2nd time

    user_stat.destroy  # 3rd time
  end
end