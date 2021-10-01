module PopulatorTaskUtils
  def create_tags!(klass, object, context, tag_count, tag_ids)
    selected_tag_ids = tag_ids.sample(tag_count)
    ActsAsTaggableOn::Tagging.populate selected_tag_ids.count do |tagging|
      tagging.taggable_id = object.id
      tagging.taggable_type = klass.to_s
      tagging.context = context
      tagging.tag_id = selected_tag_ids.shift
    end
  end

  def get_organization_category(organization)
    organization.subdomain.gsub(/[^a-z]/, '')
  end

  def populate_group_mentoring(program, group_count, mentor_count, mentee_count)
    self.class.benchmark_wrapper "Group Mentoring" do
      mentor_role_ids = program.roles.with_name([RoleConstants::MENTOR_NAME]).pluck(:id)
      mentee_role_ids = program.roles.with_name([RoleConstants::MENTOR_NAME]).pluck(:id)
      mentoring_model_ids = program.mentoring_models.pluck(:id) * group_count
      mentor_users = program.users.select{|user| user.is_mentor?}.sample(mentor_count * group_count)
      mentee_users = program.users.select{|user| user.is_student?}

      mentee_available =  Hash.new {|h,k| h[k] = Hash.new }
      mentee_users.each do |mentee|
        mentor_users.each do |mentor|
          mentee_available[mentor][mentee] = Group.involving(mentee, mentor).size.zero?
        end
      end

      Group.populate group_count do |group|
        group.program_id = program.id
        group.created_at = program.created_at
        group.published_at = group.created_at
        group.name = "Mentoring Group - #{self.class.random_string}"
        group.mentoring_model_id = mentoring_model_ids.shift
        group.status = Group::Status::ACTIVE
        group.version = 1
        group.expiry_time = group.created_at + (program.mentoring_period / 1.day).days

        temp_mentees = []
        selected_mentor_users = mentor_users.shift(mentor_count)
        selected_mentee_users = mentee_users.shift(mentee_count)

        selected_mentee_users.size.times do
          mentee = selected_mentee_users.first
          return if mentee.nil?
          selected_mentee_users = selected_mentee_users.rotate
          valid_mentor_mentee_pair = false
          selected_mentor_users.size.times do
            mentor = selected_mentor_users.first
            selected_mentor_users = selected_mentor_users.rotate
            if Group.involving(mentee, mentor).size.zero? && mentee_available[mentor][mentee]
              temp_mentees.push(mentee)
              valid_mentor_mentee_pair = true
              mentee_available[mentor][mentee] = false
              break;
            end
          end
        end
        mentor_user_ids = selected_mentor_users.collect(&:id)

        return if (mentor_user_ids.size == 0 || temp_mentees.size == 0)
        #populate mentor membership
        Connection::Membership.populate mentor_user_ids.size do |membership|
          membership.user_id = mentor_user_ids.shift
          membership.group_id = group.id
          membership.type = Connection::MentorMembership.to_s
          membership.status = Connection::Membership::Status::ACTIVE
          membership.role_id = mentor_role_ids.sample
          membership.login_count = rand(10)
          membership.api_token = "#{membership.id}#{self.class.random_string}"
          self.class.dot
        end

        #populate mentee membership
        Connection::Membership.populate temp_mentees.size do |membership|
          temp_mentee = temp_mentees.shift
          next if temp_mentee.nil?
          membership.user_id = temp_mentee.id
          membership.group_id = group.id
          membership.type = Connection::MenteeMembership.to_s
          membership.status = Connection::Membership::Status::ACTIVE
          membership.role_id = mentee_role_ids.sample
          membership.login_count = rand(10)
          membership.api_token = "#{membership.id}#{self.class.random_string}"
          self.class.dot
        end
      end
      self.class.display_populated_count(mentor_count + mentee_count , "Group Member")
    end
  end

  def copy_group_permissions(group_ids)
    groups = Group.includes(mentoring_model:[:translations], program:[roles:[:translations]]).where(id: group_ids)
    groups.to_a.flatten.each{|group| group.copy_object_role_permissions_from!(group.mentoring_model, roles: group.program.roles)}
  end

  def create_recurring_meetings(populator_meeting, group)
    meeting = Meeting.new(populator_meeting.attributes)
    if group.nil?
      meeting.schedule_rule = Meeting::Repeats::DAILY
      meeting.repeats_end_date = meeting.start_time
    else
      meeting_rule_sample_set = 7.times.map { Meeting::Repeats::DAILY } + 2.times.map { Meeting::Repeats::WEEKLY } + 2.times.map { Meeting::Repeats::MONTHLY }
      meeting.schedule_rule = meeting_rule_sample_set.sample
      meeting.repeats_on_week = [(0..6).to_a.sample] if meeting.schedule_rule == Meeting::Repeats::WEEKLY
      meeting.repeats_by_month_date = %w(true false).sample if meeting.schedule_rule == Meeting::Repeats::MONTHLY
      meeting.repeats_end_date = group.expiry_time
      meeting_repeat_every_sample_set = 2.times.map { 1 } + 2.times.map { 2 } + 2.times.map { 3 }
      meeting.repeat_every = meeting_repeat_every_sample_set.sample
      meeting.recurrent = true
    end
    meeting.update_schedule
    meeting.schedule.to_yaml
  end

  def get_member_meeting_status(member_id, meeting, meeting_request)
    is_owner = (meeting.owner_id == member_id)
    if meeting_request
      case meeting_request.status
      when AbstractRequest::Status::WITHDRAWN
        is_owner ? MemberMeeting::ATTENDING::NO : MemberMeeting::ATTENDING::NO_RESPONSE
      when AbstractRequest::Status::REJECTED
        is_owner ? MemberMeeting::ATTENDING::YES : MemberMeeting::ATTENDING::NO
      when AbstractRequest::Status::ACCEPTED
        MemberMeeting::ATTENDING::YES
      when AbstractRequest::Status::NOT_ANSWERED
        is_owner ? MemberMeeting::ATTENDING::YES : MemberMeeting::ATTENDING::NO_RESPONSE
      end
    elsif is_owner
      MemberMeeting::ATTENDING::YES
    else
      [MemberMeeting::ATTENDING::NO_RESPONSE]*3 + [MemberMeeting::ATTENDING::YES, MemberMeeting::ATTENDING::NO]
    end
  end

  def create_role_reference(klass, klass_id, role_ids, role_count = 1)
    raise "Role ids and role_count mismatch" if role_ids.size < role_count
    temp_role_ids = role_ids.dup
    RoleReference.populate role_count do |role_reference|
      role_reference.ref_obj_id = klass_id
      role_reference.ref_obj_type = klass.to_s
      role_reference.role_id = (role_count == 1 ? temp_role_ids.sample : temp_role_ids.shift)
    end
  end
end