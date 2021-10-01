# == Schema Information
#
# Table name: permissions
#
#  id   :integer          not null, primary key
#  name :string(255)      not null
#

class Permission < ActiveRecord::Base
  # Format that the permission names should be of.
  NAME_FORMAT = /^([a-z]|_)+$/

  cattr_accessor :all_permissions
  # ASSOCIATIONS
  # ============================================================================
  has_many :role_permissions, :dependent => :destroy
  has_many :roles, :through => :role_permissions

  # VALIDATIONS
  # ============================================================================
  validates_presence_of :name
  validates_uniqueness_of :name
  validate :check_name_is_of_valid_format

  # Loads default permissions from the yml file and creates Permission records.
  def self.create_default_permissions
    permissions = (RoleConstants::DEFAULT_PERMISSIONS + RoleConstants::CAREER_DEV_PERMISSIONS).uniq
    permissions.each do |permission_name|
      Permission.find_or_create_by(:name => permission_name)
    end
  end

  def self.exists_with_name?(name)
    self.all_permissions ||= Permission.pluck(:name)
    self.all_permissions.include?(name)
  end

  def self.create_permission!(name)
    return if Permission.find_by(name: name)
    Permission.create!(:name => name)
    if self.all_permissions.present?
      self.all_permissions |= [name]
    else
      self.all_permissions = Permission.pluck(:name)
    end
  end

  private

  # Checks whether the permission name is of proper format.
  def check_name_is_of_valid_format
    if not self.name =~ NAME_FORMAT
      self.errors.add(:name, "activerecord.custom_errors.permission.invalid".translate)
    end
  end
end
