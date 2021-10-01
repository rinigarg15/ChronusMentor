# == Schema Information
#
# Table name: group_membership_settings
#
#  id                :integer          not null, primary key
#  group_id          :integer          not null
#  role_id           :integer          not null
#  max_limit         :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class Group::MembershipSetting < ActiveRecord::Base
  belongs_to :group
  belongs_to :role

  validates :group_id, uniqueness: {scope: :role_id}
  validate :group_and_role_program
  validates :max_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :allow_join, inclusion: { in: [false] }, allow_nil: true

  after_save :update_group_delta

  scope :with_max_limit, -> { where.not(max_limit: nil) }

  module MaxLimit
    MINIMUM = 1
    DEFAULT_MAXIMUM = 10**9 # Setting a billion users as a default maximum for now, if the value is nil
  end

  def self.es_reindex(membership_setting)
    DelayedEsDocument.do_delta_indexing(Group, Array(membership_setting), :group_id)
  end

  private

  def group_and_role_program
    if self.group.program != self.role.program
      errors.add(:membership_setting, "activerecord.custom_errors.group/membership_setting.group_and_role_program_mismatch".translate)
    end
  end

  def update_group_delta
    if self.saved_change_to_max_limit?
      self.class.es_reindex(self)
    end
  end
end
