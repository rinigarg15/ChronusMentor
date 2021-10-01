module UserListingExtensions

  def initialize_student_actions_for_users(user_ids)
    if !!@current_user
      @user_ids = user_ids
      @student_draft_count = get_drafts_count_of_users! if @current_user.is_admin?
      @student_required_questions = @current_program.required_profile_questions_except_default_for(RoleConstants::STUDENT_NAME)

      @offer_pending = @current_program.mentor_offer_needs_acceptance? && current_user.can_offer_mentoring? ? get_pending_offers_list : {}
      @viewer_can_find_mentor = current_user.is_admin? && @view_param == RoleConstants::STUDENTS_NAME && !@current_program.project_based?
      @viewer_can_offer = current_user.can_mentor? && current_user.can_offer_mentoring?
      get_students_with_no_limit! if @viewer_can_find_mentor || @viewer_can_offer
      get_mentors_count! if @current_user.can_offer_mentoring?
      get_mentors_list! if @current_user.is_admin?
    end
  end

  def initialize_mentor_actions_for_users(user_ids)
    if !!@current_user
      @user_ids = user_ids
      @mentor_draft_count = get_drafts_count_of_users! if @current_user.is_admin?
      @mentor_required_questions = @current_program.required_profile_questions_except_default_for(RoleConstants::MENTOR_NAME)

      @can_render_calendar_ui = @current_user.try(:can_render_calendar_ui_elements?, RoleConstants::MENTOR_NAME)
      get_mentors_with_slots!(@current_program, @user_ids)
      get_students_count! if @current_user.can_send_mentor_request?
      if @current_user.can_send_mentor_request? && @current_program.matching_by_mentee_alone?
        @active_received_requests = {}
        get_active_received_requests.each do |request|
          @active_received_requests[request.receiver_id] = request.id
        end
      end
    end
  end

  def initialize_actions_for_matches_for_students(user_ids, student, program)
    @user_ids = user_ids
    @mentor_required_questions = program.required_profile_questions_except_default_for(RoleConstants::MENTOR_NAME)
    @student_required_questions = program.required_profile_questions_except_default_for(RoleConstants::STUDENT_NAME)
    @mentors_of_student = student.mentors(:closed).group_by(&:id)

    get_mentors_available_slots!(program)
    get_connections_as_mentor_count!(program)
    get_mentors_with_slots!(program, @user_ids)
  end

  def get_pending_offers_list
    offer_pending = {}
    @current_user.sent_mentor_offers.pending.each do |offer|
      offer_pending[offer.student_id] = offer.student_id
    end
    offer_pending
  end

  def get_students_with_no_limit!
    @students_with_no_limit = {}
    unless @current_program.max_connections_for_mentee.nil?
      active_studying_groups_count_of_users.each do |user_id, count|
        @students_with_no_limit[user_id] = user_id if count >= @current_program.max_connections_for_mentee
      end
    end
  end

  def get_mentors_with_slots!(program, user_ids)
    @mentors_with_slots = {}
    @mentors_with_slots_for_matching = {}
    PerfUtils.table_for_join("temp_mentors_slot", user_ids) do |temp_table|
      get_active_or_drafted_students_count!(program, user_ids, {temp_table: temp_table})
      get_sent_mentor_offers_pending!(user_ids, {temp_table: temp_table})
      get_all_received_requests_count!(user_ids, {temp_table: temp_table})
      users = User.select('users.id, max_connections_limit, mentoring_mode, program_id').joins("INNER JOIN #{temp_table} ON #{temp_table}.id = users.id")
      users = users.where(mentoring_mode: User::MentoringMode.ongoing_sanctioned) if program.consider_mentoring_mode?
      users.each do |user|
        pending_slots_for_matching = [user.max_connections_limit - (@active_or_drafted_students_count[user.id].to_i + @sent_mentor_offers_pending[user.id].to_i), 0].max
        pending_slots = [pending_slots_for_matching - @all_received_requests[user.id].to_i, 0].max
        @mentors_with_slots_for_matching[user.id] = user.id if pending_slots_for_matching > 0
        @mentors_with_slots[user.id] = user.id if pending_slots  > 0
      end
    end
    @mentors_with_slots
  end

  def get_mentors_available_slots!(program)
    @mentors_available_slots = {}
    get_active_or_drafted_students_count!(program, @user_ids)
    get_sent_mentor_offers_pending!(@user_ids)
    User.select('id, max_connections_limit').where(:id => @user_ids).each do |user|
      @mentors_available_slots[user.id] = [user.max_connections_limit - (@active_or_drafted_students_count[user.id].to_i + @sent_mentor_offers_pending[user.id].to_i), 0].max
    end
  end

  def get_active_or_drafted_students_count!(program, user_ids, options={})
    connection_membership_scope = Connection::MentorMembership.joins(:group => :student_memberships)
    connection_membership_scope = options[:temp_table].present? ? connection_membership_scope.joins("INNER JOIN #{options[:temp_table]} ON #{options[:temp_table]}.id = connection_memberships.user_id") :
                                          connection_membership_scope.where(:user_id => user_ids)
    @active_or_drafted_students_count = connection_membership_scope.where("groups.status != ?", Group::Status::CLOSED).
                                          where("groups.program_id = ?", program.id).
                                          group('connection_memberships.user_id').count
  end

  def get_sent_mentor_offers_pending!(user_ids, options={})
    mentor_offer_scope = options[:temp_table].present? ? PerfUtils.scope_with_temp_table(MentorOffer, options[:temp_table], "mentor_id")  : MentorOffer.where(:mentor_id => user_ids)
    @sent_mentor_offers_pending = mentor_offer_scope.where(:status => MentorOffer::Status::PENDING).group(:mentor_id).count
  end

  def get_active_received_requests
    MentorRequest.where(:sender_id => @current_user.id).
      where(:receiver_id => @user_ids).
      where(:status => AbstractRequest::Status::NOT_ANSWERED).
      group(:receiver_id)
  end

  def get_all_received_requests_count!(user_ids, options={})
    mentor_request_scope = options[:temp_table].present? ? PerfUtils.scope_with_temp_table(MentorRequest, options[:temp_table], "receiver_id") : 
      MentorRequest.where(:receiver_id => user_ids)
    @all_received_requests = mentor_request_scope.where(:status => AbstractRequest::Status::NOT_ANSWERED).
      group(:receiver_id).size
  end

  def active_studying_groups_count_of_users
    Connection::MenteeMembership.joins(:group).where(:user_id => @user_ids).
      where("groups.status NOT IN (?)", Group::Status::NOT_ACTIVE_CRITERIA).
      where("groups.program_id = ?", @current_program.id).
      group(:user_id).count
  end

  def get_drafts_count_of_users!
    Connection::Membership.joins(:group).where(:user_id => @user_ids).
                      where('groups.status = ?', Group::Status::DRAFTED).
                      where('groups.program_id = ?', @current_program.id).
                      group(:user_id).count
  end

  def get_mentors_count!
    @mentors_count = Connection::MenteeMembership.joins(:group => :mentor_memberships).where(:user_id => @user_ids).
                        where("groups.status NOT IN (?)", Group::Status::NOT_ACTIVE_CRITERIA).
                        where("groups.program_id = ?", @current_program.id).
                        group('connection_memberships.user_id').count
  end

  def get_students_count!
    @students_count = Connection::MentorMembership.joins(:group => :student_memberships).where(:user_id => @user_ids).
                        where("groups.status NOT IN (?)", Group::Status::NOT_ACTIVE_CRITERIA).
                        where("groups.program_id = ?", @current_program.id).
                        group('connection_memberships.user_id').count
  end

  def get_connections_as_mentor_count!(program=@current_program)
    @mentor_connections_count = Connection::MentorMembership.joins(:group).where(:user_id => @user_ids).
                                where("groups.status NOT IN (?)", Group::Status::NOT_ACTIVE_CRITERIA).
                                where("groups.program_id = ?", program.id).group("connection_memberships.user_id").count
  end

  def get_mentors_list!
    @mentors_list = {}
    @mentors_list.default = []
    all_mentor_users = {}
    all_mentors_ids = []

    mentors_list_of_users.each do |membership|
      @mentors_list[membership.user_id] = membership.mentor_ids.split(",").map(&:to_i)
      all_mentors_ids += @mentors_list[membership.user_id]
    end

    @current_program.users.select([:id, :member_id]).includes(:roles, :member).where(:id => all_mentors_ids).each do |user|
      all_mentor_users[user.id] = user
    end

    @mentors_list.each_pair do |user_id, mentor_ids|
      @mentors_list[user_id] = all_mentor_users.values_at(*mentor_ids.uniq)
    end
  end

  def mentors_list_of_users
    Connection::MenteeMembership.select('connection_memberships.user_id, GROUP_CONCAT(mentor_memberships_groups.user_id) as mentor_ids').joins(:group => :mentor_memberships).where(:user_id => @user_ids).
      where(groups: { status: Group::Status::ACTIVE_CRITERIA, program_id: @current_program.id } ).
      group('connection_memberships.user_id')
  end
end