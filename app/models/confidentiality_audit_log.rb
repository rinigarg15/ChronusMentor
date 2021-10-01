# == Schema Information
#
# Table name: confidentiality_audit_logs
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  group_id   :integer
#  reason     :text(65535)
#  program_id :integer
#  created_at :datetime
#  updated_at :datetime
#

class ConfidentialityAuditLog < ActiveRecord::Base
  belongs_to :user
  belongs_to_program
  belongs_to :group

  validates_presence_of :reason, :program, :group, :user
  validate :check_user_permissions

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:reason]
  }

  private

  # The user must have necessray connection management permission.
  def check_user_permissions
    if self.user && !self.user.can_manage_connections?
      self.errors.add(:user, "activerecord.custom_errors.confidentiality_audit_log.no_privileges".translate)
    end
  end
end
