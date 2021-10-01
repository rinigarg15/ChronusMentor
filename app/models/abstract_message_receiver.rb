# == Schema Information
#
# Table name: abstract_message_receivers
#
#  id              :integer          not null, primary key
#  member_id       :integer
#  message_id      :integer          not null
#  name            :string(255)
#  email           :string(255)
#  status          :integer          default(0)
#  created_at      :datetime
#  updated_at      :datetime
#  api_token       :string(255)
#  message_root_id :integer          default(0), not null
#

class AbstractMessageReceiver < ActiveRecord::Base

  module Status
    UNREAD  = 0
    READ    = 1
    DELETED = 2

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  belongs_to :member
  belongs_to :message, class_name: "AbstractMessage", inverse_of: :message_receivers
  belongs_to :message_root, class_name: "AbstractMessage"

  scope :unread, -> { where(:status => Status::UNREAD)}
  scope :read, -> { where(:status => Status::READ)}
  scope :deleted, -> { where(:status => Status::DELETED)}

  validates_uniqueness_of :member_id, :scope => :message_id, :allow_nil => true
  validates :status, inclusion: {in: AbstractMessageReceiver::Status.all}
  validate :check_for_active_receiver, on: :create

  before_validation :set_api_token, :on => :create

  def read?
    self.status == Status::READ
  end

  def unread?
    self.status == Status::UNREAD
  end

  def deleted?
    self.status == Status::DELETED
  end

  def mark_as_read!
    self.update_attribute(:status, Status::READ) if self.unread?
  end

  def mark_deleted!
    self.update_attribute(:status, Status::DELETED)
  end

  def offline?
    !self.member && !self.email.nil?
  end

  private

  # Checks whether the receiver is active, unless the sender is an admin.
  #
  def check_for_active_receiver
    if self.message && self.message.sender && self.member
      self.errors.add(:member, "activerecord.custom_errors.message.member_not_active".translate) if !self.member.active? && !self.message.sender.is_admin?
    end
  end

  def set_api_token
    self.api_token = secure_digest(Time.now, (1..10).map{ rand.to_s })
  end

  def secure_digest(*args)
    Digest::MD5.hexdigest(args.flatten.join('--'))
  end
  
end
