class MentoringTipAsFeature< ActiveRecord::Migration[4.2]
  def change
    if Feature.count > 0
      Feature.create_default_features
    end
    Organization.all.each do |organization|
      organization.enable_feature(FeatureName::MENTORING_INSIGHTS)
    end
  end
end
