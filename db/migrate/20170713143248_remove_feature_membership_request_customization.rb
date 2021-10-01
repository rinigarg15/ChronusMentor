class RemoveFeatureMembershipRequestCustomization< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration do
      Feature.find_by(name: "membership_request_customization").try(:destroy)
    end
  end

  def down
    ChronusMigrate.data_migration do
      Feature.create!(name: "membership_request_customization")
    end
  end
end
