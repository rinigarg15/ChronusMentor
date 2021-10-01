module FirstVisitSectionCookies

  def set_all_section_titles
    @all_profile_section_ids = @program_questions_for_user.group_by { |q| q.section.position }.sort.to_h.values.flatten.collect(&:section_id).uniq
    @all_profile_section_titles_hash  = Hash.new
    @current_organization.sections.includes(:translations).where(id: @all_profile_section_ids).each do |section|
      @all_profile_section_titles_hash[section.id] = section.title
    end
    add_mentoring_and_calendar_sync_sections
  end

  def add_mentoring_and_calendar_sync_sections
    @all_profile_section_ids << MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS if @current_program.calendar_sync_v2_for_member_applicable?
    @all_profile_section_ids << MembersController::EditSection::MENTORING_SETTINGS if can_edit_mentoring_settings_section?(@profile_user)
  end
  
  def set_first_time_sections_cookie
    role_ids = @profile_user.role_ids
    user_id = @profile_user.id
    sections_filled_hash = {user_id => {role_ids => [@section_id]}}
    first_time_sections_filled = cookies[:first_time_sections_filled].blank? ? sections_filled_hash : set_sections_cookie(role_ids, user_id, @section_id)
    cookies[:first_time_sections_filled] = {value: ActiveSupport::JSON.encode(first_time_sections_filled), expires: 1.month.from_now}
  end

  def set_sections_cookie(role_ids, user_id, section_id)
    sections_filled = ActiveSupport::JSON.decode(cookies[:first_time_sections_filled])
    sections_filled[user_id.to_s] = {role_ids.to_s => []} unless sections_filled.has_key?(user_id.to_s)
    sections_filled[user_id.to_s].has_key?(role_ids.to_s) ? (sections_filled[user_id.to_s][role_ids.to_s] << section_id) : (sections_filled[user_id.to_s][role_ids.to_s] = [section_id])
    sections_filled[user_id.to_s] = sections_filled[user_id.to_s].slice(role_ids.to_s)
    sections_filled
  end

  def set_sections_filled_from_cookies
    first_time_sections_filled = ActiveSupport::JSON.decode(cookies[:first_time_sections_filled]) if cookies[:first_time_sections_filled].present?
    set_sections_filled(first_time_sections_filled)
    reject_sections_filled_with_mandatory_questions! if @program_questions_for_user.present?
  end

  def set_sections_filled(first_time_sections_filled)
    user_id = @profile_user.id
    role_ids = @profile_user.role_ids
    @sections_filled = first_time_sections_filled[user_id.to_s][role_ids.to_s] if first_time_sections_filled.present? && first_time_sections_filled[user_id.to_s].present?
    @sections_filled ||= []
  end

  def reject_sections_filled_with_mandatory_questions!
    answered_profile_questions = @profile_member.answered_profile_questions
    profile_question_ids = (@program_questions_for_user - answered_profile_questions).collect(&:id)
    role_questions = @current_program.role_questions_for(@profile_user.role_names, user: current_user).role_profile_questions.where(profile_question_id: profile_question_ids)
    role_questions_per_section = role_questions.includes(profile_question: [:translations]).group_by { |q| q.profile_question.section_id.to_s }
    @sections_filled.reject!{|section| (role_questions_per_section[section] || []).select(&:required?).any?}
  end

end