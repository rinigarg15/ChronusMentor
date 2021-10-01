class RemoveActionControllerParametersFromDb < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      [
        [AdminView, "filter_params"],
        [Report::Alert, "filter_params"],
        [UserCsvImport, "info"],
        [CampaignManagement::UserCampaign, "trigger_params"]
      ].each do |klass, attr|
        objects = klass.where("#{attr} LIKE '%ActionController::Parameters%'")
        objects.find_each do |object|
          attr_value = object.send(attr)
          if klass == CampaignManagement::UserCampaign
            attr_value = attr_value.to_unsafe_h
          else
            attr_value = YAML.load(attr_value)
            attr_value = ActionController::Parameters.new(attr_value) if attr_value.is_a?(Hash)
            attr_value = attr_value.to_unsafe_h
            attr_value = klass.is_a?(AdminView) ? AdminView.convert_to_yaml(attr_value) : attr_value.to_yaml
          end
          object.send("#{attr}=", attr_value)
          object.save!
        end
      end
    end
  end

  def down
    # do nothing
  end
end