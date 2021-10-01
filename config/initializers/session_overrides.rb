ActiveRecord::SessionStore::Session.class_eval do
  before_save :ensure_member_is_set

  private
  def ensure_member_is_set 
    member_id = self.data["member_id"]
    #NOTE: On updating member id in session data to nil, the member_id column won't get updated
    if member_id
      self.member_id = member_id
    end
  end
end