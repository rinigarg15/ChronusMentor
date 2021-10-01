# == Schema Information
#
# Table name: login_tokens
#
#  id                :integer          not null, primary key
#  member_id         :integer
#  token_code        :string(255)
#  last_used_at      :datetime
#  created_at        :datetime
#  updated_at        :datetime
#

class LoginToken < ActiveRecord::Base
  include Authentication
  # Relationships
  belongs_to :member

  # Validations
  validates :member_id, presence: true

  before_create :set_token_code

  def expired?
    self.created_at < 1.day.ago || self.last_used_at.present?
  end

  def mark_expired
    self.update_attributes!(last_used_at: Time.now)
  end

  protected

  def set_token_code
    self.token_code = self.class.make_token
  end

end
