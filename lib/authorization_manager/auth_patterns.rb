# = Chronus Authorization module
#
# Provides support for role based authorization. Defines extensions to user,
# program and other relevant models for easy and efficient management of roles
# and permissions.
#
# The following dynamic methods are provided:
#   user.is_<role_name>?            => user.is_student?, user.is_mentor?
#   user.is_<role_1>_or_<rol_2>..?  => user.is_admin_or_mentor?, user.is_student_or_mentor?
#   user.is_<role_1>_and_<rol_2>..?  => user.is_admin_and_mentor?, user.is_student_and_mentor?
#   user.add_<role_name>_role       => user.add_admin_role
#   user.remove_<role_name>_role    => user.remove_admin_role
#   program.<role_name>_users       => program.mentor_users, program.admin_users
#
# Following is an overview of the authorization model hierarchy. (Note that the
# model and other relations in this hierarchy might change over time)
#
# === Models
# ==== Permission
# * name
#
# ===== Role
# * name
# * program_id
#
# ===== RolePermission
# * role_id
# * permission_id
#
# ===== RoleReference
# * ref_obj (polymorphic)
# * role_id
#
# ==== Notification
# (each record identifies an email sent through the program)
# * name
#
# ==== RoleNotification
# * role_id
# * notification_id
#
# === Relations
# * Program HAS_MANY Roles
# * Role HAS_MANY Permissions THROUGH RolePermissions
# * Permission HAS_MANY Roles THROUGH RolePermissions
# * User HAS_MANY Roles THROUGH RoleReferences
# * Role HAS_MANY Users THROUGH RoleReferences
# * Role HAS_MANY Notifications THROUGH RoleNotifications
#
# Author :: Vikram Venkatesan
#

require File.dirname(__FILE__) + '/exceptions'
require File.dirname(__FILE__) + '/user_extensions'
require File.dirname(__FILE__) + '/program_extensions'

module AuthorizationManager
  # Method patterns to define using 'method_missing'.
  #
  # Note that the patterns are in the order of *specificity*, which means, the
  # 'n'th pattern *might* also match (n-1)th pattern.
  module AuthPatterns
    HAS_ONLY_ROLE     = /^is_(.*)_only\?$/            # is_<role_1>_only?
    HAS_ANY_ROLE      = /^is_((.*)((_or_)(.*))+)\?$/   # is_<role_1>_or_<role_2>?
    HAS_ALL_ROLES     = /^is_((.*)((_and_)(.*))+)\?$/  # is_<role_1>_and_<role_2>?
    HAS_SINGLE_ROLE   = /^is_(.*)\?$/                 # is_<role_name>?
    HAS_PERMISSION    = /^can_(.*)\?$/                # can_<permission_name>?
    ROLE_USERS        = /^(.*)_users$/                # <role_name>_users
  end
end
