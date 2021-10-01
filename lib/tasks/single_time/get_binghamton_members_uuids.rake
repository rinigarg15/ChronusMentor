namespace :single_time do
  #usage: bundle exec rake single_time:get_binghamton_members_uuids
  task get_binghamton_members_uuids: :environment do
    Common::RakeModule::Utils.execute_task do
      file = "#{Rails.root}/tmp/member_data.csv"
      programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])
      program = programs.first
      saml_auth = organization.saml_auth
      roles_scope = RoleReference.joins(:role).select(['ref_obj_id as user_id', 'role_id']).where(roles: {program_id: program.id}, ref_obj_type: User.name)
      users_roles = RoleReference.connection.select_all(roles_scope)
      customized_terms = CustomizedTerm.where(ref_obj_type: Role.name, ref_obj_id: program.role_ids).includes(:translations).index_by(&:ref_obj_id)
      user_role_hash = {}
      users_roles.each do |user_role|
        user_id, role_id = user_role['user_id'], user_role['role_id']
        user_role_hash[user_id] ||= []
        user_role_hash[user_id] << customized_terms[role_id].term
        user_role_hash[user_id] = user_role_hash[user_id].sort
        user_role_hash
      end
      column_headers = ["Member ID", "First Name", "Last Name", "Email", "Roles in #{program.name}", "UUID"]
      CSV.open(file, 'w', write_headers: true, headers: column_headers) do |writer|
        Member.where(organization_id: organization.id).includes(:login_identifiers, :users).each do |member|
          user = member.users.find{|user| user.program_id == program.id }
          login_identifier = member.login_identifiers.find{|lid| lid.auth_config_id == saml_auth.try(:id)}
          writer << [member.id, member.first_name, member.last_name, member.email, (user_role_hash[user.try(:id)] || []).join(","), login_identifier.try(:identifier)]
        end
      end
    end
  end
end
