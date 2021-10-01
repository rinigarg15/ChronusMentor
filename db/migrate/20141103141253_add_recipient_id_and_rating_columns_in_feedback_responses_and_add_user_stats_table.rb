class AddRecipientIdAndRatingColumnsInFeedbackResponsesAndAddUserStatsTable< ActiveRecord::Migration[4.2]
  def change
    add_column :feedback_responses, :recipient_id, :integer
    add_column :feedback_responses, :rating, :float, :default => 0.5
    change_column :feedback_responses, :user_id, :integer, :null => true
    change_column :feedback_responses, :group_id, :integer, :null => true

    add_index "feedback_responses", ["recipient_id"]

    create_table "user_stats", :force => true do |t|
      t.integer "user_id"
      t.float "average_rating", :default => 0.5
      t.integer "rating_count", :default => 0
      t.string SOURCE_AUDIT_KEY.to_sym, :limit => UTF8MB4_VARCHAR_LIMIT
    end

    add_index "user_stats", ["user_id"]
  end
end
