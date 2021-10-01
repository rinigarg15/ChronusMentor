class AddNameProfileAndRoleQuestion< ActiveRecord::Migration[4.2]
  def up
  	ActiveRecord::Base.transaction do
      Organization.active.includes(:programs).each do |org|
        prof_q = org.create_default_name_profile_question!
        org.programs.each do |prog|
        	prog.create_default_name_role_question!(prof_q)
        end
      end
    end
  end

  def down
  end
end
