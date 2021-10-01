class GroupPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    return if @options[:common]["no_groups"]
    @options[:project_based] = @program.project_based?
    groups_count_form_spec = (@program.users.active.count * @percents_ary[0] * @counts_ary[0] * 0.01).to_i
    difference = groups_count_form_spec - @program.groups.count 
    difference > 0 ? add_groups(@program, difference.abs) : remove_groups(@program, difference.abs)
  end

  def add_groups(program, count, options = {})
    self.class.benchmark_wrapper "Groups" do 
      admin_user = program.admin_users.first
      roles_ids = program.roles.with_name([RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME]).pluck(:id)
      mentoring_models = program.mentoring_models.includes(:mentoring_model_task_templates)
      high_mentoring_model_ids = []
      low_mentoring_model_ids = []
      mentoring_models.each do |mentoring_model|
        (mentoring_model.mentoring_model_task_templates.size > 50 ? high_mentoring_model_ids : low_mentoring_model_ids) << mentoring_model.id
      end
      student_count_range = [2, 3]
      group_iterator = 1
      group_ids = []
      current_time = Time.now
      mentors = program.users.active.includes([:roles]).select{|user| user.is_mentor?}
      students = program.users.active.includes([:roles]).select{|user| user.is_student?}
      additional_group_status = [Group::Status::CLOSED, Group::Status::CLOSED, Group::Status::INACTIVE, Group::Status::DRAFTED]
      additional_group_status += ([Group::Status::PENDING, Group::Status::PROPOSED, Group::Status::REJECTED] * 3) if options[:project_based]
      temp_mentors = mentors.dup
      temp_students = students.dup

      mentee_mentor_available =  Hash.new {|h,k| h[k] = Hash.new }
      pair_list = []
      students.each do |student|
        mentors.each do |mentor|
          mentee_mentor_available[mentor][student] = Group.involving(mentor, student).size.zero?
          pair_list << [student, mentor] if mentee_mentor_available[mentor][student]
        end
      end
      pair_list.uniq!

      index = 0
      Group.populate count do |group|
        mentor = pair_list[index].first
        student = pair_list[index].second

        return if student.nil? || mentor.nil?
        mentee_mentor_available[mentor][student] = false
        group.program_id = program.id
        group.created_at = program.created_at..Time.now
        group.published_at = group.created_at
        group.version = 1
        if low_mentoring_model_ids.present?
          if high_mentoring_model_ids.present?
            group.mentoring_model_id = high_mentoring_model_ids.shift
          else
            group.mentoring_model_id = low_mentoring_model_ids.first
            low_mentoring_model_ids = low_mentoring_model_ids.rotate
          end
        else
          group.mentoring_model_id = high_mentoring_model_ids.first
          high_mentoring_model_ids = high_mentoring_model_ids.rotate
        end
        group.status = options[:from_external] ? Group::Status::ACTIVE : ([Group::Status::ACTIVE] * 6) + additional_group_status
        group_members = [mentor, student]
        case group.status
        when Group::Status::DRAFTED
          group.creator_id = admin_user.id
          group.published_at = nil
        when Group::Status::CLOSED
          group.terminator_id = admin_user.id
          group.closure_reason_id = GroupClosureReason.create(program_id: program.id, created_at: group.created_at, updated_at: group.updated_at, is_completed: true).id
          group.closed_at = Time.now
        when Group::Status::PROPOSED
          group_members = [mentor]
          group.creator_id = mentor.id
        end
        temp_group_members = group_members.dup
        temp_group_members_size = temp_group_members.size
        group_user = temp_group_members.shift
        type = Connection::MentorMembership.to_s
        student_memberships = []
        mentor_memberships = []
        temp_roles_ids = roles_ids.dup
        Connection::Membership.populate temp_group_members_size do |membership|
          temp_roles_ids = roles_ids.dup if temp_roles_ids.blank?
          membership.user_id = group_user.id
          membership.group_id = group.id
          membership.created_at = group.created_at
          membership.type = type
          membership.status = Connection::Membership::Status::ACTIVE
          membership.role_id = temp_roles_ids.shift
          membership.login_count = rand(10)
          membership.api_token = "#{membership.id}#{self.class.random_string}"
          type == Connection::MentorMembership.to_s ? (mentor_memberships << membership.id) : (student_memberships << membership.id)
          type = Connection::MenteeMembership.to_s
          group_user = temp_group_members.shift
        end
        unless [Group::Status::DRAFTED, Group::Status::PENDING].include?(group.status)
          group.expiry_time = group.created_at + (program.mentoring_period / 1.day).days
        end
        group.name = group_members.collect(&:last_name).to_sentence
        group_iterator += 1
        group_ids << group.id
        index += 1
        self.dot
      end
      copy_group_permissions(group_ids)
      self.class.display_populated_count(count, "Groups")
    end
  end

  def remove_groups(program, count, options = {})
    self.class.benchmark_wrapper "Removing Group................" do
      group_ids = Group.where(:program_id => program.id).select([:id, :program_id]).group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Scrap.where(:ref_obj_id => group_ids, :ref_obj_type => Group.to_s).destroy_all
      Group.where(:id => group_ids).destroy_all
      self.class.display_deleted_count(count, "Groups")
    end
  end
end