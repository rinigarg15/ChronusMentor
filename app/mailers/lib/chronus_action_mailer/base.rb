module ChronusActionMailer
  class Base < ActionMailer::Base
    self.append_view_path('app/mailers/views')
    attr_accessor :internal_attributes
    @@mailer_uids = {}
    @mailer_attributes = {}

    include ApplicationHelper
    include UserMailerHelper
    include EmailTheme
    include MailerExtensions::Setup

    helper ApplicationHelper
    helper ProgramsHelper
    helper UsersHelper
    helper UserMailerHelper

    EMAIL_LAYOUT = "default_banner_on_top_email"
    ICS_CONTENT_TYPE = "text/calendar"
    DIGEST_V2_EMAIL_LAYOUT = "digest_v2_email_layout"

    def mailer_attributes
      self.class.mailer_attributes
    end

    def self.mailer_attributes
      @mailer_attributes ||= self.class.instance_variable_get('mailer_attributes')
    end

    def self.get_for_role_names_ary(*args)
      for_role_names = mailer_attributes[:for_role_names]
      if for_role_names.is_a?(Array)
        for_role_names
      elsif for_role_names.respond_to?(:call)
        for_role_names.call(*args)
      else
        []
      end
    end

    def self.prog_template(prog)
      prog.mailer_templates.find_by(uid: self.mailer_attributes[:uid])
    end

    def self.org_template(org)
      org.mailer_templates.find_by(uid: self.mailer_attributes[:uid])
    end

    def self.register!
      self.mailer_attributes[:tags] ||= {}
      self.mailer_attributes[:tags][:specific_tags] ||= {}
      self.set_mailer_name
      set_view_path
      self.register_uid
    end

    def self.register_tags(name = :specific_tags, &block)
      @tag_name = name
      mailer_attributes[:tags] ||= {}
      mailer_attributes[:tags][name] = {}
      block.call
    end

    def self.tag(name, details, &block)
      mailer_attributes[:tags][@tag_name][name] = details
      validate_tag_details(details)
      define_method(name, &block)
      helper do
        define_method(name, &block)
      end
    end

    def validate_tag_details(details)
      raise 'feature.email.error.description_missing'.translate unless details.has_key?(:description)
      raise 'feature.email.error.tag_missing_html'.translate unless details.has_key?(:example) || details.has_key?(:eval_tag)
    end

    Dir[Rails.root.join("app/mailers/tags/*.rb")].each do |f|
      load f
    end

    def self.get_descendants
      @mailer_descendants ||= Dir[Rails.root.join("app/mailers/mails/**/*.rb")].collect do |f|
        File.basename(f,'.rb').camelize.constantize
      end
    end

    def self.get_descendant(uid)
      get_descendants.find{|e| e.mailer_attributes[:uid] == uid}
    end

    def self.always_enabled?(uid)
      return if uid.nil?

      mailer = get_descendant(uid)
      mailer.try(:mailer_attributes).try(:[], :always_enabled)
    end

    def helpers
      ActionController::Base.helpers
    end

    def build_mail
      set_campaigns_in_header if self.mailer_attributes[:campaign_id]

      # Send custom data as a hash
      set_custom_data_in_header

      mail_content = self.internal_attributes[:email].force_encoding("UTF-8")
      @email = mail(to: @recipients, subject: self.internal_attributes[:subject], cc: @cc, from: @from, sender: @from, reply_to: @reply_to, date: @date) do |format|
        format.text { Premailer.new(mail_content.to_s, :with_html_string => true).to_plain_text }
        format.html { Premailer.new(mail_content, :with_html_string => true).to_inline_css }
      end
      add_calendar_event_to_mail
      @email
    end

    def add_calendar_event_to_mail
      if @calendar_body.present?
        calendar_body = @calendar_body
        request_type = @calendar_request_type
        @email.add_part(Mail::Part.new do
          content_type "#{ICS_CONTENT_TYPE}; method=#{request_type}"
          body calendar_body
        end)
      end
    end


    def self.set_mailer_name
      self.mailer_attributes[:mailer_name] = self.name.underscore
    end

    def self.set_view_path
      self.mailer_attributes[:view_path] = Rails.root.join('app', 'mailers', 'views', self.mailer_attributes[:mailer_name] + '.html.erb')
    end

    def self.register_uid
      uid = self.mailer_attributes[:uid]
      mailer_name = self.mailer_attributes[:mailer_name]
      raise "feature.email.error.duplicate_uid_desc".translate(mailer_name: mailer_name, uid: uid, mailer_uids: @@mailer_uids[uid]) if @@mailer_uids.keys.include?(uid) && @@mailer_uids[uid] != mailer_name
      @@mailer_uids[uid] = mailer_name
    end

    def self.get_tags_from_email
      total_content = self.mailer_attributes[:subject].call +
        default_email_content_from_path(self.mailer_attributes[:view_path])
      tag_names = get_widget_tag_names(total_content)[:tag_names].collect(&:to_sym)
      tag_names += get_global_and_specfic_tags
      tag_names += get_subprogram_tags
      tag_names += get_other_registered_tags
      self.all_tags.slice(*tag_names)
    end

    def self.get_global_and_specfic_tags
      ChronusActionMailer::Base.mailer_attributes[:tags][:global_tags].keys + self.mailer_attributes[:tags][:specific_tags].keys
    end

    def self.get_subprogram_tags
      return [] unless self.mailer_attributes[:level] == EmailCustomization::Level::PROGRAM
      ChronusActionMailer::Base.mailer_attributes[:tags][:subprogram_tags].keys
    end

    def self.get_other_registered_tags
      (self.mailer_attributes[:other_registered_tags]||[]).collect do |registered_tags|
        ChronusActionMailer::Base.mailer_attributes[:tags][registered_tags].keys
      end.flatten.compact
    end

    # Here we can add more tags, this is currently used to skip validations
    def self.get_customized_tags
      ChronusActionMailer::Base.mailer_attributes[:tags][:customized_terms_tags]
    end

    def self.get_widgets_from_email
      total_content = default_email_content_from_path(self.mailer_attributes[:view_path])
      widget_names = get_widget_tag_names(total_content)[:widget_names]
      return_hash = {}

      widget_names.sort.each{|name| return_hash[name.to_sym] = name.camelize.constantize.widget_attributes[:description]}
      return_hash
    end

    def self.all_tags
      tags = {}
      ChronusActionMailer::Base.mailer_attributes[:tags].each do |_tag, values|
        tags.merge!(values)
      end
      tags.merge!(self.mailer_attributes[:tags][:specific_tags].dup) unless self.mailer_attributes[:tags][:specific_tags].nil?
      (self.mailer_attributes[:excluded_tags] || []).each do |tag|
        tags.except!(tag)
      end
      return tags
    end

    def self.get_widget_tag_names(content)
      all_tag_names     = get_tokens_from(content.to_s)
      widget_names      = all_tag_names.select {|name| name =~ /^widget_/}
      tag_names         = all_tag_names - widget_names
      {:widget_names => widget_names, :tag_names => tag_names}
    end

    def self.default_email_content_from_path(path)
      ERB.new(wrap_with_salutation_signature(IO.read(path))).result.force_encoding("UTF-8")
    end

    def self.wrap_with_salutation_signature(block)
      ary = [block.html_safe]
      ary.unshift(header_salutation) unless mailer_attributes[:no_header_salutation]
      ary << "<br/>{{widget_signature}}".html_safe unless mailer_attributes[:no_widget_signature]
      ary.join
    end

    def self.header_salutation
      salutation_message = "".html_safe
      salutation_message << ("feature.email.salutation_signature_v1".translate + ",<br/><br/>").html_safe unless self.mailer_attributes[:skip_default_salutation].present?
    end

    def self.compute_subject_and_email(organization, program = nil)
      org_template = self.org_template(organization)
      prog_template = self.prog_template(program) if program
      {
        :subject_template => ERB.new(get_subject_template(org_template, prog_template)).result,
        :email_template   => ERB.new(get_email_template(org_template, prog_template)).result
      }
    end

    def self.get_subject_template(org_template, prog_template)
      template = prog_template || org_template
      (template && template.subject.presence) || mailer_attributes[:subject].call
    end

    def self.get_email_template(org_template, prog_template)
      template = prog_template || org_template
      (template && template.source.presence) ||
        default_email_content_from_path(self.mailer_attributes[:view_path])
    end

    def init_mail
      self.internal_attributes = self.class.compute_subject_and_email(@organization, @program)
      # add widget style only we are ready to send email
      self.internal_attributes[:email_template] += "{{widget_styles}}"
    end

    def set_email_subject_and_message_internal_attributes(params)
      self.internal_attributes ||= {}
      self.internal_attributes = {
        :subject_template => params[:subject],
        :email_template   => params[:content] 
      }
    end

    def set_icalendar_body(meeting, options = {})
      ics_action = options[:ics_action].present? ? options[:ics_action] : Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT
      if meeting.can_be_synced?(ics_action == Meeting::IcsCalendarScenario::CANCEL_EVENT)
        @calendar_request_type = ics_action == Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT ? CalendarUtils::REQUEST_TYPE::REQUEST : CalendarUtils::REQUEST_TYPE::CANCEL
        @calendar_body = meeting.generate_ics_calendar(false, ics_action, user: options[:user], current_occurrence_time: options[:current_occurrence_time])
      end
    end

    def set_program_event_icalendar_body(program_event, options = {})
      return unless program_event.can_be_synced?
      @calendar_request_type = CalendarUtils::REQUEST_TYPE::REQUEST
      @calendar_body = CalendarIcsGenerator.generate_ics_calendar(program_event, user: options[:user], current_occurrence_time: options[:current_occurrence_time])
    end

    def set_program_event_icalendar_body_for_deletion(options = {})
      program = Program.find(options[:program_id])
      return unless APP_CONFIG[:calendar_api_enabled] && program.calendar_sync_enabled?
      @calendar_request_type = CalendarUtils::REQUEST_TYPE::CANCEL
      @calendar_body = CalendarIcsGenerator.generate_ics_calendar_for_deletion(options)
    end

    def render_mail
      set_mail_level
      compute_subject
      initilize_email_theme_colors
      compute_email
      build_mail
    end

    def set_mail_level
      @level = self.mailer_attributes[:level]
    end

    def set_layout_options(options = {})
      internal_attributes[:layout_options] = options
    end

    def set_custom_data(custom_hash)
      self.mailer_attributes[:custom_data] = custom_hash
    end

    def set_campaigns_in_header
      headers["X-Mailgun-Tag"] = self.mailer_attributes[:campaign_id]
      #Remove campaign_id_2 after gathering data to avoid extra costs
      headers["X-Mailgun-Tag"] = self.mailer_attributes[:campaign_id_2] if self.mailer_attributes[:campaign_id_2]
      headers["X-Mailgun-Tag"] = self.mailer_attributes[:campaign_id_3] if self.mailer_attributes[:campaign_id_3]
    end

    # Input the custom data as a hash
    def set_custom_data_in_header
      if self.mailer_attributes[:custom_data]
        headers["X-Mailgun-Variables"] = self.mailer_attributes[:custom_data].to_json 
      end
    end

    def set_preview_facilitation_message(facilitation_message, preview_tag_options = {})
      # @admin_message is needed to render message_subject and message_content tags to preview facilitation message.
      @admin_message = facilitation_message
      return unless @admin_message.try(:content).present?

      @admin_message.content = render_tags(nil, preview_tag_options.merge(facilitation_message: facilitation_message))[1]
    end


    def compute_subject
      subject_template              = internal_attributes[:subject_template]
      email_tokens                  = self.class.get_tokens_from(subject_template)
      internal_attributes[:subject] = Mustache.render(subject_template, process_tags_in_context(email_tokens, :dont_escape => true))
      @reply_to_subject = internal_attributes[:subject]
    end

    def self.get_tokens_from(template)
      tokens = []
      all_tokens = Mustache::Parser.new.compile(template).flatten
      all_tokens.each_with_index do |token, index|
        if token == :fetch
          fetch_token = all_tokens[index + 1]
          tokens << fetch_token
        end
      end
      return tokens
    end

    def compute_email
      internal_attributes[:email] = render(:partial => 'mailers/mailer_layout', :locals => internal_attributes.slice(:layout_options, :email_template), :layout => (mailer_attributes[:layout] || EMAIL_LAYOUT))
    end

    def setup_render_params(user, member, program, organization, options = {})
      self.internal_attributes = {}
      @program = program
      @organization = organization
      @user = user
      @member = member
      @user_in_context = user || member
      @level = options[:level]

      program.present? ? set_program(@program) : setup_recipient_and_organization(@member, @organization)

      setup_email(@user_in_context,options)
      set_username(@user_in_context)
      set_preview_facilitation_message(options[:facilitation_message], options[:preview_tag_options])
    end

    def get_template_content_and_tag_names(mailer_template_obj, facilitation_message)
      subject_template, email_template =  if facilitation_message.present?
                                            ["", facilitation_message.content]
                                          elsif mailer_template_obj.present?
                                            [mailer_template_obj.subject, mailer_template_obj.source + '{{widget_styles}}']
                                          end
      [subject_template, email_template, self.class.get_widget_tag_names(subject_template + email_template)]
    end

    def render_tags(mailer_template_obj, options = {})
      subject_template, email_template, widget_plain_tags = get_template_content_and_tag_names(mailer_template_obj, options[:facilitation_message])
      tag_names = widget_plain_tags[:tag_names].collect(&:to_sym)
      tag_names << options[:additional_tags] if options[:additional_tags]
      widget_tag_names = widget_plain_tags[:widget_names]

      template_tags = get_tags_in_template(tag_names, options)
      processed_widget_hash = process_widgets_in_context(widget_tag_names)
      template_tags.merge!(processed_widget_hash)

      subject_content = Mustache.render(subject_template, template_tags_for_subject(template_tags))
      preview_content = Mustache.render(email_template, template_tags)

      # Links have to be wrapped around anchor tags for the mailgun clicks track to work. Using rinku auto_link for that
      return subject_content, Rinku.auto_link(preview_content), template_tags
    end

    def get_tags_in_template(tag_names, options = {})
      all_tags = self.class.all_tags.slice(*tag_names)
      template_tags = {}
      all_tags.keys.each do |tag|
        if options[:preview]
          template_tags[tag] = evaluate_preview_tag(all_tags, tag, options)
        else
          template_tags[tag] = send(tag).to_s.force_encoding('UTF-8')
        end
      end
      template_tags
    end

    def template_tags_for_subject(template_tags)
      subject_tags = {}
      template_tags.each{ |key,val| subject_tags[key] = val.html_safe }
      subject_tags
    end

    def evaluate_preview_tag(all_tags, tag, options = {})
      if all_tags[tag][:eval_tag].present?
        send(tag).to_s.force_encoding('UTF-8')
      else
        (all_tags[tag][:example].call(options[:program], options[:organization])).html_safe
      end
    end

    def preview(user, member, program, organization, options = {})
      mailer_template_obj = options.delete(:mailer_template_obj)
      options[:preview_tag_options] = get_preview_tags_options(program, organization)
      setup_render_params(user, member, program, organization, options)
      initilize_email_theme_colors
      subject_content, message_content, _template_tags = render_tags(mailer_template_obj, options[:preview_tag_options])
      preview_layout = render(:partial => 'mailers/mailer_preview', :locals => {:content => message_content}, :layout => EMAIL_LAYOUT)
      mail(to: @user_in_context.email, subject: subject_content, cc: @cc, from: @from, sender: @from, reply_to: @reply_to, date: @date) do |format|
        format.text { Premailer.new(preview_layout, :with_html_string => true).to_plain_text }
        format.html { Premailer.new(preview_layout, :with_html_string => true).to_inline_css }
      end
    end

    def get_preview_tags_options(program, organization)
      {preview: true, program: program, organization: organization}
    end

    def self.call_to_action_example(link_text, button_class="button-large")
      "<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" class=\"mobile-button-container\" width=\"100%\"><tbody><tr><td align=\"left\" class=\"padding-copy\" style=\"padding: 35px 0px 10px 0px;\"><table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" class=\"responsive-table\"><tbody><tr><td align=\"center\"><a href=\"http://www.chronus.com\" class=\"#{button_class}\" target=\"_blank\">#{link_text} &rarr;</a></td></tr></tbody></table></td></tr></tbody></table>".html_safe
    end
  end
end