class CreateMatchSettingsForPrograms< ActiveRecord::Migration[4.2]
  def up
    Program.all.each do |program|
      Program.create_default_match_setting!(program.id)
    end
  end

  def down
  end
end