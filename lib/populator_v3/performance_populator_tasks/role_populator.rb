class RolePopulator < PopulatorTask
  def self.add_roles(user_ids, count, options = {}, role)
    benchmark_wrapper "Role" do
      user_ids = user_ids.first(count)
      RoleReference.populate user_ids.size do |role_reference|
        role_reference.role_id = role.id
        role_reference.ref_obj_type = User.to_s
        role_reference.ref_obj_id = user_ids.first
        user_ids = user_ids.rotate
        dot
      end
      display_populated_count(count, "Role")
    end
  end

  def remove_roles(member_ids, count, options = {})    
  end
end