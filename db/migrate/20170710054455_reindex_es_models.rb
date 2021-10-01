class ReindexEsModels< ActiveRecord::Migration[4.2]

  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("es_indexes:full_indexing MODELS='AbstractMessage,SurveyAnswer,ProjectRequest,ThreeSixty::SurveyAssessee'")
    end
  end

end