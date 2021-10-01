module ChronusTranslations
  class Engine < ::Rails::Engine
    initializer "chronus_translations.load_app_instance_data" do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
  end
end
