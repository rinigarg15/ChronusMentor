class AdminWeeklyStatus < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'kcxw75rg', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::DIGEST_AND_WEEKLY_UPDATES,
    :title        => Proc.new{|program| "email_translations.admin_weekly_status.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.admin_weekly_status.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.admin_weekly_status.subject_v1".translate},
    :campaign_id  => CampaignConstants::WEEKLY_UPDATE_MAIL_ID,
    :campaign_id_2 => CampaignConstants::WEEKLY_UPDATE_2_MAIL_ID,
    :disable_customization => true,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2,
    :notification_setting => UserNotificationSetting::SettingNames::DIGEST_AND_ALERTS
  }

  def admin_weekly_status(admin, program, precomputed_hash, since = 1.week.ago)
    @admin     = admin
    @program   = program
    @since     = since

    data_hash = {}

    data_hash[:matching_by_admin_alone] = @program.matching_by_admin_alone?
    data_hash[:ongoing_enabled] = @program.ongoing_mentoring_enabled?
    data_hash[:career_based_ongoing] = @program.only_career_based_ongoing_mentoring_enabled?
    data_hash[:calendar_enabled] = @program.calendar_enabled?
    data_hash[:project_based] = @program.project_based?


    ## Mem_requests
    data_hash[:last_week_mem_requests] = precomputed_hash[:membership_requests][:since]
    data_hash[:show_mr_data] = precomputed_hash[:membership_requests][:show_mr_data]
    data_hash[:mr_data_values_changed] = !precomputed_hash[:membership_requests][:values_not_changed]

    ## Articles data
    data_hash[:last_week_articles] = precomputed_hash[:articles][:since]
    data_hash[:show_articles_data] = !precomputed_hash[:articles][:values_not_changed]

    @program.roles_without_admin_role.default.collect(&:name).each do |role_name|
      role_key = "#{role_name}_users".to_sym
      role_pluralize = role_name.pluralize
      data_hash["last_week_#{role_pluralize}".to_sym] = precomputed_hash[role_key][:since]
      data_hash["show_#{role_pluralize}".to_sym] = !precomputed_hash[role_key][:values_not_changed]
    end
    
    if precomputed_hash[:mentor_requests].present?
      ## MentorRequests 
      data_hash[:last_week_mentor_reqs] = precomputed_hash[:mentor_requests][:since]
      data_hash[:show_mentor_reqs] = !precomputed_hash[:mentor_requests][:values_not_changed]
    end

    if precomputed_hash[:pending_mentor_requests].present?
      ## Active MentorRequests data
      data_hash[:last_week_active_mentor_reqs] = precomputed_hash[:pending_mentor_requests][:since]
      data_hash[:show_mentor_reqs] = !precomputed_hash[:pending_mentor_requests][:values_not_changed]
    end

    if precomputed_hash[:groups].present?
      ## Groups data
      data_hash[:last_week_groups] = precomputed_hash[:groups][:since]
      data_hash[:show_groups] = !precomputed_hash[:groups][:values_not_changed]
    end

    if precomputed_hash[:meeting_requests].present?
      ## MeetingRequests data
      data_hash[:last_week_meeting_reqs] = precomputed_hash[:meeting_requests][:since]
      data_hash[:show_meeting_reqs] = !precomputed_hash[:meeting_requests][:values_not_changed]
    end

    if precomputed_hash[:active_meeting_requests].present?
      ## Active MeetingRequests data
      data_hash[:last_week_active_meeting_reqs] = precomputed_hash[:active_meeting_requests][:since]
      data_hash[:show_active_meeting_reqs] = !precomputed_hash[:active_meeting_requests][:values_not_changed]
    end
    
    ## Projects waiting for approval data
    if precomputed_hash[:pending_projects_for_approval].present?
      data_hash[:proposed_groups] = precomputed_hash[:pending_projects_for_approval]
      ## Pending ProjectRequest data
      data_hash[:pending_project_requests] = precomputed_hash[:pending_project_requests][:since]
      data_hash[:pending_project_requests_data_values_changed] = !precomputed_hash[:pending_project_requests][:values_not_changed]
    end

    ## New survey responses
    data_hash[:new_survey_responses] = precomputed_hash[:new_survey_responses]

    @data_result = data_hash
    
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@admin, :name_only => true)
    setup_email(@admin)
    super
    set_layout_options
  end
  
  register_tags do
    tag :since_time, :description => Proc.new{'email_translations.admin_weekly_status.tags.since_time.description'.translate}, :example => Proc.new{'email_translations.admin_weekly_status.tags.since_time.example'.translate} do
      DateTime.localize(@since.in_time_zone(@admin.member.get_valid_time_zone), format: :short)
    end

    tag :current_time_in_admin_time_zone, :description => Proc.new{'email_translations.admin_weekly_status.tags.since_time.description'.translate}, :example => Proc.new{'email_translations.admin_weekly_status.tags.since_time.example'.translate} do
      DateTime.localize(Time.now.in_time_zone(@admin.member.get_valid_time_zone), format: :short)
    end

    tag :admin_weekly_updates, :description => Proc.new{'email_translations.admin_weekly_status.description'.translate}, :example => Proc.new{'email_translations.admin_weekly_status.description'.translate} do
      render(:partial => '/admin_weekly_status', :locals => {data_hash: @data_result})
    end
  end

  self.register!

end