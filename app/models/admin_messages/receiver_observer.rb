class AdminMessages::ReceiverObserver < ActiveRecord::Observer

  def before_validation(receiver)
    receiver.strip_whitespace_from(receiver.email)
  end

end