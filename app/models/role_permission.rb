# == Schema Information
#
# Table name: role_permissions
#
#  id            :integer          not null, primary key
#  role_id       :integer          not null
#  permission_id :integer          not null
#

class RolePermission < ActiveRecord::Base
  PROPOSE_GROUPS = "propose_groups"
  SEND_PROJECT_REQUEST = "send_project_request"
  CREATE_PROJECT_WITHOUT_APPROVAL = "create_project_without_approval"
  
  belongs_to :role
  belongs_to :permission

  validates_uniqueness_of :permission_id, :scope => [:role_id]

end
