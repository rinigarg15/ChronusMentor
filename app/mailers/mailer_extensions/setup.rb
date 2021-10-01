module MailerExtensions
  include TranslationsService

  module Setup

    def set_username(user_or_member, options = {})
      # using user object if present to set variables else using name passed as option
      if user_or_member.present?
        @user_name = user_or_member.name(name_only: options[:name_only])
        @user_first_name = user_or_member.first_name
        @user_last_name = user_or_member.last_name
      else
        @user_name = options[:name]
        @user_first_name = options[:first_name] || options[:name].split(" ").first
        @user_last_name = options[:last_name] || options[:name].split(" ").last
      end
    end

    def set_program(program)
      @subject ||= ''
      @program = program
      @organization = @program.organization
      set_host_name_for_urls(@organization, @program)
      set_customized_terms
    end

    def set_customized_terms
      scope = @program.present?  ? @program : @organization
      TranslationsService::initialize_custom_terms(self, scope, "_string")
    end

    def set_host_name_for_urls(organization, program = nil)
      if organization.present?
        ActionMailer::Base.default_url_options[:host] = organization.domain
      else
        ActionMailer::Base.default_url_options[:host] = DEFAULT_HOST_NAME
      end
      ActionMailer::Base.default_url_options[:protocol] = "https"

      if program.present?
        ActionMailer::Base.default_url_options[:root] = program.root
        @current_root = program.root
      else
        ActionMailer::Base.default_url_options.delete(:root)
        @current_root = nil
      end

      if @set_locale.blank?
        ActionMailer::Base.default_url_options.delete(:set_locale)
      end
    end

    def setup_email(user = nil, options = {})
      @user = user if user && user.is_a?(User)

      setup_from_subject_and_sent_on(options)
      @recipients = user ? "#{user.email}" : "#{options[:email]}"
      @cc = @sender.is_a?(String) ? @sender : @sender.email if @sender.present? && @organization.audit_user_communication? && options[:message_type] == EmailCustomization::MessageType::COMMUNICATION
    end

    def setup_from_subject_and_sent_on(options = {})
      program_name = @program.try(:name) || @organization.name
      from_name =
        if options[:sender_name].present?
          options[:direct_sender_name].present? ? options[:sender_name] : "feature.email.content.sender_via_program_html".translate(:sender_name => options[:sender_name].html_safe, :program => program_name.html_safe)
        else
          program_name
        end
      from_address = get_email_from_address(@organization)
      from_address.display_name = from_name
      @from = from_address.format.html_safe
      @subject = ""
      #TODO Do we need them any more
      @program_link = helpers.link_to(@program.name, program_root_url(:subdomain => @organization.subdomain)).html_safe if @program
      @sent_on = Time.now
      @date = Time.now
    end

    def setup_recipient_and_organization(member, organization, program = nil)
      @member = member
      @organization = organization
      set_customized_terms

      if program
        @program = program
      elsif @organization.standalone? && @member && @member.active_programs.size == 1
        # If the member belongs to only one sub program, set @program to it so
        # that the mail is delivered as though from the sub program.
        @program = @member.active_programs.first
      end

      # Find the +User+ corresponding to @member in the program.
      @user = @member.user_in_program(@program) if @member && @program

      set_host_name_for_urls(@organization, @program)

      if @program
        @program_link = helpers.link_to(@program.name, program_root_url(:subdomain => @organization.subdomain, :root => @program.root)).html_safe
      elsif @organization
        @program_link = helpers.link_to(@organization.name, root_organization_url(:subdomain => @organization.subdomain)).html_safe
      end
    end

    def set_sender(options)
      @sender = options[:sender]
    end

    private

    def get_email_from_address(organization)
      email_address = organization.get_from_email_address
      Mail::Address.new email_address
    end
  end
end