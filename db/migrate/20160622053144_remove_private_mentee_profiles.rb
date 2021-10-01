class RemovePrivateMenteeProfiles< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      remove_column :users, :private
      remove_column :programs, :default_profile_privacy
      Permission.find_by(name: "mark_profile_private").try(:destroy)
      Feature.where(name: "private_profiles").each do |feature|
        feature.destroy
      end
    end
  end

  def down
    ActiveRecord::Base.transaction do
      Permission.create!(:name => "mark_profile_private")
      add_column :users, :private, :boolean, default: false
      add_column :programs, :default_profile_privacy, :boolean, default: false
    end
  end
end
