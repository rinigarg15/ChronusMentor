class PostingInMentoringAreaFailure < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'e549wf4k', # rand(36**8).to_s(36)
    :title        => Proc.new{|program| "email_translations.posting_in_mentoring_area_failure.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.posting_in_mentoring_area_failure.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.posting_in_mentoring_area_failure.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.ongoing_mentoring_enabled?},
    :campaign_id_2  => CampaignConstants::POSTING_IN_MENTORING_AREA_FAILURE_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :donot_list   => true
  }

  def posting_in_mentoring_area_failure(user, group, old_subject, old_body)
    @group = group
    @user = user
    @old_subject = old_subject
    @old_content = old_body
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_username(@user)
    setup_email(@user)
    super
  end

  register_tags do
    tag :subject, :description => Proc.new{'email_translations.posting_in_mentoring_area_failure.tags.subject.description'.translate}, :example => Proc.new{'email_translations.posting_in_mentoring_area_failure.tags.subject.example'.translate} do
      @old_subject
    end

    tag :content, :description => Proc.new{'email_translations.posting_in_mentoring_area_failure.tags.content.description'.translate}, :example => Proc.new{'email_translations.posting_in_mentoring_area_failure.tags.content.example'.translate} do
      wrap_and_break(@old_content)
    end

    tag :mentoring_connection_name, :description => Proc.new{|program| 'email_translations.posting_in_mentoring_area_failure.tags.mentoring_connection_name.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'email_translations.posting_in_mentoring_area_failure.tags.mentoring_connection_name.example'.translate} do
      @group.name
    end

    tag :url_mentoring_connection, :description => Proc.new{|program| 'email_translations.posting_in_mentoring_area_failure.tags.url_mentoring_connection.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
      group_url(@group, :subdomain => @organization.subdomain)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.posting_in_mentoring_area_failure.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@group.program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :src => 'email'}})
    end

    tag :closed_date, :description => Proc.new{|program| 'email_translations.posting_in_mentoring_area_failure.tags.closed_date.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'email_translations.posting_in_mentoring_area_failure.tags.closed_date.example'.translate} do
      formatted_time_in_words(@group.closed_at, :no_ago => true, :no_time => true)
    end
  end

  self.register!

end
