class AddLoginRequiredToCkeditorAssets< ActiveRecord::Migration[4.2]
  def up
    add_column :ckeditor_assets, :login_required, :boolean, default: false
  end

  def down
    remove_column :ckeditor_assets, :login_required
  end
end