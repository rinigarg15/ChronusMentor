# == Schema Information
#
# Table name: facilitation_delivery_logs
#
#  id                                  :integer          not null, primary key
#  facilitation_delivery_loggable_id   :integer
#  user_id                             :integer
#  last_delivered_at                   :datetime
#  group_id                            :integer
#  facilitation_delivery_loggable_type :string(255)
#

class FacilitationDeliveryLog < ActiveRecord::Base
  belongs_to :user
  belongs_to :facilitation_delivery_loggable, polymorphic: true
  belongs_to :group
  before_create :set_last_delivered_at

  validates_presence_of :user, :facilitation_delivery_loggable_id, :facilitation_delivery_loggable_type
  validates_uniqueness_of :facilitation_delivery_loggable_id, :scope => [:user_id, :group_id, :facilitation_delivery_loggable_type]
  validate :check_program_integrity, :if => Proc.new{ |f| f.user && f.facilitation_delivery_loggable }
  validate :check_valid_group, :if => Proc.new{|facilitation_delivery_log| facilitation_delivery_log.group.present? }, on: :create

  private

  def set_last_delivered_at
    self.last_delivered_at = Time.now
  end

  # Make sure the user and the message's program are the same.
  def check_program_integrity
    if self.user.program != self.facilitation_delivery_loggable.program
      self.errors[:base] << "activerecord.custom_errors.facilitation.message_and_user_different_programs".translate
    end
  end

  def check_valid_group
    unless self.group.has_member?(user)
      self.errors[:base] << "activerecord.custom_errors.facilitation.user_and_group_invalid".translate(mentoring_connection: self.group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)
    end
  end
end
