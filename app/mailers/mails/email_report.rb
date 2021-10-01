class EmailReport < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'jkv8t0dp', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{|program| "email_translations.email_report.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.email_report.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.email_report.subject".translate},
    :campaign_id  => CampaignConstants::EMAIL_REPORT_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :skip_default_salutation => true,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 10
  }

  def email_report(user_or_email, program, subject, email_body, attachment_name, attachment_content)
    @user_or_email = user_or_email
    @program = program
    @email_subject = subject
    @email_body = email_body
    @attachment_name = attachment_name
    @attachment_content = attachment_content
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    if @user_or_email.is_a?(User)
      set_username(@user_or_email)
      setup_email(@user_or_email, :from => :admin)
    else
      name = @user_or_email.email.split('@').first.capitalize
      set_username(nil, :name => name)
      setup_email(nil, :from => :admin, :email => @user_or_email.email)
    end
    attachments[@attachment_name] = @attachment_content
    super
  end

  register_tags do
    tag :subject, :description => Proc.new{'email_translations.email_report.tags.subject.description'.translate}, :example => Proc.new{'email_translations.email_report.tags.subject.example'.translate} do
      @email_subject
    end

    tag :body, :description => Proc.new{'email_translations.email_report.tags.body.description'.translate}, :example => Proc.new{'email_translations.email_report.tags.body.example'.translate} do
      @email_body
    end    
  end

  self.register!

end