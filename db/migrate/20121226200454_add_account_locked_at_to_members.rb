class AddAccountLockedAtToMembers< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      add_column :members, :account_locked_at, :datetime
      add_column :members, :password_updated_at, :datetime
      # Organization.active.each do |org|
      #   puts "Populating password_updated_at for #{org.name}...."
      #   org.members.each do |member|
      #     unless member.auth_config && member.auth_config.requires_login_name?
      #       begin
      #         member.update_password_timestamp!
      #       rescue
      #         puts "Check member_id - #{Rails.env.to_s} - #{member.id}"
      #       end
      #     end
      #   end
      # end
    end
  end

  def down
    remove_column :members, :account_locked_at
    remove_column :members, :password_updated_at
  end
end