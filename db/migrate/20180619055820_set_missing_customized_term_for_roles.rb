class SetMissingCustomizedTermForRoles < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      ActiveRecord::Base.transaction do
        Role.includes(:customized_term).all.each do |role|
          role.set_default_customized_term
        end
      end
    end
  end

  def down
  end
end
