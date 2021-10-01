class RemoveRejectReasonFromMentorRequest< ActiveRecord::Migration[4.2]
  def change
    if AbstractRequest.column_names.include?("reject_reason")
      remove_column :mentor_requests, :reject_reason
    end
  end
end
