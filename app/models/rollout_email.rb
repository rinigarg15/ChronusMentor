# == Schema Information
#
# Table name: rollout_emails
#
#  id           :integer          not null, primary key
#  ref_obj_id   :integer
#  ref_obj_type :string(255)
#  email_id     :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  action_type  :integer          default(0)
#

class RolloutEmail < ActiveRecord::Base
  belongs_to :ref_obj, polymorphic: true

  module ActionType
    NONE = 0
    UPDATE_ALL = 1
    UPDATE_ALL_NON_CUSTOMIZED = 2
    KEEP_CURRENT_CONTENT = 3
    SWITCH_TO_DEFAULT_CONTENT = 4

    def self.all
      (NONE..SWITCH_TO_DEFAULT_CONTENT)
    end
  end
  
  validates :ref_obj, presence: true
  validates :email_id, inclusion: { in: ChronusActionMailer::Base.get_descendants.collect{|e| e.mailer_attributes[:uid]}, allow_nil: true }
  validates :action_type, inclusion: {in: ActionType.all}
end
