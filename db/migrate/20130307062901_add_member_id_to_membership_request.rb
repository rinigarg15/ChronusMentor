class AddMemberIdToMembershipRequest< ActiveRecord::Migration[4.2]
  def change
    add_column :membership_requests, :member_id, :integer
    ActiveRecord::Base.connection.execute("update membership_requests m, users u set m.member_id = u.member_id where m.creator_id = u.id")
  end
end
