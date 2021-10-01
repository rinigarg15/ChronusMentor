# == Schema Information
#
# Table name: passwords
#
#  id              :integer          not null, primary key
#  reset_code      :string(255)
#  expiration_date :datetime
#  created_at      :datetime
#  updated_at      :datetime
#  member_id       :integer
#  email_id        :string(255)
#

require 'digest/sha1'

class Password < ActiveRecord::Base
  attr_accessor :email

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:email]
  }

  # Relationships
  belongs_to :member

  # Validations
  validate :member_xor_email
  before_validation :set_reset_code, :on => :create

  scope :expired, -> { where("expiration_date < ?", Time.now.utc)}

  def self.destroy_expired
    self.expired.destroy_all
  end

  protected

  def set_reset_code
    self.reset_code = Digest::SHA1.hexdigest(Time.now.to_s.split(//).sort_by {rand}.join )
    self.expiration_date = 6.months.from_now
  end

  private

  def member_xor_email
    if !(member.present? ^ email_id.present?)
      errors[:base] << "activerecord.custom_errors.password.member_or_email".translate
    end
  end
end
