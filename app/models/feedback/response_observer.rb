class Feedback::ResponseObserver < ActiveRecord::Observer
  def after_create(response)
    user_stat = UserStat.find_or_create_by(user_id: response.recipient_id)
    user_stat.update_rating_on_response_create(response.rating)
  end

  def after_update(response)
    user_stat = UserStat.find_by(user_id: response.recipient_id)
    user_stat.update_rating_on_response_update(response.rating, response.rating_before_last_save)
  end

  def after_destroy(response)
    user_stat = UserStat.find_by(user_id: response.recipient_id)
    user_stat.update_rating_on_response_destroy(response.rating)
  end
end