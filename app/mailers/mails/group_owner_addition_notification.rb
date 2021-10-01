class GroupOwnerAdditionNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'o2gkoiy', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::NEW_CIRCLES_CREATION,
    :title        => Proc.new{|program| "email_translations.group_owner_addition_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_owner_addition_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_owner_addition_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? },
    :campaign_id_2  => CampaignConstants::GROUP_OWNER_ADDITION_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 6
  }

  def group_owner_addition_notification(member, group)
    @group = group
    @member = member
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_username(@member)
    setup_email(@member, :from => :admin)
    super
  end

  register_tags do
    tag :url_mentoring_connection, :description => Proc.new{|program| "email_translations.group_owner_addition_notification.tags.url_mentoring_connection.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
      @group.published? ? group_url(@group, :subdomain => @organization.subdomain, :src => 'mail') : profile_group_url(@group, :subdomain => @organization.subdomain, :src => 'mail')
    end
    
    tag :group_name, :description => Proc.new{"email_translations.group_owner_addition_notification.tags.group_name.description".translate}, :example => Proc.new{"email_translations.group_owner_addition_notification.tags.group_name.example".translate} do
      @group.name
    end

    tag :mentoring_connection_button, :description => Proc.new{|program| "email_translations.group_owner_addition_notification.tags.mentoring_connection_button.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{|program| call_to_action_example('email_translations.group_owner_addition_notification.button_text'.translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action('email_translations.group_owner_addition_notification.button_text'.translate(mentoring_connection: @_mentoring_connection_string), profile_group_url(@group, :subdomain => @organization.subdomain, :src => 'mail'))
    end  
  end

  self.register!

end
