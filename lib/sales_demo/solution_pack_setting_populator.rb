module SalesDemo
  class SolutionPackSettingPopulator < BasePopulator

    attr_accessor :campaigns_hash

    def initialize(master_populator)
      self.master_populator = master_populator
    end

    def copy_data
      master_populator.referer_hash[:resource] = {}
      master_populator.referer_hash[:program].each do |key, value|
        program = Program.find(value)
        program.set_owner!
        zip_file_path = Rails.root + SalesPopulator::LOCATION + "solution_pack_#{key}.zip"
        update_features(key, program, zip_file_path)
        map_campaigns(key)
        FileUtils.rm_rf(Rails.root + SalesPopulator::LOCATION + "solution_pack_#{key}")
        SolutionPack.new(program: program, sales_demo_mapper: master_populator.referer_hash, is_sales_demo: true).import(zip_file_path, dump_location: Rails.root + SalesPopulator::LOCATION + "id_mappings.yml")
        master_populator.populate_solution_pack_id_mappings
        update_campaigns
      end
    end

    def update_features(key, program, zip_file_path)
      SolutionPack::ExportImportCommonUtils.unzip_file(zip_file_path, "solution_pack_#{key}/")
      features_path = Rails.root + SalesPopulator::LOCATION + "solution_pack_#{key}/" + SettingsImporter::FolderName + "features.csv"
      exported_feature_rows = CSV.read(features_path)
      features_for_enabling = exported_feature_rows[0]
      (FeatureName.organization_level_features & features_for_enabling).each do |feature|
        unless Feature.find_by(name: feature).nil?
          program.enable_feature(feature, true)
        end
      end
    end

    def map_campaigns(key)
      campaign_path = Rails.root + SalesPopulator::LOCATION + "solution_pack_#{key}/" + "campaign.csv"
      campaign_message_path = Rails.root + SalesPopulator::LOCATION + "solution_pack_#{key}/" + "campaign_message.csv"
      self.campaigns_hash = {"campaign" => {}, "campaign_message" => {}}
      {campaign_path => "campaign", campaign_message_path => "campaign_message"}.each do |path, key|
        CSV.foreach(path, {headers: true}) do |row|
          self.campaigns_hash[key][row["id"].to_i] = {created_at: row["created_at"], updated_at: row["updated_at"], type: row["type"]}
        end
      end
    end

    def update_campaigns
      {"CampaignManagement::AbstractCampaign" => "campaign", "CampaignManagement::AbstractCampaignMessage" => "campaign_message"}.each do |model, key|
        self.campaigns_hash[key].each do |k, original_values|
          original_values[:type].constantize.where(id: self.master_populator.solution_pack_referer_hash[model][k]).update_all(created_at: self.modify_date(original_values[:created_at]), updated_at: self.modify_date(original_values[:updated_at]))
        end
      end
    end
  end
end