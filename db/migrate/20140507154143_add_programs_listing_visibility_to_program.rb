class AddProgramsListingVisibilityToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :programs_listing_visibility, :integer, :default => Organization::ProgramsListingVisibility::ALL
  end
end
