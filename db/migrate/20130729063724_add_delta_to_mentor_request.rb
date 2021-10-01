class AddDeltaToMentorRequest< ActiveRecord::Migration[4.2]
  def change
    add_column :mentor_requests, :delta, :boolean, :default => false
  end
end
