namespace :single_time do
  #usage: bundle exec rake single_time:remove_duplicated_role_references
  desc "Maintaining uniqueness of the triplet: {role_id, ref_obj_id, ref_obj_type}"
  task remove_duplicated_role_references: :environment do
    role_reference_ids = ENV['IDS'].split(',')
    role_reference_ids.each do |id|
      role_reference = RoleReference.find(id)
      if RoleReference.where(role_id: role_reference.role_id, ref_obj_id: role_reference.ref_obj_id, ref_obj_type: role_reference.ref_obj_type).where.not(id: id).exists?
        role_reference.destroy
        puts "RoleReference with id: #{id} removed!"
      end
    end
    puts "Done!"
  end
end
