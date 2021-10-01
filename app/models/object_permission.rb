# == Schema Information
#
# Table name: object_permissions
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ObjectPermission < ActiveRecord::Base
  module MentoringModel
    MILESTONE = "manage_mm_milestones"
    GOAL = "manage_mm_goals"
    TASK = "manage_mm_tasks"
    FACILITATION_MESSAGE = "manage_mm_messages"
    MEETING = "manage_mm_meetings"
    ENGAGEMENT_SURVEY = "manage_mm_engagement_surveys"

    PERMISSIONS = [MILESTONE, GOAL, TASK, FACILITATION_MESSAGE, MEETING, ENGAGEMENT_SURVEY]

    DEFAULTS = {
      admin_role: [GOAL, TASK, FACILITATION_MESSAGE, ENGAGEMENT_SURVEY],
      user_role: [GOAL, TASK, MEETING]
    }

    ADMIN_PERMISSIONS = [MILESTONE, GOAL, TASK, FACILITATION_MESSAGE, ENGAGEMENT_SURVEY]
    OTHER_USER_PERMISSIONS = [MILESTONE, GOAL, TASK, MEETING]
  end

  # Associations
  has_many :object_role_permissions, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: true

  def self.create_default_permissions
    MentoringModel::PERMISSIONS.each do |permission_name|
      ObjectPermission.find_or_create_by!(name: permission_name)
    end
  end

  def object_permission_name
    name
  end
end
