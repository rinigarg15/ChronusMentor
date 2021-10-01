class RemoveOpenIdAuthentication< ActiveRecord::Migration[4.2]
  def up
    # AuthConfig.where(auth_type: "OpenIDAuth").each do |auth|
    #   org = auth.organization
    #   chronus_auth = org.auth_configs.indigenous_auths.last
    #   org.members.where(auth_config_id: auth.id).update_all(auth_config_id: chronus_auth.id)
    #   auth.destroy
    # end
    drop_table :open_id_authentication_associations
    drop_table :open_id_authentication_nonces
  end

  def down
    create_table :open_id_authentication_associations do |t|
      t.integer :issued
      t.integer :lifetime
      t.string  :handle
      t.string  :assoc_type
      t.binary  :server_url
      t.binary  :secret
    end

    create_table :open_id_authentication_nonces do |t|
      t.integer :timestamp, null: false
      t.string  :server_url
      t.string  :salt, null: false
    end
  end
end
