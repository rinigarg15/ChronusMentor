class AddActionTypeColumnToRolloutEmail< ActiveRecord::Migration[4.2]
  def change
    add_column :rollout_emails, :action_type, :integer, default: RolloutEmail::ActionType::NONE 
  end
end
