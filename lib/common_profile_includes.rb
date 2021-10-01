#
# Common code for rendering profile layout used in profile show page, edit page
# and edit picture page.
#
module CommonProfileIncludes
  # Number of items in the side pane sections.
  PROFILE_RIGHT_PANE_ENTRY_LIMIT = 2

  # Prepares data for rendering the profile side pane.
  def prepare_profile_side_pane_data
    @profile_member_or_user ||= organization_view? ? @profile_member : @profile_user

    if @show_articles
      published_articles = @profile_member_or_user.articles.published.includes(:article_content)
      @side_pane_articles = published_articles.limit(PROFILE_RIGHT_PANE_ENTRY_LIMIT)
      @side_pane_articles_count = published_articles.size
    end

    if @show_answers
      questions = @profile_member_or_user.qa_questions
      @side_pane_questions = questions.limit(PROFILE_RIGHT_PANE_ENTRY_LIMIT)
      answers = @profile_member_or_user.qa_answers
      @side_pane_answers = answers.limit(PROFILE_RIGHT_PANE_ENTRY_LIMIT).includes([:qa_question])
      @side_pane_questions_count = questions.size
      @side_pane_answers_count = answers.size
    end
    
    if @show_connections
      groups = @profile_member_or_user.groups.active
      @side_pane_groups = groups.limit(PROFILE_RIGHT_PANE_ENTRY_LIMIT)
      @side_pane_groups_count = groups.size if @show_connections
    end
    
    if @show_meetings
      include_options = [:member_meetings , :members, :owner]
      meetings = @current_program.get_accessible_meetings_list(@profile_member.meetings).includes(include_options)
      meetings = Meeting.upcoming_recurrent_meetings(meetings.accepted_meetings)
      @side_pane_meetings = meetings.first(OrganizationsController::MY_MEETINGS_COUNT)
      @side_pane_meetings_count = meetings.size
    end

    @side_pane_requests = []
    if @show_connection_requests
      @side_pane_connection_requests = current_user.received_mentor_requests.active.where(:sender_id => @profile_user.id)
      @side_pane_requests.concat(@side_pane_connection_requests)
    end

    if @show_meeting_requests
      side_pane_meeting_requests = current_user.pending_received_meeting_requests.where(:sender_id => @profile_user.id).includes(:meeting_proposed_slots).latest_first
      @side_pane_requests.concat(side_pane_meeting_requests)
    end
    @side_pane_requests_count = @side_pane_requests.size
  end

  def fetch_program_questions_for_user(program, profile_user, user, skype_enabled, is_owner_admin_only)
    @all_answers = profile_user.member.profile_answers.includes([{profile_question: {question_choices: :translations} }, :answer_choices, :educations, :experiences, :publications, :location]).group_by(&:profile_question_id)
    role_questions_with_email = program.role_questions_for(profile_user.role_names, user: user).role_profile_questions.includes(profile_question: [:section, {question_choices: :translations}])
    questions_with_email = role_questions_with_email.to_a.select{|q| q.visible_for?(user, profile_user)}.collect(&:profile_question).uniq.select{|q| q.question_type != ProfileQuestion::Type::NAME}
    (skype_enabled && !is_owner_admin_only) ? questions_with_email : questions_with_email.select{|q| !q.skype_id_type? }
  end
end
