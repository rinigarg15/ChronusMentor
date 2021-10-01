class AddOperatorToMatchConfigs< ActiveRecord::Migration[4.2]
  def change
    add_column :match_configs, :operator, :string, null: false, default: 'lt'
  end
end
