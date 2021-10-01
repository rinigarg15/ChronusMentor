class MobileApi::V1::UsersPresenter < MobileApi::V1::BasePresenter
  include UserListingExtensions
  include CommonProfileIncludes
  include ::ApplicationHelper

  # get all program's users
  #currently this method supports only two roles namely pure mentors and pure mentees.
  def list(acting_user, params = {})
    result = { success: true }
    pagination_options = {per_page: params[:per_page] || PER_PAGE, page: params[:page] || 1}
    roles = []
    users_chain = program.users.active.includes({member: :profile_picture})

    # filter by email
    if params.has_key?(:email)
      users_chain = users_chain.where(members: { email: params[:email] })
    end

    if params[:search_query].present?
      users_chain = users_chain.where(id: apply_search_query(params[:search_query]))
    end

    # if requested_roles = [], then non-administrative-viewable-roles based users
    # else if intersection(requested-roles, non-administrative-viewable-roles) == [], then privacy_restriction error is raised
    # else users of intersection(requested-roles, non-administrative-viewable-roles)
    visible_roles = acting_user.visible_non_admin_roles
    if params.has_key?(:roles)
      roles = RolesMapping.roles_from_aliases(params[:roles])
      result = errors_hash([ApiConstants::UserErrors::INCORRECT_ROLES]) unless roles.present?
    end
    privacy_restriction = roles.present? && ((roles & visible_roles).size != roles.size)
    roles = roles.present? ? (roles & visible_roles) : visible_roles
    if roles.present?
      users_chain = users_chain.for_role(roles)
    elsif privacy_restriction
      result = errors_hash([ApiConstants::UserErrors::PRIVACY_RESTRICTION])
    end

    if result[:success]
      profile_needed = (1 == params[:profile].to_i)
      list_contains_only_mentor = params[:roles].present? && params[:roles] == MobileApi::V1::BasePresenter::RolesMapping::MENTOR_ROLE
      student_viewing_mentors = acting_user && acting_user.can_send_mentor_request? && list_contains_only_mentor
      @match_results = {}
      connection_count = {}
      ## The below variable needs to be initialized as this variable is used in the lib/user_listing_extensions
      if student_viewing_mentors
        @match_results = acting_user.student_cache_normalized if program.allow_end_users_to_see_match_scores?
        user_match_ids = users_chain.pluck(:id)
        user_match_ids = user_match_ids.sort_by{|user_id| -(@match_results[user_id] || 0) }
        user_ids_string = user_match_ids.join(',')
        users_chain = User.where(id: user_match_ids).order(user_ids_string.present? ? "field(id,#{user_ids_string})" : "").paginate(pagination_options)
        @user_ids = users_chain.collect(&:id)
        set_can_connect_data(acting_user, program)
      else
        users_chain = users_chain.paginate(pagination_options)
        @user_ids = users_chain.collect(&:id)
      end

      if list_contains_only_mentor
        connection_count = Connection::MentorMembership.joins(group: :student_memberships).where(user_id: @user_ids).
        where("groups.status NOT IN (?)", Group::Status::NOT_ACTIVE_CRITERIA).
        where(groups: {program_id: program.id}).
        group('connection_memberships.user_id').count
      end
      set_profile_summary_values(acting_user, program, users_chain, roles)
      result = success_hash(total_entries: users_chain.total_entries, total_pages: users_chain.total_pages, list: users_chain.map { |user| 
        additional_params = {}
        is_viewing_self = acting_user == user
        additional_params.merge!(self_view: is_viewing_self)
        additional_params.merge!(viewer_can_send_message: show_send_message_link?(user, acting_user))
        if student_viewing_mentors && !is_viewing_self
          additional_params.merge!(match_score: match_score_for_user(@match_results, user, src: "list"), zero_match_score_message: program.zero_match_score_message)
          user_connect_response = can_user_connect(user, acting_user)
          additional_params.merge!(connect_request: user_connect_response)
        end
        additional_params.merge!(connection_count: connection_count[user.id] || 0) if list_contains_only_mentor
        additional_params.merge!(profile_summary: profile_summary_values(user))
        user_hash(user, profile_needed, additional_params)
      })
    end
    result
  end

  def dashboard(acting_user, params)
    user_id = params[:id].to_i
    user = program.users.where(id: user_id).includes(:roles, :member).first
    if user.present?
      options = {
        inbox_unread_count: user.member.inbox_unread_count,
        announcement_count: published_announcements_count(user),
        mentor_request_count: (user.is_mentor? ? user.received_mentor_requests.active.count : user.sent_mentor_requests.active.count)
      }
      user_hash = user_hash(user, false, options.merge!(size: :large))

      ## TODO:: Showing only active connections, when you remove active scope, you need not write new tests, please uncomment already written tests.
      groups_chain = acting_user.groups.published.active.includes(:mentoring_model_tasks, {members: {member: :profile_picture}})

      mentoring_roles = program.roles.for_mentoring_models
      # map received data to array
      success_hash(user: user_hash, groups: groups_chain.map do |group| 
          simple_group_hash(group, acting_user: acting_user, mentoring_roles: mentoring_roles)
        end
      )
    else
      user_not_found_hash(user_id)
    end
  end

  def find(acting_user, params)
    user_id = params[:id].to_i
    user = program.users.where(id: user_id).includes(:roles, {member: :profile_picture}).first

    if user.present?
      if user.visible_to?(acting_user)
        options = {acting_user: acting_user}
        user_hash = user_hash(user, true, options.merge!(size: :large))
        is_viewing_self = acting_user == user

        if acting_user.can_send_mentor_request? && !is_viewing_self
          match_results = program.allow_end_users_to_see_match_scores? ? acting_user.student_cache_normalized : {}
          user_hash.merge!(match_score: match_score_for_user(match_results, user, src: "find"), zero_match_score_message: program.zero_match_score_message)
          if user.can_mentor?
            @user_ids = user.id
            set_can_connect_data(acting_user, program)
            connect_request = can_user_connect(user, acting_user)
            user_hash.merge!(connect_request: connect_request)
          end
        end

        user_hash.merge!(
          self_view: is_viewing_self, 
          viewer_can_send_message: show_send_message_link?(user, acting_user)
        )

        success_hash(user: user_hash)
      else
        errors_hash([ApiConstants::UserErrors::PRIVACY_RESTRICTION])
      end
    else
      user_not_found_hash(user_id)
    end
  end

