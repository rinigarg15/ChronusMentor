class AddBrowserWarningShownAtToMember< ActiveRecord::Migration[4.2]
  def change
    add_column :members, :browser_warning_shown_at, :datetime
  end
end
