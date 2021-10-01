class EnableExecutiveSummaryReportFeature< ActiveRecord::Migration[4.2]
  def change
    Program.all.each do |program|
      program.enable_feature(FeatureName::EXECUTIVE_SUMMARY_REPORT)
    end
    Organization.all.each do |organization|
      organization.enable_feature(FeatureName::EXECUTIVE_SUMMARY_REPORT)
    end
  end
end
