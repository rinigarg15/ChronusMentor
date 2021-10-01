class AddEngagementTypeToPrograms< ActiveRecord::Migration[4.2]
  def up
    add_column :programs, :engagement_type, :integer

    Program.reset_column_information
    Program.find_each do |prog|
      prog.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    end
  end

  def down
    remove_column :programs, :engagement_type
  end
end
