class CreateIndividualProgramAssets< ActiveRecord::Migration[4.2]
  def up
    Organization.active.each do |organization|
      Organization.clone_program_asset!(organization.id) if organization.program_asset.present? && !organization.standalone?
    end
  end

  def down
  end
end
