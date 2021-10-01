class RemovePublicMentorsListing< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :public_mentors_listing
  end

  def down
    add_column :programs, :public_mentors_listing, :boolean
  end
end
