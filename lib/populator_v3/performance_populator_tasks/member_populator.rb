class MemberPopulator < PopulatorTask

  def patch(options = {})
    category = get_organization_category(@organization)
    members_count = @options[:org_node][category]["members_count"]
    add_remove_members_with_status(members_count, "Member::Status::ACTIVE")
    dormant_members_count = @options[:org_node][category]["dormant_members_count"]
    add_remove_members_with_status(dormant_members_count, "Member::Status::DORMANT") if dormant_members_count.present?
  end

  def add_members(org_id, obj_count, options = {})
    return if obj_count.zero?
    self.class.benchmark_wrapper "Member" do
      organization = Organization.find(org_id)
      chronus_auth_id = organization.chronus_auth.id
      count = organization.members.count + 1
      options.reverse_merge!(special_emails: true)
      subdomain = organization.subdomain
      all_tags_ids = ActsAsTaggableOn::Tag.pluck(:id)

      Member.populate(obj_count, per_query: 50_000) do |member|
        member.first_name = options[:last_name] || Faker::Name.first_name
        member.last_name = options[:first_name] || Faker::Name.last_name
        member.email = options[:email] || ("#{subdomain}_member#{count}#{(count <= 10) ? "" : "+minimal"}@chronus.com")
        member.organization_id = organization.id
        member.salt = 'da4b9237bacccdf19c0760cab7aec4a8359010b0'
        member.crypted_password = '688174433af60e1b89ecd9ed33022104bb6633e3'
        member.admin = false
        member.failed_login_attempts = false
        member.calendar_api_key = "#{member.first_name}#{count}#{self.class.random_string}"
        member.calendar_sync_count = 0
        member.api_key = "#{member.last_name}#{count}#{self.class.random_string}api"
        member.state = [options[:status].constantize]
        member.will_set_availability_slots = [true, true, true, true, true, true, true, true, true, true]
        member.password_updated_at = Time.now.utc
        member.availability_not_set_message = Populator.sentences(2..4) unless member.will_set_availability_slots
        member.created_at = organization.created_at...Time.now
        member.terms_and_conditions_accepted = member.created_at...Time.now

        LoginIdentifier.populate 1 do |login_identifier|
          login_identifier.auth_config_id = chronus_auth_id
          login_identifier.member_id = member.id
        end

        count += 1
        self.dot
      end
      self.class.display_populated_count(obj_count, "Member") unless obj_count.zero?
    end
  end

  def remove_members(org_id, count, options = {})
    self.class.benchmark_wrapper "Remove Members....." do
      organization = Organization.find(org_id)
      destroy_objects_with_progress_print(organization.members.where(state: options[:status]).last(count))
      self.class.display_deleted_count(count, "Member") unless count.zero?
    end
  end

  def add_remove_members_with_status(spec_count, status)
    difference = @organization.members.where("state = ?", status.constantize).count - spec_count
    difference > 0 ? remove_members(@organization.id, difference.abs, status: status) : add_members(@organization, difference.abs, status: status)
  end
end