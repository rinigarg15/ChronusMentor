class AddLastUpdateSentTimeToConnectionMemberships< ActiveRecord::Migration[4.2]
  def change
    add_column :connection_memberships, :last_update_sent_time, :datetime, :default => Time.now
  end
end
