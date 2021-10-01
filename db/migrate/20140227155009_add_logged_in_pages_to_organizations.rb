class AddLoggedInPagesToOrganizations< ActiveRecord::Migration[4.2]
  def change
    Program.where(allows_logged_in_pages: true).find_each{|p| p.enable_feature(FeatureName::LOGGED_IN_PAGES) }
  end
end
