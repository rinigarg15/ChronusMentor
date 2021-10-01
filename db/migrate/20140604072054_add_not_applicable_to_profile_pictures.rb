class AddNotApplicableToProfilePictures< ActiveRecord::Migration[4.2]
  def change
    add_column :profile_pictures, :not_applicable, :boolean, :default => false
  end
end
