class RemoveUnusedAuthentication< ActiveRecord::Migration[4.2]
  def up
    # AuthConfig.where(auth_type: ["SoapAuth", "APIAuth", "URLEncryptionAuth", "OPENAMAuth"]).destroy_all
  end

  def down
    # No down migration
  end
end
