class ModifyOpensslConfig< ActiveRecord::Migration[4.2]
  def up
    # AuthConfig.where(:auth_type => AuthConfig::Type::OPENSSL).each do |ac|
    #   ac.config = Base64.encode64(ac.config)
    #   ac.save!
    # end
  end

  def down
  end
end
