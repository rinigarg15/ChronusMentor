class AddThresholdToMatchConfig< ActiveRecord::Migration[4.2]
  def change
    add_column :match_configs, :threshold, :float, default: 0.0
  end
end
