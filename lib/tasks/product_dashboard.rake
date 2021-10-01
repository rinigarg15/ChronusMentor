namespace :product_dashboard do
  desc "Update the data in product dashboard google spreadsheet"
  task update: :environment  do
    dashboard = ProductDashboard.new
    dashboard.update if dashboard.allowed_for_env
  end

  desc "Update the account names in product dashboard google spreadsheet"
  task update_account_names: :environment  do
    dashboard = ProductDashboard.new
    dashboard.update(account_names: true) if dashboard.allowed_for_env
  end
end