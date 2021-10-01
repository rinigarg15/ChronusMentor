class GroupMemberAdditionNotificationToNewMember < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'dvrnpn78', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_CONNECTIONS_NOTIFICATION,
    :title        => Proc.new{|program| "email_translations.group_member_addition_notification_to_new_member.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_member_addition_notification_to_new_member.description_v4".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_member_addition_notification_to_new_member.subject_v2".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id_2  => CampaignConstants::GROUP_MEMBER_ADDITION_NOTIFICATION_TO_NEW_MEMBER_MAIL_ID,
    :program_settings => Proc.new{|program| program.allow_one_to_many_mentoring?},
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1
  }

  def group_member_addition_notification_to_new_member(user, group, actor, options = {})
    @group = group
    @user = user
    @message = options[:message]
    @role = @group.memberships.of(@user).first.role
    @members_by_role_hash = {}
    @actor = actor
    group.memberships.includes(:role, [:user => :member]).group_by(&:role).each do |role, memberships|
      role_term =  role.customized_term.pluralized_term
      @members_by_role_hash[role_term] = memberships.collect(&:user)
    end
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_username(@user)
    setup_email(@user, :from => :admin)
    super
  end

  register_tags do
    tag :url_mentoring_connection, :description => Proc.new{|program| "email_translations.group_member_addition_notification_to_new_member.tags.url_mentoring_connection.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
      group_url(@group, :subdomain => @organization.subdomain, :src => 'mail')
    end

    tag :expiry_date, :description => Proc.new{|program| "email_translations.group_member_addition_notification_to_new_member.tags.expiry_date.description_v2".translate(program.return_custom_term_hash)}, :example => Proc.new{"email_translations.group_member_addition_notification_to_new_member.tags.expiry_date.example".translate} do
      formatted_time_in_words(@group.expiry_time, :no_ago => true, :no_time => true)
    end

    tag :role_name_articleized, :description => Proc.new{|program| "email_translations.group_member_addition_notification_to_new_member.tags.role_name_articleized.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{ |program| program.get_first_role_term(:articleized_term_downcase) } do
      @role.customized_term.articleized_term_downcase
    end

    tag :list_of_mentors, :description => Proc.new{|program| "email_translations.group_member_addition_notification_to_new_member.tags.list_of_mentors.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{'William Smith'} do
      group_member_links(@group.mentors, false)
    end

    tag :list_of_mentees, :description => Proc.new{|program| "email_translations.group_member_addition_notification_to_new_member.tags.list_of_mentees.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{'John Doe'} do
      group_member_links(@group.students, false)
    end

    tag :list_of_members, :description => Proc.new{|program| "email_translations.group_member_addition_notification_to_new_member.tags.list_of_members.description_v2".translate(program.return_custom_term_hash)}, :example => Proc.new{"email_translations.group_member_addition_notification_to_new_member.tags.list_of_members.example_v1_html".translate} do
      render_members_list_partial(@members_by_role_hash, @user)
    end

    tag :group_name, :description => Proc.new{"email_translations.group_member_addition_notification_to_new_member.tags.group_name.description".translate}, :example => Proc.new{"email_translations.group_member_addition_notification_to_new_member.tags.group_name.example".translate} do
      @group.name
    end

    tag :administrator_or_owner_name, :description => Proc.new{"email_translations.group_member_addition_notification_to_new_member.tags.administrator_or_owner_name.description".translate}, :example => Proc.new { |program| "email_translations.group_member_addition_notification_to_new_member.tags.administrator_or_owner_name.content".translate(program: program.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase, administrator: program.organization.admin_custom_term.term_downcase) } do
      (@actor.present? && @actor.is_owner_of?(@group)) ? @actor.name(name_only: true) : "email_translations.group_member_addition_notification_to_new_member.tags.administrator_or_owner_name.content".translate(program: customized_subprogram_term, administrator: customized_admin_term)
    end

    tag :message_content, :description => Proc.new{"email_translations.group_member_addition_notification_to_new_member.tags.message_content.description".translate}, :example => Proc.new{'feature.email.tags.message_from_administrator_v2_html'.translate(message_from_admin: "email_translations.group_member_addition_notification_to_new_member.tags.message_content.example".translate, admin: "feature.custom_terms.downcase.admin".translate)} do
      sender = (@actor.present? && @actor.is_owner_of?(@group)) ? @actor.name(name_only: true) : customized_admin_term
      @message.present? ? "feature.email.tags.message_from_user_v2_html".translate(message: @message, name: sender) : ""
    end

    tag :mentoring_area_button, :description => Proc.new{|program| 'email_translations.group_member_addition_notification_to_new_member.tags.mentoring_area_button.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{|program| call_to_action_example("email_translations.group_member_addition_notification_to_new_member.tags.mentoring_area_button.visit_your_connection".translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action("email_translations.group_member_addition_notification_to_new_member.tags.mentoring_area_button.visit_your_connection".translate(mentoring_connection: @_mentoring_connection_string), group_url(@group, :subdomain => @organization.subdomain, :root => @program.root, :src => :mail))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.group_member_addition_notification_to_new_member.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end
  end

  self.register!

end
