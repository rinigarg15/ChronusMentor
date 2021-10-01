class CreateDefaultProgramGroupView< ActiveRecord::Migration[4.2]
  def change
    Program.active.each do |program|
      Program.create_default_group_view(program.id)
      puts "Default Group View for #{program.name} created."
    end
  end
end
