class AddTypeToMentorRequests< ActiveRecord::Migration[4.2]
  def change
    add_column :mentor_requests, :type, :string, limit: UTF8MB4_VARCHAR_LIMIT, default: MentorRequest.to_s
  end
end
