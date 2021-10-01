module ActsAsSubscribable
  extend ActiveSupport::Concern

  class_methods do
    def acts_as_subscribable
      has_many :subscriptions, as: :ref_obj, dependent: :destroy
      has_many :subscribers, through: :subscriptions, source: :user
    end
  end

  def subscribed_by?(user)
    self.subscriptions.exists?(user_id: user.id)
  end

  def subscribe_user(user)
    self.subscribers << user unless self.subscribed_by?(user)
  end

  def unsubscribe_user(user)
     self.subscriptions.where(user_id: user).destroy_all
  end

  def toggle_subscription(user)
    subscribed_by?(user) ? unsubscribe_user(user) : subscribe_user(user)
  end
end