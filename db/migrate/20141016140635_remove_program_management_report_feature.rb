class RemoveProgramManagementReportFeature< ActiveRecord::Migration[4.2]
  def up
  	feature = Feature.find_by(name: "program_management_report")
    feature.destroy if feature.present?
  end

  def down
  	Feature.create!(name: "program_management_report")
  end
end
