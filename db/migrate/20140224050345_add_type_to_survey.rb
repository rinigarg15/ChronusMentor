class AddTypeToSurvey< ActiveRecord::Migration[4.2]
  def change
    add_column :surveys, :type, :string
    Survey.unscoped.reset_column_information
    Survey.unscoped.update_all(:type => ProgramSurvey.name)
    EngagementSurvey.name #To load the class in development & test env
  end
end
