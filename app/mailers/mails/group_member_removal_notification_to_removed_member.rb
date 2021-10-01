class GroupMemberRemovalNotificationToRemovedMember < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'ga4emyqy', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_CONNECTIONS_NOTIFICATION,
    :title        => Proc.new{|program| "email_translations.group_member_removal_notification_to_removed_member.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_member_removal_notification_to_removed_member.description_v4".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_member_removal_notification_to_removed_member.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id_2  => CampaignConstants::GROUP_MEMBER_REMOVAL_NOTIFICATION_TO_REMOVED_MEMBER_MAIL_ID,
    :program_settings => Proc.new{|program| program.allow_one_to_many_mentoring?},
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def group_member_removal_notification_to_removed_member(member, group, old_members_by_role, actor)
    @group = group
    set_program(@group.program)
    @member = member
    @actor = actor
    @members_by_role_hash = {}
    @old_members_by_role = old_members_by_role
    @group.memberships.where(user_id: old_members_by_role.values.flatten.collect(&:id)).includes(:role, [:user => :member]).group_by(&:role).each do |role, memberships|
      role_term = (memberships.size == 1) ? role.customized_term.term : role.customized_term.pluralized_term
      @members_by_role_hash[role_term] = memberships.collect(&:user)
    end
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_username(@member)
    setup_email(@member, :from => :admin, :sender_name => @actor && @actor.visible_to?(@member) ? @actor.name(:name_only => true) : nil)
    super
  end

  register_tags do
    tag :list_of_mentors, :description => Proc.new{|program| "email_translations.group_member_removal_notification_to_removed_member.tags.list_of_mentors.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{"<a href='http://www.chronus.com'>William Smith</a>"} do
      group_member_links(@old_members_by_role[:mentors], false)
    end

    tag :list_of_mentees, :description => Proc.new{|program| "email_translations.group_member_removal_notification_to_removed_member.tags.list_of_mentees.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{"<a href='http://www.chronus.com'>John Doe</a>"} do
      group_member_links(@old_members_by_role[:mentees], false)
    end

    tag :list_of_members, :description => Proc.new{"email_translations.group_member_removal_notification_to_removed_member.tags.list_of_members.description".translate}, :example => Proc.new{"Mentors: <a href='http://www.chronus.com'>John Doe</a>"} do
      group_members_list_by_role(@members_by_role_hash, false)
    end

    tag :group_name, :description => Proc.new{|program| "email_translations.group_member_removal_notification_to_removed_member.tags.group_name.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{"email_translations.group_member_removal_notification_to_removed_member.tags.group_name.example".translate} do
      @group.name
    end

    tag :administrator_or_owner_name, :description => Proc.new{"email_translations.group_member_removal_notification_to_removed_member.tags.administrator_or_owner_name.description".translate}, :example => Proc.new { |program| "email_translations.group_member_removal_notification_to_removed_member.tags.administrator_or_owner_name.content".translate(program: program.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase, administrator: program.organization.admin_custom_term.term_downcase) } do
      (@actor.present? && @actor.is_owner_of?(@group)) ? @actor.name(name_only: true) : "email_translations.group_member_removal_notification_to_removed_member.tags.administrator_or_owner_name.content".translate(program: customized_subprogram_term, administrator: customized_admin_term)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.group_member_removal_notification_to_removed_member.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end
  end

  self.register!

end
