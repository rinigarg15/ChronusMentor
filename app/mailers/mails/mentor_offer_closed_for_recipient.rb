class MentorOfferClosedForRecipient < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '8jsj6pgi', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_OFFERS,
    :title        => Proc.new{|program| "email_translations.mentor_offer_closed_for_recipient.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_offer_closed_for_recipient.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_offer_closed_for_recipient.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :feature      => FeatureName::OFFER_MENTORING,
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.mentor_offer_needs_acceptance?},
    :campaign_id_2  => CampaignConstants::MENTOR_OFFER_CLOSED_FOR_RECIPIENT_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :for_role_names => [RoleConstants::STUDENT_NAME],
    :listing_order => 6
  }

  def mentor_offer_closed_for_recipient(student, mentor_offer, options={})
    @student = student
    @mentor_offer = mentor_offer
    @program = mentor_offer.program
    @sender = mentor_offer.mentor
    @closed_by = @mentor_offer.closed_by
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@student, :name_only => true)
    setup_email(@student, :from => :admin, :sender_name => @closed_by && @closed_by.visible_to?(@student) ? @closed_by.name(:name_only => true) : nil)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :sender_name, :description => Proc.new{'email_translations.mentor_offer_closed_for_recipient.tags.sender_name.description'.translate}, :example => Proc.new{'William Smith'} do
      @sender.name
    end

    tag :message_from_admin, :description => Proc.new{'email_translations.mentor_offer_closed_for_recipient.tags.message_from_admin.description'.translate}, :example => Proc.new{'email_translations.mentor_offer_closed_for_recipient.tags.message_from_admin.example'.translate} do
      @mentor_offer.response.presence || ""
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.mentor_offer_closed_for_recipient.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@student.program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :root => @student.program.root}})
    end

    tag :message_from_admin_as_quote, :description => Proc.new{'email_translations.mentor_offer_closed_for_recipient.tags.message_from_admin_as_quote.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.mentor_offer_closed_for_recipient.tags.message_from_admin_as_quote.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      @mentor_offer.response.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @mentor_offer.response, :name => @closed_by.name) : ""
    end

    tag :sender_url, :description => Proc.new{'email_translations.mentor_offer_closed_for_recipient.tags.sender_name.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      user_url(@sender, subdomain: @organization.subdomain, root: @program.root)
    end
  end

  self.register!

end
