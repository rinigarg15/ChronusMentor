# == Schema Information
#
# Table name: object_role_permissions
#
#  id                   :integer          not null, primary key
#  ref_obj_id           :integer
#  ref_obj_type         :string(255)
#  role_id              :integer
#  object_permission_id :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#

class ObjectRolePermission < ActiveRecord::Base
  # Associations
  belongs_to :ref_obj, polymorphic: true
  belongs_to :role
  belongs_to :object_permission

  # Validations
  validates :ref_obj_id, :ref_obj_type, :role_id, :object_permission_id, presence: true
  validates :object_permission_id, uniqueness: { scope: [:ref_obj_id, :ref_obj_type, :role_id] }

  delegate :object_permission_name, :to => :object_permission
  delegate :role_name, :to => :role
end
