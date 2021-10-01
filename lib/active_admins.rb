module ActiveAdmins
  def pull_active_admins_in_csv(active_admins_csv)
    get_admins_in_csv(pull_active_admins, active_admins_csv)
  end

  def pull_active_admins
    admins = []
    org_members_hash = Member.where(admin: true).includes(organization: [:programs]).group_by(&:organization)
    org_members_hash.each do |org, members_arr|
      next unless org.active?
      admins << members_arr
      admins << User.joins(role_references: :role).
          where(roles: {program_id: org.program_ids, administrative: true}).
          # reject global admins in program admins list
          where.not(users: {member_id: members_arr.collect(&:id)}).
          includes({program: [:organization, :translations]}, :member).
          order("users.last_seen_at DESC").group_by(&:member_id).
          collect{|k,v| v[0]}
    end
    get_admins_display_hash(admins.flatten.compact)
  end

  def get_admins_in_csv(admins, active_admins_csv = nil)
    generate_admins_csv(active_admins_csv) do |csv|
      csv << [
          "feature.admin_view.program_defaults.title.Account_Name".translate,
          "feature.admin_view.program_defaults.title.Organization".translate,
          "feature.admin_view.program_defaults.title.organization_url".translate,
          "feature.admin_view.program_defaults.title.Programs".translate,
          "feature.admin_view.program_defaults.title.last_active_program_url".translate,
          "feature.admin_view.program_defaults.title.first_name".translate,
          "feature.admin_view.program_defaults.title.last_name".translate,
          "feature.admin_view.program_defaults.title.email".translate,
          "feature.admin_view.program_defaults.title.created_at".translate
        ]

      admins.each do |display_hash|
        csv_array = []
        csv_array << display_hash[:account_name]
        csv_array << display_hash[:org_name]
        csv_array << display_hash[:org_url]
        csv_array << display_hash[:program_name]
        csv_array << display_hash[:program_url]
        csv_array << display_hash[:first_name]
        csv_array << display_hash[:last_name]
        csv_array << display_hash[:email]
        csv_array << display_hash[:created_at]
        csv << csv_array
      end
    end
  end

  private

  def get_admins_display_hash(admins = [])
    admins.collect do |admin|
      get_admin_display_hash(admin)
    end
  end

  def get_admin_display_hash(admin)
    org = admin.is_a?(Member) ? admin.organization : admin.program.organization
    program = admin.is_a?(Member) ? admin.most_recent_user.try(:program) : admin.program
    program_root = program.try(:root)
    program_name = admin.is_a?(Member) ? "display_string.All".translate : program.name
    program_url = Rails.application.routes.url_helpers.program_root_url(get_common_url_options(org).merge(root: program_root)) if program_root
    {
      account_name: org.account_name,
      org_name: org.name,
      org_url: Rails.application.routes.url_helpers.root_organization_url(get_common_url_options(org)),
      program_name: program_name,
      program_url: program_url,
      first_name: admin.first_name,
      last_name: admin.last_name,
      email: admin.email,
      created_at: DateTime.localize(admin.created_at, format: :full_display_no_time)

    }
  end

  def get_common_url_options(organization)
    {
      subdomain: organization.subdomain,
      host: organization.domain,
      protocol: organization.get_protocol
    }
  end

  def generate_admins_csv(active_admins_csv = nil)
    if active_admins_csv
      CSV.open(active_admins_csv, "w") do |csv|
        yield csv
      end
    else
      CSV.generate do |csv|
        yield csv
      end
    end
  end
end