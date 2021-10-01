class MembershipRequestPopulator < PopulatorTask
  def patch(options = {})
    program_ids = @organization.program_ids
    membership_requests_hsh = get_children_hash(nil, @options[:args]['model'] || @node, @foreign_key, program_ids)
    process_patch(program_ids, membership_requests_hsh)
  end

  def add_membership_requests(program_ids, count, options = {})
    self.class.benchmark_wrapper 'Membership Requests' do
      programs = Program.where(id: program_ids)
      total_membership_requests_created = 0
      programs.each do |program|
        member_ids_in_program = program.all_users.pluck(:member_id)
        members_not_in_program = program.organization.members.non_suspended.where.not(id: member_ids_in_program)
        count = [count, members_not_in_program.size].min
        roles = program.roles.non_administrative.to_a
        membership_count = 0
        admin_user = program.admin_users.first
        MembershipRequest.populate(count, per_query: 50_000) do |membership_request|
          member = members_not_in_program[membership_count]
          membership_request.first_name = member.first_name
          membership_request.last_name = member.last_name
          membership_request.email = member.email
          membership_request.member_id = member.id
          membership_request.program_id = program.id
          membership_request.status = [MembershipRequest::Status::UNREAD, MembershipRequest::Status::REJECTED].sample
          membership_request.response_text = (membership_request.status == MembershipRequest::Status::REJECTED) ? Populator.sentences(3..6) : nil
          membership_request.admin_id = (membership_request.status == MembershipRequest::Status::REJECTED) ? admin_user.id : nil

          role = roles.first
          roles.rotate!
          membership_request.joined_directly = false
          RoleReference.populate 1 do |role_reference|
            role_reference.role_id = role.id
            role_reference.ref_obj_type = MembershipRequest.name
            role_reference.ref_obj_id = membership_request.id
          end
          membership_count += 1
          self.dot
        end
        total_membership_requests_created += membership_count
      end
      self.class.display_populated_count(total_membership_requests_created, 'Membership Requests')
    end
  end

  def remove_membership_requests(program_ids, count, options = {})
    self.class.benchmark_wrapper 'Removing Membership Request................' do
      program_id_membership_requests_hash = MembershipRequest.where(program_id: program_ids).select(:id, :program_id).group_by(&:program_id)
      membership_requests_ids = program_id_membership_requests_hash.collect { |_, membership_requests| membership_requests.last(count).collect(&:id) }.flatten
      MembershipRequest.where(id: membership_requests_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, 'Membership Requests')
    end
  end
end
