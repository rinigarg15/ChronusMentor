class RevokeFeatureStatusMultipleTemplates< ActiveRecord::Migration[4.2]
  def up
    feature = Feature.find_by(name: "multiple_templates")
    feature.destroy if feature.present?
  end

  def down
    Feature.create!(name: "multiple_templates")
    ## Not handling the case of repopulating the organization_features
  end
end