protected

  def match_score_for_user(match_results, user, options = {})
    score = options[:src] == "find" ? match_results[user.id] : (match_results[user.id] || 0)
    program.allow_end_users_to_see_match_scores? ? score : nil
  end

  def user_not_found_hash(id)
    errors_hash([ApiConstants::UserErrors::USER_NOT_FOUND % id])
  end

  def user_hash(user, profile_needed = false, options = {})
    res = {
      id:             user.id,
      first_name:     user.first_name,
      last_name:      user.last_name,
      name:           user.name,
      email:          user.email,
      status:         user.state,
      uuid:           user.member.login_name,
      roles:          RolesMapping.aliased_names(user.role_names),
      image_url:      generate_member_url(user.member, options),
      member_id:      user.member_id,
      member_since:   DateTime.localize(user.created_at, format: :full_month_year)
    }
    options.delete(:size)
    if profile_needed
      res.merge!(profile: profile_hash(user, options.delete(:acting_user)))
      res.merge!(section_order: program.profile_questions_for(user.role_names).group_by(&:section).keys.sort_by(&:position).collect(&:title))
    end
    res.merge!(options) if options.present?
    res
  end

  def education_hash(education)
    {
      school_name:     education.school_name,
      degree:          education.degree,
      major:           education.major,
      graduation_year: education.graduation_year
    }
  end

  def educations_hash(answer)
    answer.educations.inject({}) do |res, education|
      res.merge!(:"education_#{education.id}" => education_hash(education))
    end
  end

  def experience_hash(experience)
    {
      company:     experience.company,
      job_title:   experience.job_title,
      current_job: experience.current_job,
      start_month: experience.start_month,
      start_year:  experience.start_year,
      end_month:   experience.end_month,
      end_year:    experience.end_year
    }
  end

  def experiences_hash(answer)
    answer.experiences.inject({}) do |res, experience|
      res.merge!(:"experience_#{experience.id}" => experience_hash(experience))
    end
  end


  def profile_hash(user, acting_user)
    attributes = {}

    program_questions_for_user = fetch_program_questions_for_user(program, user, acting_user, program.organization.skype_enabled?, user.is_admin_only?)
    program_questions_for_user_with_order = program_questions_for_user.sort_by(&:position)
    program_questions_for_user_with_order.each do |question|
      next unless question.conditional_text_matches?(@all_answers)
      section_title = question.section.title
      attributes[section_title] ||= []
      answer = @all_answers[question.id]
      if answer.present?
        question_array = {
          question_text: question.question_text.html_safe, 
          answer_text: question.choice_or_select_type? ? answer[0].selected_choices_to_str : answer[0].try(:answer_text).to_s
        }
        question_array.merge!(file_name: answer[0].attachment_file_name, attachment: answer[0].attachment.to_s) if question.file_type?
        attributes[section_title] << question_array
      end
    end
    attributes
  end
  
  def profile_summary_values(user)
    profile_answers = @question_answers[user.member_id] || []
    profile_summary_hash = {}
    profile_answers.each do |question_answer_hash|
      answer = question_answer_hash[:answer]
      question = question_answer_hash[:question]
      if question.education? && !profile_summary_hash[:education].present?
          profile_summary_hash[:education] = format_summary(question, answer)
      elsif question.experience? && !profile_summary_hash[:experience].present?
          profile_summary_hash[:experience] = format_summary(question, answer)
      elsif profile_summary_hash[:education].present? && profile_summary_hash[:experience].present?
        break
      end
    end
    profile_summary_hash
  end

  def apply_search_query(search_query)
    search_options = {
      with: { program_id: program.id },
      source_columns: [:id]
    }
    User.get_filtered_users(search_query, search_options)
  end
  
  def can_user_connect(user, acting_user)
    group = @mentor_group_map[user]
    mentor_request_id = @active_received_requests[user.id]
    existing_pending_request = mentor_request_id.present?
    mentor_max_connection_limit_reached = @mentors_with_slots[user.id].to_i < 1
    mentee_max_connection_limit_reached = mentee_max_connection_limit_reached?(acting_user)
    denied_due_to_match_score_zero = !acting_user.can_connect_to_mentor?(user, @match_results)
    connection_already_exists = group.present?
    mentee_pending_request_limit_reached = acting_user.pending_request_limit_reached_for_mentee?

    #conditions
    can_connect = (acting_user != user &&
                   acting_user.active? &&
                   @current_program.matching_by_mentee_alone? &&
                   acting_user.can_send_mentor_request? &&
                   !existing_pending_request &&
                   !mentor_max_connection_limit_reached &&
                   !mentee_max_connection_limit_reached &&                   
                   !connection_already_exists &&                    
                   !denied_due_to_match_score_zero &&
                   !mentee_pending_request_limit_reached)
                 
    return {can_connect: can_connect,
            group_id: group.try(:id),
            mentor_request_id: mentor_request_id,
            errors: {:existing_pending_request => existing_pending_request,
                     :mentor_max_connection_limit_reached => mentor_max_connection_limit_reached,
                     :mentee_max_connection_limit_reached => mentee_max_connection_limit_reached,
                     :denied_due_to_match_score_zero => denied_due_to_match_score_zero, 
                     :connection_already_exists => connection_already_exists,
                     :mentee_pending_request_limit_reached => mentee_pending_request_limit_reached
                     }
            }
  end

  def get_active_received_requests(user)
    MentorRequest.where(:sender_id => user.id).
      where(:receiver_id => @user_ids).
      where(:status => AbstractRequest::Status::NOT_ANSWERED).
      group(:receiver_id)
  end

  def set_can_connect_data(acting_user, program)
    @current_program = program
    get_mentors_with_slots!(program, @user_ids)
    @mentor_group_map = acting_user.mentor_connections_map
    @active_received_requests = {}
    get_active_received_requests(acting_user).each do |request|
      @active_received_requests[request.receiver_id] = request.id
    end
  end

  def published_announcements_count(user)
    program.announcements.for_user(user).published.not_expired.count
  end

  def mentee_max_connection_limit_reached?(user)
    @current_program.max_connections_for_mentee.present? && (user.groups.active.size >= @current_program.max_connections_for_mentee)
  end


  def simple_group_hash(group, options = {})
    {
      id: group.id,
      name: group.name,
      last_activity_on: datetime_to_string(group.last_activity_at),
      tasks: tasks_meta_dictionary(group),
      image_url: generate_connection_url(group, options[:acting_user], options.slice(:size)),
      can_show_tasks: program.mentoring_connections_v2_enabled? && group.can_manage_mm_tasks?(options[:mentoring_roles])
    }
  end

  private
  def format_summary(question, answer)
    if question.education?
      education = answer.educations.first
      education.degree.present? ? "#{education.degree}, #{education.school_name}" : "#{education.school_name}"
    else
      experience = answer.experiences.first
      experience.job_title.present? ? "#{experience.job_title}, #{experience.company}" : "#{experience.company}"
    end
  end

  def set_profile_summary_values(profile_viewer, program, users, roles)
    role_questions = program.role_questions_for(roles, user: profile_viewer).role_profile_questions.joins(:profile_question).where(profile_questions: {question_type: [ProfileQuestion::Type::EDUCATION, ProfileQuestion::Type::MULTI_EDUCATION, ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE]})
    profile_question_id_member_map = {}
    @question_answers = {}
    users.each do |user|
      profile_question_id_member_map[user.member_id] = role_questions.select{|q| q.visible_for?(profile_viewer, user)}.collect(&:profile_question_id)
    end
    all_member_answers = ProfileAnswer.where(ref_obj_id: users.collect(&:member_id), ref_obj_type: Member.name, profile_question_id: profile_question_id_member_map.values.uniq).includes(:profile_question)
    all_member_answers.each do |profile_answer|
      (@question_answers[profile_answer.ref_obj_id] ||= []) << {question: profile_answer.profile_question, answer: profile_answer} if profile_question_id_member_map[profile_answer.ref_obj_id].include?(profile_answer.profile_question_id) && !profile_answer.unanswered?
    end
  end

end
