 # InstanceMigrator::S3AssetsCollector.new.collect_s3_assets

module InstanceMigrator
  class S3AssetsCollector
    include OrganizationData::S3AssetsCollectionExtensions
    attr_accessor :s3_asset_file_path

    def initialize(s3_asset_file_path = nil)
      self.s3_asset_file_path = s3_asset_file_path || File.join(Rails.root, "tmp/s3_assets_file.csv")
    end

    def collect_s3_assets
      ApplicationEagerLoader.load
      s3_asset_collect_csv = CSV.open(self.s3_asset_file_path, "w")
      ActiveRecord::Base.descendants.each do |model|
        OrganizationData::S3AssetsCollectionExtensions.collect_s3_assets_for_model(model, [], OrganizationData::TargetCollection::OPERATION::COLLECT_S3_ASSETS, s3_asset_collect_csv)
      end
      s3_asset_collect_csv.close
    end
  end
end