# == Schema Information
#
# Table name: user_settings
#
#  id                     :integer          not null, primary key
#  user_id                :integer
#  max_meeting_slots     :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  max_meeting_slots      :integer
#

class UserSetting < ActiveRecord::Base
  # Hours of availabilty is for a month/quarter/year
  module Frequency
    def self.monthly
      {:label => 'display_string.month'.translate, :value => 0}
    end

    def self.quarterly
      {:label => 'display_string.quarter'.translate, :value => 1}
    end

    def self.yearly
      {:label => 'display_string.year'.translate, :value => 2}
    end

    def self.all
      [monthly, quarterly, yearly]
    end
  end
  #Association
  belongs_to :user

  #validations
  validates :user, :presence => true

  def update_limit_based_on_reason
    limit_to_reset = self.user.get_meeting_limit_to_reset
    limit_updated = self.max_meeting_slots.present? ? limit_to_reset < self.max_meeting_slots : true
    self.update_attributes(max_meeting_slots: limit_to_reset) if limit_updated
    limit_updated
  end
   
end
