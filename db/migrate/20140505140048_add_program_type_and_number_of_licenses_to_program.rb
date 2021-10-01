class AddProgramTypeAndNumberOfLicensesToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :program_type, :string
    add_column :programs, :number_of_licenses, :integer
  end
end
