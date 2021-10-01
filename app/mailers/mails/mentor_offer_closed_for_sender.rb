class MentorOfferClosedForSender < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'oqrkeoij', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_OFFERS,
    :title        => Proc.new{|program| "email_translations.mentor_offer_closed_for_sender.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_offer_closed_for_sender.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_offer_closed_for_sender.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :feature      => FeatureName::OFFER_MENTORING,
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.mentor_offer_needs_acceptance?},
    :campaign_id_2  => CampaignConstants::MENTOR_OFFER_CLOSED_FOR_SENDER_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :for_role_names => [RoleConstants::MENTOR_NAME],
    :listing_order => 5
  }

  def mentor_offer_closed_for_sender(mentor, mentor_offer, options={})
    @mentor = mentor
    @mentor_offer = mentor_offer
    @program = mentor_offer.program
    @student = mentor_offer.student
    @closed_by = @mentor_offer.closed_by
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@mentor, :name_only => true)
    setup_email(@mentor, :from => :admin, :sender_name => @closed_by && @closed_by.visible_to?(@mentor) ? @closed_by.name(:name_only => true) : nil)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :recipient_name, :description => Proc.new{'email_translations.mentor_offer_closed_for_sender.tags.recipient_name.description'.translate}, :example => Proc.new{'William Smith'} do
      @student.name
    end

    tag :url_mentees_listing, :description => Proc.new{'email_translations.mentor_offer_closed_for_sender.tags.url_mentees_listing.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      users_url(:view => RoleConstants::STUDENT_NAME, :subdomain => @organization.subdomain)
    end

    tag :message_from_admin, :description => Proc.new{'email_translations.mentor_offer_closed_for_sender.tags.message_from_admin.description'.translate}, :example => Proc.new{'email_translations.mentor_request_closed_for_sender.tags.message_from_admin.example'.translate} do
      @mentor_offer.response.presence || ""
    end

    tag :message_from_admin_as_quote, :description => Proc.new{'email_translations.mentor_offer_closed_for_sender.tags.message_from_admin_as_quote.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.mentor_offer_closed_for_sender.tags.message_from_admin_as_quote.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      @mentor_offer.response.present? ? 'feature.email.tags.message_from_user_v3_html'.translate( :message => @mentor_offer.response, :name => @closed_by.present? ? @closed_by.name : @organization.admin_custom_term.term ) : ""
    end
  end

  self.register!

end
