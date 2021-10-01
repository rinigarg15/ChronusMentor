class GenericUserPopulator < PopulatorTask
  def add_users_with_state(member_ids, count, options = {})
    members = Member.where(id: member_ids).to_a
    members = members * count
    self.class.benchmark_wrapper "Users" do
      program = options[:program]
      User.populate member_ids.size * count do |user|
        member = members.shift
        user.program_id = program.id
        user.member_id = member.id
        user.max_connections_limit = 70..80
        user.created_at = 10.days.ago...Time.now
        user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
        user.last_program_update_sent_time = user.created_at
        user.group_notification_setting = UserConstants::DigestV2Setting::GroupUpdates::WEEKLY
        user.last_group_update_sent_time = user.created_at
        user.primary_home_tab = Program::RA_TABS::ALL_ACTIVITY
        user.state = (options[:state] == User::Status::PENDING ? User::Status::PENDING : ((member.state == Member::Status::SUSPENDED) ? User::Status::SUSPENDED : User::Status::ACTIVE))
        user.last_seen_at = user.created_at..Time.now
        self.dot
      end
      self.class.display_populated_count(member_ids.size * count, "Users")
    end
  end

  def remove_users_with_state(program, user_ids)
    program.users.where(:id => user_ids).destroy_all
  end
end