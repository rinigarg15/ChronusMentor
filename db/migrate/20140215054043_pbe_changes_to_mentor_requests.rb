class PbeChangesToMentorRequests< ActiveRecord::Migration[4.2]
  def change
    change_table :mentor_requests do |t|
      t.rename :student_id, :sender_id
      t.rename :mentor_id, :receiver_id
      t.integer :sender_role_id

      t.index [:sender_id, :type]
      t.index [:receiver_id, :type]
      t.index :sender_role_id
    end
  end
end
