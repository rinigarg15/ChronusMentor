class AddDefaultAlertsToManagementReport< ActiveRecord::Migration[4.2]
  def change
    Program.find_each do |program|
      program.create_default_alerts_for_program_management_report
    end
  end
end