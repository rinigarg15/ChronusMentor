class AddFavouriteColumntoAdminView< ActiveRecord::Migration[4.2]
  def up
    add_column :admin_views, :favourite, :boolean, default: false
    add_column :admin_views, :favourited_at, :datetime
    AdminView.reset_column_information
    default_admin_views = [AbstractView::DefaultType::MENTORS, AbstractView::DefaultType::MENTEES, AbstractView::DefaultType::ALL_ADMINS, AbstractView::DefaultType::ALL_USERS, AbstractView::DefaultType::ALL_MEMBERS]
    AdminView.where(:default_view => default_admin_views).each do |admin_view|
      admin_view.update_attributes!(:favourite => true, :favourited_at => admin_view.created_at)
    end
  end

  def down
    remove_column :admin_views, :favourite
    remove_column :admin_views, :favourited_at
  end
end
