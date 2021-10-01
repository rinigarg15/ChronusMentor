class AddMatchConfigForMentoringTopics< ActiveRecord::Migration[4.2]
  def up
  	Program.active.select("programs.id, programs.parent_id").each do |program|
  		program.match_configs.create!(:is_profile_field => false, :weight => 0.0)
  	end
  end

  def down     
  end
end
