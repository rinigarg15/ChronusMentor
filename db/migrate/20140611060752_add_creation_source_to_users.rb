class AddCreationSourceToUsers< ActiveRecord::Migration[4.2]
  def change
    add_column :users, :creation_source, :integer, default: User::CreationSource::UNKNOWN
  end
end
