class AddEditModeToSurvey< ActiveRecord::Migration[4.2]
  def change
    add_column :surveys, :edit_mode, :integer
    Survey.unscoped.update_all(:edit_mode => Survey::EditMode::MULTIRESPONSE) # Set all existing (Program) surveys to MultiResponse mode
  end
end
