class RemoveAdminPendingMembershipEmailMailerTemplate < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration do
      Mailer::Template.where(uid: 'g29625j6').destroy_all # admin_pending_membership_requests.rb
    end
  end

  def down
  end
end
