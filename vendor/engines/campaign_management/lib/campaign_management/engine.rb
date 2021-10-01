module CampaignManagement
  class Engine < ::Rails::Engine
    config.eager_load_paths += ["#{config.root}/lib"]
    initializer "campaign_management.load_app_instance_data" do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    initializer "campaign_management.action_controller" do |app|
      ActiveSupport.on_load :action_controller do
        helper CampaignManagement::CampaignsHelper
      end
    end

    initializer "campaign_management.locales" do |app|
      CampaignManagement::Engine.config.i18n.load_path += Dir[root.join("locales", "*.{rb,yml}").to_s]
    end
  end
end