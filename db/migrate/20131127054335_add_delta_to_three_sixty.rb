class AddDeltaToThreeSixty< ActiveRecord::Migration[4.2]
  def change
    add_column :three_sixty_surveys, :delta, :boolean, :default => false
    add_column :three_sixty_survey_assessees, :delta, :boolean, :default => false
  end
end
