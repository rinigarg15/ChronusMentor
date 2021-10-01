# == Schema Information
#
# Table name: features
#
#  id   :integer          not null, primary key
#  name :string(255)
#

class Feature < ActiveRecord::Base
  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------
  validates :name, :uniqueness => true

  has_many :organization_features, dependent: :destroy

  def self.create_default_features
    FeatureName.all.each do |name|
      Feature.find_or_create_by(:name => name)
    end
  end

  def self.handle_feature_dependency(prog_or_org)
    FeatureName.dependent_features.each_pair do |feature_name, enabled_disabled_config|
      if prog_or_org.has_feature?(feature_name)
        self.enable_disable_features(prog_or_org, enabled_disabled_config)
      end
    end
  end

  def self.handle_specific_feature_dependency(prog_or_org)
    FeatureName.specific_dependent_features.values.each do |enabled_disabled_config|
      self.enable_disable_features(prog_or_org, enabled_disabled_config)
    end

    # Handle default *handle_feature_dependency* if any of the enabled features have dependencies
    if (FeatureName.specific_dependent_features.values.collect{|val| val[:enabled]}.flatten.uniq & FeatureName.dependent_features.keys).any?
      Feature.handle_feature_dependency(prog_or_org)
    end
  end

  def self.enable_disable_features(prog_or_org, enabled_disabled_config)
    enabled_disabled_config.each_pair do |status, features_list|
      features_list.each do |feature_name|
        prog_or_org.enable_feature(feature_name, status == :enabled)
      end
    end
  end

  def self.generate_csv
    CSV.generate do |csv|
      header = ["Program ID", "Organization ID", "Active Org", "Program Name", "Organization Name", "Account Name"]
      Feature.all.each do |f|
        header << f.name
      end      
      csv << header
      Program.all.each do |p|
        subarray = [p.id, p.organization.id, p.organization.active, p.name, p.organization.name, p.organization.account_name]
        Feature.all.each do |f|
          subarray << p.has_feature?(f.name)
        end
        csv << subarray
        subarray = []
      end
      csv
    end
  end
end
