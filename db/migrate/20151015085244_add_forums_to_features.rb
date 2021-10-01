class AddForumsToFeatures< ActiveRecord::Migration[4.2]
  def change
    if Feature.count > 0
      Feature.create_default_features
      Program.active.each do |program|
        if program.organization.standalone?
          organization = program.organization
          organization.enable_feature(FeatureName::FORUMS, true)
        else
          program.enable_feature(FeatureName::FORUMS, true)
        end
      end
    end
  end
end
