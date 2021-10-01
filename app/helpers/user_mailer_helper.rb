module UserMailerHelper

  include Emails::LayoutHelper
  include Emails::AdminWeeklyStatusHelper
  include MailerExtensions::Setup

  LOGO_MAX_HEIGHT = 75
  LOGO_MIN_HEIGHT = 50
  LOGO_ASPECT_WIDTH = 250

  def view_helpers
    ActionController::Base.helpers
  end

  def process_tags(options = {})
    email_template = options[:email_template] || @internal_attributes[:email_template]
    names = ChronusActionMailer::Base.get_widget_tag_names(email_template)
    processed_tags    = process_tags_in_context(names[:tag_names])
    processed_widgets = process_widgets_in_context(names[:widget_names])
    return processed_tags.merge(processed_widgets)
  end

  def process_tags_in_context(tag_names, options = {})
    processed_tags = {}
    tag_names.each do|tag_name|
      begin
        processed_tags[tag_name.to_sym] = send(tag_name).to_s.force_encoding('UTF-8')
      rescue Exception => ex
        puts "-+- #{tag_name} -+-"
        raise ex
      end
    end
    if options[:dont_escape]
      processed_tags.each{ |key,val| processed_tags[key] = val.html_safe }
    else
      processed_tags
    end
  end

  def process_widgets_in_context(widget_names)
    processed_widgets = {}
    widget_names.each do |widget_name|
      processed_widgets[widget_name.to_sym] = process_widget_in_context(widget_name).to_s.force_encoding('UTF-8')
    end
    return processed_widgets
  end

  def process_widget_in_context(widget_name)
    widget = widget_name.camelize.constantize.send :new, self
    widget.process(@level)
  end

  # Welcome message email related  constants.
  module SignupNotificationConstants
    # Height of the image that is sent in the mail
    PICTURE_SIZE_HEIGHT = 40

    # These are constants for the images that are used in the welcome messages view file.
    ACT_ICONS = {
      'mentor_icon' => 'icons/mentor.png',
      'mentee_icon' => 'icons/mentee.png',
      'program-settings_icon' =>'icons/program-settings.png',
      'program_icon' => 'icons/program.png',
      'user_small_icon' => 'v3/user_small.jpg',
      'article_icon' => 'icons/article.png',
      'book_icon' => 'book-icon.gif',
      'question_icon' => 'question.jpg'
    }
  end

  def html_line_break
    '<br/>'.html_safe
  end

  def program_logo
    # Add program logo if available, and not if email from 'Chronus Mentor'
    set_level_object
    return if @level_object.logo_or_banner_url.blank?

    logo_or_banner_url = ImportExportUtils.file_url(@level_object.logo_or_banner_url)
    image_options = {
      id: 'program-logo-or-banner',
      height: get_logo_height(logo_or_banner_url),
      alt: "emails.default_content.program_logo".translate(program: @organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term.to_s.force_encoding('UTF-8')),
      align: 'left',
      hspace: '10',
      style: 'max-width: 90% !important;'
    }
    logo_code = image_tag(logo_or_banner_url, image_options)

    if @level_object == @program
      link_to(logo_code, program_root_url(:subdomain => @organization.subdomain, :root => @program.root)).html_safe
    else
      link_to(logo_code, root_organization_url(:subdomain => @organization.subdomain)).html_safe
    end
  end

  # Height of the logo in system mail is determined by resizing the image to the LOGO_ASPECT_WIDTH and get the aspect height and then the height should be minimum of LOGO_MAX_HEIGHT and dimension height and it should not be lesser than LOGO_MIN_HEIGHT.
  def get_logo_height(logo_or_banner_url)
    begin
      geometry = Paperclip::Geometry.from_file(logo_or_banner_url)
      height = geometry.resize_to("#{LOGO_ASPECT_WIDTH}x#{geometry.height.to_i}").height.to_i
    rescue => _ex
      height = LOGO_MIN_HEIGHT
    end
    height = [height, LOGO_MAX_HEIGHT].min
    return [height, LOGO_MIN_HEIGHT].max.to_s
  end

  # Returns the notification settings text to be placed in the footer of an email.
  def notification_settings_link
    settings_url = if @program.nil?
      # Member settings. Take to organization profile settings page. If
      # standalone, the user will be redirected to the sub program he/she
      # belongs to.
      account_settings_url(subdomain: @organization.subdomain)
    else
      edit_member_url(@user.member, section: MembersController::EditSection::SETTINGS, subdomain: @organization.subdomain, root: @program.root, focus_notification_tab: true, scroll_to: NOTIFICATION_SECTION_HTML_ID)
    end
    settings_link = link_to("display_string.Click_here".translate, settings_url, style: "color: #1798C1 !important;")
    content_tag(:span, "feature.email.content.modify_your_notifications_v1_html".translate(click_here: settings_link))
  end

  def contact_admin_link
    contact_link = get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, host: @organization.domain, root: @program.root, src: 'email' } )
    content_tag(:span, "feature.email.content.contact_admin_for_any_queries_v2_html".translate(contact_admin: contact_link))
  end

  # Prepares the template for mail content (given block) to be delivered to the
  # given user
  #
  # ==== Params
  # options[:show_change_notif_link] - true if 'Change notification settings'
  # link is to be shown
  #
  def email_template(options = {}, &block)
    options ||= {}
    set_host_name_for_urls(@organization, @program)
    @show_change_notif_link = options[:show_change_notif_link]
    @show_mentoring_area_notif_setting = options[:show_mentoring_area_notif_setting]
    if @program && @level == EmailCustomization::Level::PROGRAM
      program_name = @program.name
      @program_url = program_root_url(:subdomain => @organization.subdomain)
    else
      program_name = @organization.name
      @program_url = root_organization_url(:subdomain => @organization.subdomain)
    end
    @program_or_organization_link = link_to(program_name.to_s.force_encoding('UTF-8'),
      @program_url, :style => 'color: #666666; text-decoration: none;')
    concat(email_body(options, &block))
  end

  def do_not_reply
    content_tag(:span, "feature.email.content.automated_email_hint_v1_html".translate)
  end

  def email_footer_logo
    return nil if @organization.present? && @organization.white_label
    content_tag(:td, {:align => "left", :width => "100px"}) do
      content_tag(:a, @program_url, {:target => "_blank"}) do
        image_tag(APP_CONFIG[:powered_by_chronus], {:alt => "emails.default_content.logo".translate, :width => "90", :style => "display: block; font-family: Helvetica, Arial, sans-serif; color: #666666; font-size: 14px;", :border => "0"})
      end
    end
  end

  def download_mobile_apps_info
    return nil unless @organization.present? && @organization.mobile_view_enabled?
    content_tag(:tr) do
      content_tag(:td, {:align => "left", :style => "padding-top:15px;"}) do
        link_to(image_tag(APP_CONFIG[:android_app_google_play_icon]), android_app_store_link(@organization, CordovaHelper::AndroidAppStoreSource::EMAIL), :style => "padding-right:5px;", :target => "_blank") +
        link_to(image_tag(APP_CONFIG[:ios_app_store_icon]), APP_CONFIG[:ios_chronus_app_store_link], :target => "_blank")
      end
    end
  end

  def email_body(options = {}, &block)
    # The class is added to facilitate extraction of email body in plain text format.
    # Please do not add styles to the class, since only inline styles are supported by many email clients
    content_tag(:div, :style => "margin-bottom: #{options[:email_body_margin_bottom] || '5px'};", :class => 'email_content') do
      mail_body = "".html_safe
      # The gsub is to strip out html comments from the passed block
      if @email_template_erb
        mail_body << ERB.new(@email_template_erb).result(binding).gsub(/\<!\s*--(.*?)(--\s*\>)/m, '').html_safe
      else
        mail_body << capture(&block).gsub(/\<!\s*--(.*?)(--\s*\>)/m, '').html_safe
      end
      mail_body.html_safe
    end
  end

  def links_at_bottom
    links = []
    links << notification_settings_link if @show_change_notif_link || @show_mentoring_area_notif_setting
    links << contact_admin_link if @program && (@user.blank? || !@user.is_admin? || (@user.is_admin? && !@user.active?))
    links << html_line_break
    safe_join(links, " ")
  end

  def header(text, opts = {})
    header_style = "color: #992222; margin: 10px 0 5px;font-size: 1.1em; #{opts[:style]}"
    content_tag(:h3, text, :style => header_style)
  end

  def user_link_in_email(user)
    link_to(user.name, member_url(user.member, :subdomain => @organization.subdomain)).html_safe
  end

  # UL list with styles
  #
  #   list do
  #   end
  #
  # generates..
  #   <ul>
  #   </ul>
  #
  def list(html_opts = {}, &block)
    ul_style = "list-style-type: square; list-style-position: inside; padding: 0;margin: 0 0 0 20px;"
    concat(content_tag(:ul, capture(&block), html_opts.merge(:style => ul_style)))
  end

  # LI list item with styles
  #
  #   list do
  #     list_item do
  #       First item
  #     end
  #     list_item do
  #       Second item
  #     end
  #   end
  #
  # generates..
  #   <ul>
  #     <li>
  #       First item
  #     </li>
  #     <li>
  #     Second item
  #     </li>
  #   </ul>
  #
  def list_item(&block)
    concat(content_tag(:li, capture(&block)))
  end

  # Grayed text mostly used for text like 'posted by Abc'
  def grayed_text(text)
    content_tag(:span, text, :style => "color:#666666;font-size:0.8em;")
  end

  # Horizontal divider line.
  def divider
    content_tag(:div, "", :style => 'height: 2px; border-bottom: 1px dotted #666666; margin: 10px 0;')
  end

  # Renders the user's picture in the email.
  def user_picture_in_email(user, options = {}, image_options = {})
    user_picture(user, options.merge(:mail_view => true), image_options).html_safe
  end

  def member_picture_in_email(member, options = {}, image_options = {})
    member_picture_v3(member, options, image_options).html_safe
  end

  def notification_email_to_mentor_group_member_links(students)
    group_members = ["display_string.you".translate] + students.collect {|student| user_link_in_email(student)}
    group_members.to_sentence.html_safe
  end

  def notification_email_to_student_group_member_links(mentors)
    group_members = ["display_string.you".translate] + mentors.collect {|mentor| user_link_in_email(mentor)}
    group_members.to_sentence.html_safe
  end

  # Returns a sentence containing links to *members*
  def group_member_links(members, include_self = true)
    group_members = (include_self ? ["display_string.you".translate] : [])
    group_members += members.collect {|member| user_link_in_email(member)}
    group_members.to_sentence.html_safe
  end

  def group_members_list_by_role(members_by_role_hash, include_self = true, options = {})
    table_body = []
    members_by_role_hash.each do |role_term, members|
      row_content = content_tag(:td, role_term + ":", style: "color:#666666;font-weight: bold;") +
                    content_tag(:td, group_member_links(members, include_self), style: "width: 300px;")
      table_body << content_tag(:tr, row_content, valign: "top")
    end
    content_tag(:table, table_body.join(" ").html_safe,
      cellspacing: options[:cellspacing] || 0,
      cellpadding: options[:cellpadding] || 5,
      style: options[:style] || "padding: 0.6em; background-color: #F0F5D5; border: 1px dotted #CCCCCC; font-size: 0.9em; margin-left: 20px; margin-top: 10px;"
    )
  end

  def render_members_list_partial(members_by_role_hash, viewing_user)
    roles = members_by_role_hash.keys
    member_hash_list = []
    roles.each do |role|
      members_by_role_hash[role].each do |member|
        member_hash_list << member if viewing_user.id != member.id
      end
    end
    render('/connection_members_list', :row_users => member_hash_list, :viewing_user => viewing_user)
  end

  def display_mentor_request_to_mentor(mentor_request)
    return unless mentor_request

    content_tag(:div, :style => "margin: 5px 10px; padding-left: 5px; border-left: 1px solid #CCC;") do
      ("#{'feature.email.content.help_requested'.translate}<br> ".html_safe + image_tag("#{EMAIL_IMAGE_URL}/assets/s_quote.gif") + mentor_request.message).html_safe
    end
  end

  def connection_membership_pending_notification_text(pending_notification, options = {})
    case pending_notification.action_type
    when RecentActivityConstants::Type::USER_SUSPENSION
      "email_translations.digest_v2.connection_membership_notification.user_suspension".translate(name: pending_notification.ref_obj.name(name_only: true))
    when RecentActivityConstants::Type::GROUP_MEMBER_LEAVING
      "email_translations.digest_v2.connection_membership_notification.member_leaving".translate(name: pending_notification.ref_obj.name(name_only: true))
    when RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
      "email_translations.digest_v2.connection_membership_notification.member_update".translate
    when RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE
      "email_translations.digest_v2.connection_membership_notification.change_expiry_date".translate(date: DateTime.localize(pending_notification.ref_obj.expiry_time.in_time_zone(options[:user_time_zone]), format: :abbr_short))
    when RecentActivityConstants::Type::TOPIC_CREATION, RecentActivityConstants::Type::POST_CREATION
      topic_name = pending_notification.ref_obj.is_a?(Topic) ? pending_notification.ref_obj.title : pending_notification.ref_obj.topic.title
      "email_translations.digest_v2.connection_membership_notification.topic_discussion".translate(topic_name: topic_name)
    when RecentActivityConstants::Type::MENTORING_MODEL_TASK_CREATION
      "email_translations.digest_v2.connection_membership_notification.task_creation".translate(title: pending_notification.ref_obj.title)
    end
  end

  def digest_v2_url_for_connection_update(pending_notification, group, url_options)
    if [RecentActivityConstants::Type::TOPIC_CREATION, RecentActivityConstants::Type::POST_CREATION].include?(pending_notification.action_type)
      forum_url(group.forum, url_options)
    else
      group_url(group, url_options.merge(show_plan: true))
    end
  end

  def raise_if_erb(content)
    raise "+ #{"feature.email.error.erb_in_mailer_views".translate} +" if content.regex_scan?("<%")
  end

  def get_hidden_text(email_text)
    return Nokogiri::HTML(email_text).text.gsub(/http(s?):\/\/[\w\.:\/]+/, '')[0..100]
  end

  def set_level_object
    @level_object = (@level == EmailCustomization::Level::PROGRAM && @program) ? @program : @organization
  end

  def get_sender_name(sender)
    member = sender.is_a?(User) ? sender.member : sender
    sender.name(name_only: member.is_chronus_admin?)
  end

  def url_options_for_recommendations(program)
    organization = program.organization
    return {subdomain: organization.subdomain, domain: organization.domain, root: program.root, src: EngagementIndex::Src::VisitMentorsProfile::CAMPAIGN_WIDGET_RECOMMENDATIONS}
  end
end
