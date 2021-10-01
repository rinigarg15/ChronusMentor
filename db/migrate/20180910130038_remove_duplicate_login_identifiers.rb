class RemoveDuplicateLoginIdentifiers < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      distinct_ids = LoginIdentifier.select("MIN(id) as id").group(:member_id,:auth_config_id).pluck(:id)
      LoginIdentifier.where.not(id: distinct_ids).destroy_all
    end
  end

  def down
  end
end
