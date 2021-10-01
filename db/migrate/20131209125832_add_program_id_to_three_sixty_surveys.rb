class AddProgramIdToThreeSixtySurveys< ActiveRecord::Migration[4.2]
  def up
    add_column :three_sixty_surveys, :program_id, :integer
    add_index :three_sixty_surveys, :program_id

    Organization.active.each do |org|
      next unless org.standalone?
      org.three_sixty_surveys.each do |survey|
        survey.update_attribute(:program_id, org.programs.first.id)
      end
    end
  end

  def down
    remove_index :three_sixty_surveys, :program_id
    remove_column :three_sixty_surveys, :program_id
  end
end
