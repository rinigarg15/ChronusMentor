module ApplicationControllerExtensions::Helpers
  private

  def assign_user_and_sanitization_version(record)
    record.current_user = current_user
    record.current_member = current_member
    record.sanitization_version = @current_organization.security_setting.sanitization_version
  end

  def track_activity_for_ei(activity, options={})
    return unless EngagementIndex.enabled?
    @engagement_index ||= EngagementIndex.new(@current_member, @current_organization, @current_user, @current_program, browser, working_on_behalf?)
    @engagement_index.save_activity!(activity, options)
  end

  def track_sessionless_activity_for_ei(activity, member, organization, options={})
    return unless EngagementIndex.enabled?
    @engagement_index ||= EngagementIndex.new(member, organization, options.delete(:user), options.delete(:program), options.delete(:browser), false)
    @engagement_index.save_activity!(activity, options)
  end

  def global_search_current_user_role_ids
    current_user.is_admin? ? current_program.role_ids : current_user.role_ids 
  end  

  def is_membership_form_enabled?(program_or_organization)
    super_user_or? do
      if program_or_organization.is_a? Program
        program_or_organization.allows_apply_to_join_for_a_role?
      elsif program_or_organization.is_a? Organization
        program_or_organization.can_preview_membership_questions_for_any_program?
      end
    end
  end

  #
  # Returns the search options for limiting to the programs depending on the
  # current context and the sub program filters if any.
  #
  def sub_program_search_options
    if program_view?
      {program_id: @current_program.id}
    else
      if @filtered_program
        # Organization view with program filter - Restrict to the given program.
        {program_id: @filtered_program.id}
      else
        # Organization view - Restrict to the programs the member belongs to.
        {program_id: wob_member.active_programs.pluck(:id)}
      end
    end
  end

  def expire_banner_cached_fragments(object = nil)
    object ||= program_context
    organization = current_organization
    locales = [I18n.default_locale] + organization.languages.pluck(:language_name)
    locales.each do |locale|
      expire_fragment(CacheConstants::Programs::BANNER.call(object.id, locale))
      expire_program_fragments(organization, locale)
    end
  end

  def get_dormant_member_search_options
    {
      per_page: SELECT2_PER_PAGE_LIMIT,
      with: {organization_id: @current_organization.id}
    }
  end

  def expire_cached_program_user_filters
    @current_organization.programs.each do |program|
      expire_user_filters(program.id)
    end
  end

  def get_members_field_for_filters_autocomplete(params, options = {})
    filters = params[:filter][:filters].values.first
    return [] unless filters['field'].in?([AdminViewColumn::Columns::Key::FIRST_NAME, AdminViewColumn::Columns::Key::LAST_NAME, AdminViewColumn::Columns::Key::EMAIL, SurveyResponseColumn::Columns::SenderName])
    members = get_members_source_column_for_autocomplete(filters, options)
    method_name = get_member_filter_method_name(filters['field'])
    members.map { |member| { filters['field'] => member.send(method_name).to_s.downcase } }.uniq
  end

  def get_en_datetime_str(datetime_str)
    return datetime_str if current_locale == :en || datetime_str.nil? # This need to be in :en
    get_datetime_str_in_en(datetime_str)
  end

  def setup_negative_captcha
    @captcha = NegativeCaptcha.new(
      secret: APP_CONFIG[:negative_captcha_secret],
      spinner: request.remote_ip,
      fields: [:email],
      css: "display: none",
      params: params
    )
  end

  def reject_terms_and_privacypolicy(organization_hash)
    organization_hash.reject{ |key, _val| Organization::TermsAndPrivacyPolicy.all.include?(key) }
  end

  def load_survey_response_params(survey, response_id)
    @survey_answers = survey.survey_answers.includes(:answer_choices).where(response_id: response_id)
    @first_survey_answer = @survey_answers.first
    @meeting = @first_survey_answer.member_meeting.meeting if survey.meeting_feedback_survey?
    @survey_questions = survey.survey_questions.includes(:translations, {question_choices: :translations}, rating_questions: [:translations, matrix_question: [:translations, {question_choices: :translations}]])
    @submitted_at = @survey_answers.collect(&:last_answered_at).max
    @survey_answers = @survey_answers.group_by(&:common_question_id)
  end

  def get_solution_pack_flash_message(solution_pack, data_deleted = false)
    message = solution_pack_create_message(data_deleted)
    message << content_tag(:div, get_invalid_ck_assets_message(solution_pack), class: "font-bold") if solution_pack.invalid_ck_assets_in.present?

    [message.html_safe, (solution_pack.invalid_ck_assets_in.present? || data_deleted) ? :warning : :notice]
  end

  def destroy_role_questions(to_be_destroyed_role_qns)
    to_be_deleted_role_ids = to_be_destroyed_role_qns.collect(&:role_id)
    to_be_destroyed_role_qns.map(&:destroy)
    to_be_deleted_role_ids
  end

  def permit_internal_attributes(attr_params, allowed_params)
    internal_attributes = ActionController::Parameters.new({})
    attr_params.keys.map {|k| internal_attributes[k] = attr_params[k].permit(allowed_params)}
    internal_attributes.permit!
  end

  def get_current_user
    # Note the usage of all_users here. all_users = [admins + mentors + mentees]
    if logged_in_organization? && @current_program
      #don't change current_member to wob_member.
      @current_program.all_users.active_or_pending.where(
        "users.member_id = ?", current_member.id).includes([{roles: :permissions}, :program]).readonly(false).first
    end
  end

  #
  # Returns the current program or organization based on whether we are at the
  # organization or program level.
  #
  def program_context
    program_view? ? @current_program : @current_organization
  end

  def set_browser_warning_content
    @browser_warning_content = @current_organization.try(:browser_warning)
    return if @browser_warning_content.present?

    browser_warning_default_content_hash = YAML::load(IO.read(Rails.root.join("config/default_browser_warning_content.yml")))[0]
    @browser_warning_content = browser_warning_default_content_hash[I18n.locale.to_s] || browser_warning_default_content_hash[I18n.default_locale.to_s]
  end

  def get_invalid_ck_assets_message(solution_pack)
    invalid_ck_assets_message = "#{"solution_pack.error.invalid_attachment_urls".translate} (#{'display_string.Old'.translate}, #{'feature.reports.header.New'.translate}): "
    invalid_ck_assets_message + solution_pack.invalid_ck_assets_in.collect do |model_name, obj_ids|
      "#{model_name} - #{obj_ids}"
    end.join("; ")
  end

  def solution_pack_create_message(data_deleted)
    message = "flash_message.program_flash.created_using_solution_pack".translate(program: _Program)
    message << " #{'flash_message.program_flash.created_using_solution_pack_with_data_deleted'.translate(Mentoring_Connection: _mentoring_connection)}" if data_deleted
    message
  end

  def expire_user_filters(program_id)
    roles = Role.where(program_id: program_id).non_administrative.collect(&:name)
    roles.each {|role| expire_fragment(CacheConstants::Programs::USER_FILTERS.call(program_id, role)) }
    expire_fragment(CacheConstants::Programs::USER_FILTERS.call(program_id, roles.join('_')))
  end

  def get_member_filter_method_name(field_name)
    field_name == SurveyResponseColumn::Columns::SenderName ? 'name_only' : field_name
  end

  def get_members_source_column_for_autocomplete(filters, options)
    field = Member.get_field_mapping(filters['field'])
    Member.get_filtered_members(filters["value"].strip, options.merge!(match_fields: [field.to_s + ".autocomplete"], source_columns: [field]))
  end

  def expire_program_fragments(organization, locale)
    organization.programs.pluck(:id).each {|program_id| expire_fragment(CacheConstants::Programs::BANNER.call(program_id, locale))} if (program_context.is_a?(Organization) || program_context.standalone?)
  end
end