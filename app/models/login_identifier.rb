class LoginIdentifier < ActiveRecord::Base

  belongs_to :member
  belongs_to :auth_config

  validates :member, :auth_config_id, presence: true
  validates :auth_config_id, uniqueness: { scope: :member_id }
  validates :identifier, presence: true, uniqueness: { scope: :auth_config_id, case_sensitive: false }, if: Proc.new { |login_identifier| login_identifier.auth_config.try(:non_indigenous?) }
end