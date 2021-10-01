class RemoveMeetingFeedbacks< ActiveRecord::Migration[4.2]
  def up
    drop_table :meeting_feedbacks
  end

  def down
    create_table :meeting_feedbacks do |t|
      t.integer  :member_meeting_id
      t.text     :body
      t.datetime :meeting_occurrence_time
      t.timestamps null: false
    end
    add_index :meeting_feedbacks, :member_meeting_id
    add_index :meeting_feedbacks, :meeting_occurrence_time
  end
end