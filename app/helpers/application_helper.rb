module ApplicationHelper
  include PrototypeHelper
  include FormErrorHelper
  include ChronusSanitization::HelperMethods

  IMAGE_INITIALS = {
    0 => "grey_and_cream",
    1 => "light_grey_and_violet",
    2 => "blue_and_white",
    3 => "white_and_grey",
    4 => "green_and_grey",
    5 => "cream_and_grey",
    6 => "violet_and_light_grey",
    7 => "white_and_blue",
    8 => "grey_and_white",
    9 => "grey_and_green"
  }

  NAVIGATION_SIDEBAR_TRUNCATE_LENGTH = 36

  # Fixing a bug in prototype-legacy-helper gem.
  # The helper 'form_for' raises error when you don't pass the :html option.
  # Setting it to empty hash when it is nill
  def apply_form_for_options!(record, object, options)
    options[:html] ||= {}
    super(record, object, options)
  end

  def set_gray_background
    @lightGrayBackground = true
  end

  def viewport_meta_tag
    scaling_attributes = mobile_device? ? ", maximum-scale=1.0, user-scalable=no" : ""
    tag(:meta, name: "viewport", content: "width=device-width, initial-scale=1.0#{scaling_attributes}")
  end

  # Returns the default value if the text is blank and the text itself,
  # otherwise.
  def default_if_blank(text, default_value)
    text.blank? ? default_value : text
  end

  def render_logo_or_banner(program_context, options = {})
    asset_url, asset_type = program_context.logo_or_banner_url([:logo, :banner], true)
    alt_text =
      if asset_type == :logo
        "program_settings_strings.header.program_logo".translate(Program: _Program)
      elsif asset_type == :banner
        "program_settings_strings.header.program_banner".translate(Program: _Program)
      end

    image_tag(asset_url, alt: alt_text, class: options[:class], size: options[:size])
  end

  def italic_quot(content)
    content_tag(:i, get_safe_string("&quot;") + content + get_safe_string("&quot;"))
  end

  def wrap_and_break(content)
    return "" if content.blank? # word_wrap does not handle empty strings.
    word_wrap(h(content)).gsub(/\n/, '<br/>'.html_safe).html_safe
  end

  def definition_container(definition_term, definition_data)
    content_tag(:dt, definition_term, :title => definition_term) + content_tag(:dd, definition_data)
  end

  def profile_field_container(definition_term, definition_data, options = {})
    content_tag(:h4, definition_term, :class => options[:class], :id => options[:heading_id]) + content_tag(:div, definition_data, :class => options[:answer_class])
  end

  def profile_field_container_wrapper(definition_term, definition_data, options = {})
    content_tag(:div, profile_field_container(definition_term, definition_data, options), { class: "p-b-xs" }.merge(options[:wrapper_options] || {}))
  end

  # Simple captcha can be model or controller based
  # If model based, object should have an attribute called captcha
  def display_captcha(obj = nil, options = {})
    options.reverse_merge!( { label: "captcha.help_text".translate } )
    options.merge!(object: obj.class.name.underscore) if obj.present?
    captcha = show_simple_captcha(options)
    return captcha unless obj.present? && obj.errors[:captcha].present?
    content_tag(:div, captcha, :class => "has-error")
  end

  # Similar to pluralize, but returns only the text part, skipping the count
  #   pluralize_only_text(2, 'bag', 'bags') => 'bags'
  #   pluralize_only_text(1, 'fan', 'fans') => 'fan'
  def pluralize_only_text(count, singular, plural)
    count == 1 ? singular : plural
  end

  #Returns the truncated program name with 'style_class' applied to it and a link to the program home page
  def program_listing(program, style_class = nil)
    prog_name = truncate(program.name, :length => 15)
    link_to(
      prog_name,
      program_root_path(:root => program.root),
      :class => style_class,
      :title => program.name
      )
  end

  def get_active_member_programs(member, organization)
    all_programs = ProgramsListingService.get_applicable_programs(organization)
    member_programs = member.active_programs
    return all_programs & member_programs
  end

  # Returns the time string in words
  #
  #   formatted_time_in_words(t)                    => August 26, 2008 at 3:30 A.M.
  #   formatted_time_in_words(t1)                   => 2 hours ago
  #   formatted_time_in_words(t1, :no_ago => true)  => on July 26, 2008 at 3:30 A.M.
  #   formatted_time_in_words(t1, :no_time => true) => July 26, 2008
  #   formatted_time_in_words(t1, :no_date => true) => July, 2008
  #
  # ==== Params
  # * <tt>absolute</tt>: return words representing absolute time, without using
  #   any of 'ago', 'on' or 'at'
  # * <tt>no_time</tt>: skip '...at time' at the end
  #
  def formatted_time_in_words(given_time, options = {})
    return "" if given_time.nil?
    given_time = given_time.to_datetime

    # If the time is within last 24 hours, show as "...ago" string.
    if given_time.to_datetime >= 1.day.ago && given_time.to_datetime < Time.now && !options[:no_ago]
      return 'display_string.time_ago'.translate(time: time_ago_in_words(given_time))
    else
      if options[:no_date] && options[:no_time]
        date = DateTime.localize(given_time, format: :full_month_year)
      elsif options[:no_time]
        date = DateTime.localize(given_time, format: :full_display_no_time)
      elsif options[:no_date]
        date = DateTime.localize(given_time, format: :full_display_no_date)
      elsif options[:short_date]
        date = DateTime.localize(given_time, format: :abbr_short)
      elsif options[:short_time]
        date = DateTime.localize(given_time, format: :short_time)
      elsif options[:full_display_no_day_short_month]
        date = DateTime.localize(given_time, format: :full_display_no_day_short_month)
      elsif options[:time_or_date]
        if given_time.to_date == Date.today
          date = DateTime.localize(given_time, format: :short_time)
        else
          date = DateTime.localize(given_time, format: :abbr_short)
        end
      else
        date = DateTime.localize(given_time, format: :full_display_no_day)
      end
    end
    return options[:on_str] ? 'display_string.on_date'.translate(date: date) : date
  end

  # We currently support only upto 4 steps as we have only 4 images
  def simple_wizard(captions, selected_step=1)
    content = "".html_safe
    captions.each_with_index do |caption, index|
      step = index + 1
      content << content_tag(:li, :class => "#{step==selected_step ? 'well square-well pull-left bg-dark attach-bottom' : 'well square-well no-border pull-left attach-bottom'} ") do
        content_tag(:i, image_tag("num/#{step}_green.gif", :height => "25px", :width => "25px"), :class => "has-next") +
          content_tag(:span, captions[index], :class => "strong")
      end
    end
    content_tag(:ul, content, :class => "unstyled no-margin clearfix ")
  end

  def add_program_wizard(step)
    tab_captions = [
      "program_settings_strings.label.program_details".translate,
      "program_settings_strings.label.create_administrator_account".translate,
      "program_settings_strings.label.complete_registration".translate
    ]
    simple_wizard(tab_captions, step)
  end

  # Displays formatted string representation of the given date object.
  # TODO: Date#in_time does not respect the timezone. Can remove in_time_zone on in_time after Ruby 2.4 upgrade (https://github.com/rails/rails/issues/25428)
  def formatted_date_in_words(date_obj, options = {})
    return "" if date_obj.nil?
    formatted_time_in_words(date_obj.in_time_zone, options.merge(no_time: true, no_ago: true))
  end

  # Renders a in page flash container for showing page action errors.
  def response_flash(flash_id, options = {})
    case options[:class]
    when "alert-danger"
      options[:class] = "error"
    when "alert-success"
      options[:class] = "success"
    when "alert-warning"
      options[:class] = "warning"
    end

    render(:partial => "common/response_flash", :locals => {:flash_id => flash_id, :options => options})
  end

  #Renders a error flash with a default message
  #To be used along with simple form's inline flash
  def display_error_flash(klass_object, message = content_tag(:h3, "common_text.error_msg.please_correct_highlighted_errors".translate))
    options = {
                :class => "error",
                :message => message
              }
    render(:partial => "common/response_flash", :locals => {:options => options}) if klass_object.errors.present?
  end

  # Renders the flash message with appropriate styles, depending on whether it
  # is a notice message or an error. It is assumed that the notice and error
  # messages are mutually exclusive and only one of them will be set/displayed
  # in any page.
  #
  # If there's a sublayout, renders the flash properly aligned with the
  # innercontent within the sublayout.
  #
  # ==== Params:
  # sublayout ::  if any. Right now, only pages controller has a sublayout.
  #
  def show_flash(sublayout = nil)
    flash_class, message =
      if flash[:notice]
        ["success", flash[:notice]]
      elsif flash[:error]
        ["error", flash[:error]]
      elsif flash[:warning]
        ["warning", flash[:warning]]
      elsif flash[:info]
        ["info", flash[:info]]
      end

    render partial: "common/response_flash", locals: { options: { class: flash_class, message: message } }
  end

  def side_section(header_text, options={}, &block)

    unless options[:if].nil?
      return if options[:if] == false
    end

    show_see_all = (!(options[:total_entries] && options[:max_entries]) ||
        (options[:total_entries] > options[:max_entries])) && options[:see_all]

    see_all_position = options[:see_all_position] || :bottom

    header_text_to_use = "".html_safe
    header_text_to_use << options[:see_all] if show_see_all && see_all_position == :top
    header_text_to_use << (header_text.blank? ? "" : header_text)
    header_text_to_use = content_tag(:h3, header_text_to_use , :class=>"has-below-1")
    pane_content = "".html_safe
    pane_content << content_tag(:div, header_text_to_use) unless header_text_to_use.empty?
    pane_content << content_tag(:div, capture(&block))

    if (show_see_all && see_all_position == :bottom) || options[:pane_action]
      pane_content += content_tag(:div) do
        footer_content = "".html_safe

        # See all link
        if show_see_all
          footer_content += content_tag(:div, options[:see_all], :class => 'pane_see_all')
        end

        # Action link
        if options[:pane_action]
          footer_content += content_tag(:div, options[:pane_action], :class => 'pane_action')
        end
        content_tag(:div, footer_content, :class => 'clearfix')
      end
    end

    pane_content = content_tag(:div, pane_content, :class => "#{options[:pane_class].to_s}")
    if options[:bottom_border]
      pane_content << content_tag(:hr,nil, :class => "in-sidecol")
    end
    concat pane_content
  end

  # Pane with given content
  def pane(header_text, options = {}, &block)
    # If there's a params[:if] and if its false dont render the pane
    unless options[:if].nil?
      return if options[:if] == false
    end

    # Show see all link if either entries count is not given, or the current
    # count is lesser than the maximum entries.
    #
    show_see_all = (!(options[:total_entries] && options[:max_entries]) ||
        (options[:total_entries] > options[:max_entries])) && options[:see_all]

    see_all_position = options[:see_all_position] || :bottom
    # Add see all text to the header if the position is :top
    header_text_to_use = "".html_safe
    header_text_to_use << options[:see_all] if show_see_all && see_all_position == :top
    header_text_to_use << (header_text.blank? ? "" : header_text)
    header_text_to_use = content_tag(:h3, header_text_to_use)

    pane_content = "".html_safe
    pane_content << content_tag(:div, header_text_to_use, :class => 'pane-header') unless header_text_to_use.empty?
    pane_content << content_tag(:div, capture(&block), :class => "pane-body")

    if (show_see_all && see_all_position == :bottom) || options[:pane_action]
      pane_content += content_tag(:div, :class => 'pane_footer') do
        footer_content = "".html_safe

        # See all link
        if show_see_all
          footer_content += content_tag(:div, options[:see_all], :class => 'pane_see_all')
        end

        # Action link
        if options[:pane_action]
          footer_content += content_tag(:div, options[:pane_action], :class => 'pane_action')
        end
        content_tag(:div, footer_content, :class => 'clearfix')
      end
    end

    pane_content = content_tag(:div, pane_content, :class => "pane #{options[:pane_class].to_s}")
    concat pane_content
  end

  def ibox(header_title=nil, options={}, &block)
    render(:partial => "common/ibox", :locals => {:options => options, :header_title => header_title, :content_block => capture(&block)})
  end

  def panel(header_title, options = {}, &block)
    render partial: "common/panel", locals: { options: options, header_title: header_title, content_block: capture(&block) }
  end

  # Renders a popup with the content given in the block
  #
  # ==== Params
  # * <tt>title</tt>: the title of the popup
  # * <tt>action_item_id</tt>: id of the element that triggers the popup.
  #
  def popup(title, action_item_id, options = {}, &block)
    # id to use for the popup
    popup_id = 'popup_' + action_item_id

    render_init = options[:render_init].present? ? options[:render_init] : ''
    width = options[:width].present? ? options[:width] : 'auto'
    position = (options[:position] ? options[:position].to_sym : nil )
    below_align = (options[:below_align] ? options[:below_align].to_sym : nil )
    # options convert
    modal = !!options[:modal]
    if (modal || position == :center)
      at = my = 'center'
      target = 'jQuery(window)'
    else
      target = "jQuery('##{action_item_id}')"
      # fix position
      if position == :above
        at = 'top '
        my = 'bottom '
      else
        at = 'bottom '
        my = 'top '
      end

      # fix alignment
      if below_align == :right
        at += 'right'
        my += 'right'
      else
        at += 'left'
        my += 'left'
      end
    end

    partial_to_render = options[:with_image] ? 'common/popup_with_image' : 'common/popup'
    concat render(
      :partial => partial_to_render,
      :locals => {
        :popup_title => title,
        :popup_id => popup_id,
        :action_item_id => action_item_id,
        :block => block,
        :modal => modal,
        :at => at,
        :my => my,
        :target => target,
        :render_init => render_init,
        :width => width,
        :klass => options[:klass]
      })
  end


  def modal_v3_popup(title, options={}, &block)
    @no_js = true
    concat modal_v3_popup_content(title, options, &block)
  end

  def modal_v3_popup_content(title, options={}, &block)
    render(:partial => 'common/modal_popup', :locals => {:popup_title => title, :binding => block, :options => (options || {})})
  end
  # Renders a Qtip popup with the content given in the block
  # This should be used only with the jQueryShowQtip and not for general popups
  #
  # ==== Params
  # * <tt>title</tt>: the title of the popup
  #
  def qtip_popup(title, options={}, &block)
    if options[:modern_qtip]
      concat render(:partial => 'common/qtip_popup_modern', :locals => {:popup_title => title, :binding => block, width: options[:width], container_class: options[:container_class]})
    elsif options[:with_image]
      concat render(:partial => 'common/qtip_popup_with_image', :locals => {:popup_title => title, :binding => block})
    elsif options[:non_header]
      concat render(:partial => 'common/qtip_popup_non_header', :locals => {:binding => block})
    else
      concat render(:partial => 'common/qtip_popup', :locals => {:popup_title => title, :binding => block})
    end
  end

  def modal_popup(title, options ={}, &block)
    options[:class] = options[:class] || ""
    options[:class] += " modal_popup clearfix"
    options[:title] = title
    concat content_tag(:div, capture(&block), options)
  end

  def modal_container(header_title, options={}, &block)
    # modal_id is mandatory
    if options[:modal_id].present?
      concat render(:partial => "common/modal_container", :locals => {:header_title => header_title, :content_block => capture(&block), :options => options})
    end
  end

  def render_button_group(common_actions, options = {})
    render(partial: "common/button_group", locals: {common_actions: common_actions, options: options}, :formats => FORMAT::HTML)
  end

  # Action container with dummy label for left aligning with rest of the form
  def action_set(options = {}, &block)
    action_code = capture(&block)

    action_code = content_tag(:div, action_code.html_safe, :class => options[:class].to_s + ' form-actions')

    concat(action_code)
  end

  # Renders cancel link defaulting to referrer. If use_default is true, link to
  # that unconditionally.
  def cancel_link(url_or_function = nil, options = {})
    message_text = options[:caption] || 'display_string.Cancel'.translate
    if options[:qtip]
      link_to_function(message_text, url_or_function || "closeQtip();", :class => "btn cancel btn-white #{options[:additional_class]}")
    else
      url_or_function = back_url(url_or_function || program_root_path) unless options[:use_default]
      link_to(message_text, url_or_function, :class => "cancel btn btn-white #{options[:additional_class]}")
    end
  end

  def email_notification_consequences_for_multiple_mailers_html(mailers, options = {})
    program = options[:program] || current_program
    role_name_to_display_name_hsh = RoleConstants.program_roles_mapping(program, roles: program.roles, no_capitalize: true, pluralize: (options[:pluralize].nil? ? true : options[:pluralize]))
    select_disabled = ->(mailers, invert) { mailers.select { |mailer|  mailer.get_for_role_names_ary(program).map { |role_name| role_name_to_display_name_hsh[role_name].present? }.inject(false, :|) && program.email_template_disabled_for_activity?(mailer) == invert } }
    roles_list_compiler = ->(mailers) { to_sentence_sanitize(mailers.map { |mailer| mailer.get_for_role_names_ary(program).map { |role_name| link_to(role_name_to_display_name_hsh[role_name], edit_mailer_template_path(mailer.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), target: :_blank) if role_name_to_display_name_hsh[role_name] } }.flatten.compact) }
    disabled_mailers, enabled_mailers = [select_disabled[mailers, true], select_disabled[mailers, false]]
    users_str = "display_string.#{options[:selected_users] ? 'selected_users' : 'users'}".translate
    translation_key = disabled_mailers.empty? ? "all_mailer_roles_enabled_html" : enabled_mailers.empty? ? "all_mailer_roles_disabled_html" : "mailer_roles_enabled_and_disabled_html"
    "feature.email.content.#{translation_key}".translate(enabled_roles_list: roles_list_compiler[enabled_mailers], disabled_roles_list: roles_list_compiler[disabled_mailers], users: users_str)
  end

  def email_notification_consequences_on_action_html(mail_klass, options = {})
    options.reverse_merge!(div_enclose: true, div_class: "", with_count: false, count: 0, common_text: false, translation_extras: {}, return_email_link_only: false)
    options[:organization_or_program] ||= current_program
    email_link = link_to(options[:email_link_text] || "display_string.email".translate, edit_mailer_template_path(mail_klass.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), target: :_blank)
    return email_link if options[:return_email_link_only]
    email_status_str = options[:common_text] ? "enabled_or_disabled_common_text" : options[:organization_or_program].email_template_disabled_for_activity?(mail_klass) ? "disabled" : "enabled"
    translation_interpolations = {email: email_link}.merge!(options[:translation_extras])
    translation_interpolations.merge!(count: options[:count]) if options[:with_count]
    main_translation_key = "email_translations.#{mail_klass.name.underscore}"
    secondary_translation_key = "#{email_status_str}#{"_with_count" if options[:with_count]}_html"
    main_translation_key = "feature.email.content" unless I18n.t(main_translation_key).keys.include?(secondary_translation_key.to_sym)
    ret = "#{main_translation_key}.#{secondary_translation_key}".translate(translation_interpolations)
    ret = content_tag(:div, ret, class: options[:div_class]) if options[:div_enclose]
    ret
  end

  #
  # Action container with dummy label for left aligning with rest of the form
  # If an :assocations arg is passed, compresses all association errors into
  # one error.
  #
  def formatted_form_error(f, options = {}, &block)
    # There can be error only if there's an object and its faulty
    return unless f.object

    if objects = options.delete(:objects)
      objects.each do |object|
        object.errors.full_messages.each do |error|
          f.object.errors.add(:base, error)
        end
      end
    end

    if f.object.errors.empty?
      return nil
    end

    if (assocs = options.delete(:associations))
      assocs.each do |assoc|
        errors_on_assoc = f.object.errors[assoc]
        if errors_on_assoc  &&              # If the assoc has errors
          errors_on_assoc.is_a?(Array) &&   #   and if its an array
          errors_on_assoc.size > 1          #   of size > 1,
          f.object.errors[assoc].clear   # collapse errors into one error message
          f.object.errors[:base] << "common_text.error_msg.association_invalid".translate(:association => assoc.to_s.downcase.humanize)
        end
      end
    end

    content = "".html_safe
    content += f.error_messages(options)
    if content.present?
      response_flash("flash_container", { message: content, class: "error" } )
    end
  end

  #
  # Returns whether the +viewer+ can contact the +profile_user_or_member+,
  # ignoring the connectedness check.
  #
  def show_link?(profile_user_or_member, viewer = (current_user_or_member))
    # Show if the profile user is active.
    return true if profile_user_or_member.active?

    # If suspended, allow only admin to view.
    viewer && (viewer.is_a?(User) ? viewer.is_admin? : viewer.admin?)
  end

  #
  # Returns whether the +viewer+ should be shown send message link when viewing
  # the +profile_user_or_member+'s profile.
  #
  def show_send_message_link?(profile_user_or_member, viewer = (current_user_or_member))
    viewer && show_link?(profile_user_or_member, viewer) && viewer.allowed_to_send_message?(profile_user_or_member)
  end

  def get_send_message_link(profile_user_or_member, viewer = (current_user_or_member), options = {})
    listing_page = options.delete(:listing_page)
    if profile_user_or_member.is_a?(User) && viewer.is_a?(User)
      group = viewer.common_groups(profile_user_or_member, :active).find(&:scraps_enabled?)
    end

    if group && !viewer.is_admin? && !viewer.program.allow_user_to_send_message_outside_mentoring_area?
      link_to_scraps_listing = group_scraps_path(group, new_scrap: true)
      listing_page ? { url: link_to_scraps_listing } : link_to_scraps_listing
    else
      listing_page ? { js: (%Q[jQueryShowQtip('#inner_content', 600, '#{new_message_path(options)}','',{modal: true})]).html_safe } : new_message_path(options)
    end
  end

  # Renders the given user's picture by delegating to +member_picture+
  def user_picture(user, options = {}, image_options = {})

    # If application context, check visibility of the user to
    if !options[:mail_view] && !options[:bulk_match_view] && (options[:user_name]=="display_string.Anonymous".translate || (current_user && !user.visible_to?(current_user)))
      options.merge!(:anonymous_view => true)
    end

    member_picture_v3(user.member, options, image_options)
  end

  # Renders the given members's picture if present, or default picture otherwise.
  # Size kyes needs to be set in options hash, to generate image with initials where images are not available.
  def member_picture(member, options = {}, image_options = {})
    raise "display_string.invalid_member".translate unless member.is_a?(Member)

    # When rendering user picture for a group, linking to group page instead of
    # profile.
    item_link = options[:item_link]
    item_link ||= options[:group] ? group_path(options[:group]) : member_path(member)
    member_name = options[:member_name] || member.name
    # Default to large picture.
    size_sym = options[:size] || :large
    photo_div_id = options[:id] || ""
    outer_class = options[:outer_class] || ""
    profile_picture = member.profile_picture

    image_content = if options[:anonymous_view]
      image_tag(
        UserConstants::DEFAULT_PICTURE[size_sym],
        {:title => "feature.profile.content.picture_viewing_prohibited".translate}.merge(image_options)
      ).html_safe
    else
      box_content = if profile_picture.present? && !profile_picture.not_applicable?
        image_tag(member.picture_url(size_sym),{ alt: "display_string.member_profile_picture".translate(member_name: member_name), title: member_name, id: "#{photo_div_id}"}.merge(image_options))
      else
        initials_size = options[:new_size] || size_sym
        generate_block_with_initials(member, initials_size, image_options, photo_div_id)
      end
      box_content = link_to(box_content, item_link, class: "#{'no-text-decoration' if profile_picture.blank? || (profile_picture.present? && profile_picture.not_applicable?)}") unless options[:dont_link]
      box_content += content_tag(:div, link_to(h(member_name), item_link), :class => 'member_name') unless options[:no_name]
      box_content += content_tag(:span, member_name, :class => "member_name #{options[:style_name_without_link]}") if options[:style_name_without_link].present?
      box_content
    end

    options[:skip_outer_class] ? image_content : content_tag(:div, image_content, class: "member_box #{size_sym} #{outer_class}")
  end

  def member_picture_v3(member, options={}, image_options={})
    raise "display_string.invalid_member".translate unless member.is_a?(Member)

    # When rendering user picture for a group, linking to group page instead of
    # profile.
    item_link = options[:item_link]
    item_link ||= options[:group] ? group_path(options[:group]) : options[:src] ? member_path(member, src: options[:src]) : member_path(member)
    member_name = options[:member_name] || member.name
    # Default to large picture.
    size_sym = options[:size] || :large
    photo_div_id = options[:id] || ""
    outer_class = options[:outer_class] || ""
    profile_picture = member.profile_picture

    image_options[:class] = "table-bordered thick-border img-circle #{image_options[:class]} #{'m-b-n-xl inline' if image_options[:place_image_in_middle]}"
    if options[:anonymous_view]
      image_content = image_tag(
        UserConstants::DEFAULT_PICTURE[size_sym],
        {:title => "feature.profile.content.picture_viewing_prohibited".translate}.merge(image_options)
      ).html_safe
    else
      image_alt_text = "display_string.member_profile_picture".translate(member_name: member_name)
      default_image_content = image_tag(UserConstants::DEFAULT_PICTURE[size_sym], {alt: image_alt_text, title: member_name}.merge(image_options))
      image_content = if options[:force_default_picture]
        default_image_content
      elsif profile_picture.present? && !profile_picture.not_applicable?
        if image_options[:place_image_in_middle]
          content_tag(:div, class: "clearfix") do
            image_tag(member.picture_url(size_sym),{:alt => image_alt_text, :title => member_name, :id => "#{photo_div_id}"}.merge(image_options))
          end
        else
          image_tag(member.picture_url(size_sym),{:alt => image_alt_text, :title => member_name, :id => "#{photo_div_id}"}.merge(image_options))
        end
      elsif options[:use_default_picture_if_absent]
        default_image_content
      else
        initials_size = options[:new_size] || size_sym
        generate_block_with_initials(member, initials_size, image_options, photo_div_id)
      end
      image_content = link_to(image_content, item_link) unless options[:dont_link]

      image_content += options[:additional_image_content] if options[:additional_image_content]
      text_content = "".html_safe
      text_content += content_tag(:div, link_to(h(member_name), item_link), :class => 'member_name') unless options[:no_name]
      text_content += content_tag(:span, member_name, :class => "member_name #{options[:style_name_without_link]}") if options[:style_name_without_link].present?
    end

    member_picture_options = {:image_content => image_content, :text_content => text_content}
    member_picture_options.merge!({:outer_class => " #{size_sym} #{outer_class} "}) unless options[:skip_outer_class]
    member_picture_options.merge!({:media_class => "media-middle"}) if (options[:no_name] && !options[:member_name])
    member_picture_options.merge!({:row_fluid => true}) if options[:row_fluid]
    member_picture_options.merge!({:no_padding_for_media_body => true}) if options[:no_padding_for_media_body]

    content = render(:partial => "common/member_picture", :locals => member_picture_options, :formats => FORMAT::HTML)
  end

  def generate_block_with_initials(member, size_sym, image_options = {}, photo_div_id = "")
    size_sym = :small if image_options[:meeting_area].present?
    member_id = member.id % 10
    image_initials = UnicodeUtils.upcase(member.first_name.try(:first).to_s + member.last_name.first)
    image_params = {:id => "#{photo_div_id}", :class => "image_with_initial inline image_with_initial_dimensions_#{size_sym} profile-picture-#{IMAGE_INITIALS[member_id]} profile-font-styles #{image_options[:class]}", :title => member.name}
    image_params[:style] = image_options[:style] if image_options[:style]
    content_tag(:div, image_initials, image_params)
  end

  def non_existing_user_picture(options = {})
    content_tag(:div) do
      size_sym = options[:size] || :medium
      img_class = options[:class] || "photo img-circle"
      image = image_tag(UserConstants::DEFAULT_PICTURE[size_sym], class: img_class)
    end
  end

  def include_common_sort_by_id_fields(options = {})
    suffix_id = options[:suffix_id].present? ? "_#{options[:suffix_id]}" : ""
    hidden_field_tag(:sort_field, options[:sort_field], class: 'cjs-sort-field', id: "sort_field#{suffix_id}") +
    hidden_field_tag(:sort_order, options[:sort_order], class: 'cjs-sort-order', id: "sort_order#{suffix_id}")
  end

  def include_sort_info_for_basic_sort_by_id_options_for_top_bar(options = {})
    sort_fields = [
      { field: CommonSortUtils::ID_SORT_FIELD, order: CommonSortUtils::SORT_DESC, label: "display_string.Sort_by_most_recent".translate, mobile_label: "display_string.Most_recent".translate },
      { field: CommonSortUtils::ID_SORT_FIELD, order: CommonSortUtils::SORT_ASC,  label: "display_string.Sort_by_oldest".translate     , mobile_label: "display_string.Oldest".translate      }
    ]
    { sort_info: sort_fields }.merge!(options)
  end

  def basic_sort_by_id_options_for_top_bar(collection_present, options = {})
    return {} unless collection_present
    include_sort_info_for_basic_sort_by_id_options_for_top_bar(on_select_function: (options[:on_select_function] || "updateSortCommon"), sort_field: options[:sort_field], sort_order: options[:sort_order])
  end

  # Top bar includes:
  # 1. Listing Info ( e.g. Showing 10 Mentors )
  # 2. Filter Icon in Mobile Layout
  # 3. Sorting Option

  # Check updateCurPageInfo for updating the current-page info using javascript
  def top_bar_in_listing(listing_info_options = {}, filter_options = {}, sort_by_options = {}, options = {})
    left_content = ""
    right_content = ""
    show_in_web = options[:left_most_content].present? || options[:right_most_content].present?

    collection = listing_info_options.delete(:collection)
    if collection.present?
      show_in_web = true
      default_listing_info_options = {
        short_display: true,
        entries_name: content_tag(:span, 'display_string.Showing'.translate, class: hidden_on_mobile)
      }
      listing_info_options = default_listing_info_options.merge(listing_info_options)
      left_content += content_tag(:div, page_entries_info(collection, listing_info_options), class: "cur_page_info m-t-sm m-b-xs pull-left")
    end

    if filter_options[:show]
      applied_filters_count = (filter_options[:applied_count].present? && !filter_options[:applied_count].zero?) ? filter_options[:applied_count] : nil
      label = set_screen_reader_only_content("display_string.Filters".translate)
      label += "(#{applied_filters_count})" if applied_filters_count.present?
      right_content += content_tag(:div, class: "#{hidden_on_web} #{filter_options[:filter_class]} pull-right") do
        link_to(append_text_to_icon("fa fa-filter fa-lg no-margins text-info", label), "javascript:void(0)", class: "font-bold btn btn-white", id: "#{'cjs_user_filter' if filter_options[:user_filter]}",
          data: { toggle: "offcanvasright" } )
      end
    end

    if sort_by_options.present?
      show_in_web = true
      sort_url = sort_by_options.delete(:sort_url)
      sort_field = sort_by_options.delete(:sort_field)
      sort_order = sort_by_options.delete(:sort_order)
      sort_info = sort_by_options.delete(:sort_info)

      sort_select_web, sort_select_mobile, sort_form = sort_options_v3(sort_url, sort_field, sort_order, sort_info, sort_by_options)
      right_content += content_tag(:div, sort_select_web, class: "#{hidden_on_mobile} pull-right")
      right_content += content_tag(:div, class: "#{hidden_on_web} pull-right") do
        concat link_to(embed_icon("fa fa-sort-amount-asc fa-lg no-margins text-info", set_screen_reader_only_content("display_string.Sort".translate)), "#", class: "font-bold btn btn-white",
          data: { toggle: "modal", target: "#sort_by_modal" } )
      end

      modal_options = {
        modal_id: "sort_by_modal",
        modal_class: "cui-non-full-page-modal",
        modal_body_class: "no-padding"
      }
      right_content += capture do
        modal_container(append_text_to_icon("fa fa-sort", "display_string.Sort_by".translate), modal_options) do
          sort_select_mobile
        end
      end
      right_content += sort_form
    end

    content = (options[:left_most_content] || "").html_safe + left_content.html_safe + (options[:right_most_content] || "").html_safe + right_content.html_safe
    if content.present?
      content_tag(:div, class: "listing_top_bar clearfix p-sm b-b #{options[:additional_class]} #{hidden_on_web if !show_in_web}") do
        content.html_safe
      end
    else
      "".html_safe
    end
  end

  # Bottom bar includes:
  # 1. Pagination : 3 pages in mobile and 5 pages in web
  # 2. Number of entries per page ( e.g. Show 10, 20,... Mentors )
  def bottom_bar_in_listing(pagination_options = {}, per_page_options = {}, options={})
    content = ""

    collection = pagination_options.delete(:collection)
    if collection.present?
      if collection.total_pages > 1
        default_pagination_options = {
          renderer: ChronusPagination::LinkRenderer,
          previous_label: content_tag(:span, content_tag(:i, "", class: "fa fa-angle-left") + set_screen_reader_only_content("display_string.previous".translate), class: "small"),
          next_label: content_tag(:span, content_tag(:i, "", class: "fa fa-angle-right") + set_screen_reader_only_content("display_string.next".translate), class: "small"),
          short_display: true,
          class: "pagination no-margins #{'ajax_pagination' if pagination_options[:ajax]}"
        }
        default_web_pagination_options = default_pagination_options.merge( { inner_window: 2 } )
        default_mobile_pagination_options = default_pagination_options.merge( { inner_window: 1 } )
        content += content_tag(:div, class: "#{hidden_on_mobile if collection.total_pages > 3} pull-left") do
          will_paginate(collection, default_web_pagination_options.merge(pagination_options)).html_safe
        end
        if collection.total_pages > 3
          content += content_tag(:div, class: "small #{hidden_on_web} pull-left") do
            will_paginate(collection, default_mobile_pagination_options.merge(pagination_options)).html_safe
          end
        end
      end
    end

    if per_page_options.present? && collection.present? && collection.total_entries > (per_page_options[:per_page_option] || UserConstants::PER_PAGE_OPTIONS).min
      page_url = per_page_options.delete(:page_url)
      current_number = per_page_options.delete(:current_number)
      content += content_tag(:div, class: "pull-right") do
        per_page_selector_v3(page_url, current_number, per_page_options)
      end
      content += content_tag(:div, "display_string.Show".translate, class: "#{hidden_on_mobile} pull-right p-t-xxs m-r-xs")
    end

    if content.present?
      content_tag(:div, class: "listing_bottom_bar clearfix p-sm b-t #{options[:additional_class]}") do
        content.html_safe
      end
    else
      "".html_safe
    end
  end

  # Renders pagination links for the given collection
  def pagination_bar(collection, options = {})
    return if collection.empty? && !options[:empty_collection]
    content = "".html_safe

    unless options.delete(:no_side_entry_name).present?
      additional_class = options.delete(:additional_class) || ''
      content =  content_tag(:div,
        page_entries_info(collection, {:entries_name => options.delete(:entries_name), :short_display => true}.merge(options)).html_safe,
          :class => "col-sm-4 cur_page_info p-sm #{additional_class}")
    end

    content += options.delete(:additional_text) if options[:additional_text]

    # Render page links unless asked not to.
    unless options[:no_page_links]
      content += will_paginate(
        collection, {:inner_window => 1, :outer_window => 1}.merge(options)) || ''
    end

    return content
  end

  def render_bottom_pagination(collection, options = {})
    render_for_single_page = options.delete(:render_for_single_page)
    return if collection.total_pages <= 1 && !render_for_single_page
    per_page_content = options.delete(:per_page_content) || ""
    paginator_content = if(1 == collection.total_pages)
      '&nbsp;'.html_safe
    else
      paginate_options = {
        inner_window: 1,
        outer_window: 1,
        previous_label: "will_paginate.bottom_pagination_bar.previous_label".translate,
        next_label: "will_paginate.bottom_pagination_bar.next_label".translate
      }
      will_paginate(collection, paginate_options.merge(options))
    end
    content_tag(:div, (per_page_content + paginator_content).html_safe, class: "pagination_box text-xs-center bottom_pagination")
  end

  # Creates the number of items to be displayed per page. The parameters are:
  #
  # * <tt> page_url</tt> The url of the page, the options can contain other URL params
  # * <tt> cur_number</tt> The number of items being displayed currently. (For onchange JS function)
  # * <tt> users</tt> The object containing the number of items.
  # * <tt> page_nos</tt> The options for the number of items.
  # * <tt> options</tt> Can contain additional parameters like :entry_name, :url_params

  def per_page_selector_v3(page_url, cur_number, options = {})
    page_nos = options[:per_page_option] || UserConstants::PER_PAGE_OPTIONS

    page_info = page_nos.map do |text|
      { :number => "#{text}", :label => "#{text}" }
    end

    use_ajax = options.delete(:use_ajax)
    items_per_page_id = "items_per_page_selector"
    function_name = use_ajax ? (options.delete(:ajax_function) || 'submitPerPageSelectorFormAjax') : 'submitPerPageSelectorForm'
    content_tag(:div, :class => 'items_per_page') do
      select_field =
        label_tag(:select, "common_text.pagination.items_per_page_label".translate, :for => items_per_page_id, class: "sr-only") +
        content_tag(:select, id: items_per_page_id, onchange: "#{function_name}(this.value)", class: "form-control input-sm") do
          page_info.map do |_info|
            opts = {}
            opts[:selected] = "selected" if cur_number.to_s == _info[:number].to_s
            opts[:value] = "#{_info[:number].to_i}"
            content_tag(:option, _info[:label], opts)
          end.join.html_safe
        end

      paging_form = ''
      unless use_ajax
        paging_form = content_tag(:form, action: page_url, method: :get, id: 'change_items_form', class: 'hide') do
          concat hidden_field_tag(:items_per_page, "", id: 'change_items_field')
          concat (options[:url_params] || {}).map { |key, value| hidden_field_tag(key, value) }.join.html_safe
        end
      end
      select_field + paging_form
    end
  end

  # Renders select options with required logic for sorting
  #
  # NOTE: This helper renders sorting options code only for non-AJAX sorting.
  #
  # ==== Params
  # * <tt>page_url</tt> - url to load with options on change of sorting choice
  # * <tt>cur_field</tt> - field on which current sorting is done
  # * <tt>cur_order</tt> - whether the current sorting is ascending or
  #   descending
  # * <tt>sort_info</tt> - array containing an entry for each sort choice with
  #   the following keys.
  #   * label - the label to show, say, 'Date'
  #   * field - the field to sort by
  #   * order - asc or desc sorting
  #
  def sort_options_v3(page_url, current_field, current_order, sort_info, options = {})
    submit_function = options.delete(:on_select_function) || (options.delete(:use_ajax) ? 'submitSortFormAjax' : 'submitSortForm')
    is_groups_page = options[:is_groups_page] ? 'true' : 'false'

    sort_select_web = label_tag(:sort_by, "display_string.Sort_by".translate, for: "sort_by", class: "sr-only") +
      content_tag(:select, id: 'sort_by', class: "form-control input-sm", onchange: "#{submit_function}(this.value, #{is_groups_page})") do
      options_content = "".html_safe
      sort_info.each do |_info|
        opts = {}
        opts[:selected] = "selected" if current_field.to_s == _info[:field].to_s && ( current_order.to_s == _info[:order].to_s || current_field == UserSearch::SortParam::RELEVANCE )
        opts[:value] = "#{_info[:field]},#{_info[:order]}"
        options_content << content_tag(:option, _info[:label], opts)
      end
      options_content
    end

    sort_select_mobile = content_tag(:div, class: "list-group no-margins") do
      content = ""
      sort_info.each do |sort_option|
        value = "#{sort_option[:field]},#{sort_option[:order]}"
        is_current_field = (current_field.to_s == sort_option[:field].to_s) && (current_order.to_s == sort_option[:order].to_s || current_field == UserSearch::SortParam::RELEVANCE)
        content += link_to_wrapper(true, js: "jQuery('#sort_by_modal').modal('hide'); #{submit_function}('#{value}', #{is_groups_page})", class: "list-group-item #{'gray-bg font-bold' if is_current_field}") do
          concat (sort_option[:mobile_label].presence || sort_option[:label])
          concat highlight_selected_item_in_list_group if is_current_field
        end
      end
      content.html_safe
    end

    sort_form = content_tag(:form, :action => page_url, :method => :get, :id => 'sort_form', class: "hide") do
      fields_content = hidden_field_tag(:sort, nil, :id => 'sort_field')
      fields_content += hidden_field_tag(:order, nil, :id => 'sort_order')
      (options[:url_params] || {}).each do |key, value|
        fields_content += hidden_field_tag(key, value)
      end
      fields_content
    end

    [sort_select_web, sort_select_mobile, sort_form]
  end

  # Resposive UI - CLEAN - use sort_options_v3 instead
  def sort_options(page_url, cur_field, cur_order, sort_info, options = {})
    submit_function = options.delete(:use_ajax) ? 'submitSortFormAjax' : 'submitSortForm'
    is_groups_page = options[:is_groups_page] ? 'true' : 'false'
    sort_select = (content_tag(:select, id: 'sort_by', class: "form-control input-sm", onchange: "#{submit_function}(this.value, #{is_groups_page})") do
        options_content = "".html_safe
        sort_info.each do |_info|
          opts = {}
          opts[:selected] = "selected" if cur_field.to_s == _info[:field].to_s && cur_order.to_s == _info[:order].to_s

          # Onclick of the option sets the current field, order and submits the
          # form
          opts[:value] = "#{_info[:field]},#{_info[:order]}"

          options_content << content_tag(:option, _info[:label], opts)
        end
        options_content
      end)

    sort_form = (content_tag(:form, :action => page_url, :method => :get,
        :id => 'sort_form', :style => 'display: none;') do
        fields_content = hidden_field_tag(:sort, nil, :id => 'sort_field')
        fields_content += hidden_field_tag(:order, nil, :id => 'sort_order')

        (options[:url_params] || {}).each do |key, value|
          fields_content += hidden_field_tag(key, value)
        end

        fields_content
      end)

    content_tag(:div, :class => 'pull-sm-right pull-xs-left sorting p-t-xs p-b-xs p-xxs') do
      sort_select + sort_form
    end
  end

  # Returns meeting time string for the given profile
  def meeting_time_string(profile)
    day_string = ""

    if profile.meeting_weekday && profile.meeting_weekend
      day_string = "feature.meetings.content.meeting_time.any_day".translate
    elsif profile.meeting_weekday
      day_string = "feature.meetings.content.meeting_time.weekdays".translate
    elsif profile.meeting_weekend
      day_string = "feature.meetings.content.meeting_time.weekends".translate
    end

    time_string = []
    time_string << "feature.meetings.content.meeting_time.morning".translate if profile.meeting_morning
    time_string << "feature.meetings.content.meeting_time.afternoon".translate if profile.meeting_afternoon
    time_string << "feature.meetings.content.meeting_time.evening".translate if profile.meeting_evening

    # No need to show all times of day
    time_string.clear if time_string.size == 3
    day_string += " : " unless day_string.empty? || time_string.empty?

    final_string = day_string + time_string.join(", ")
    final_string = "-" if final_string.empty?
    final_string
  end

  # Generates a pane with header with the given block as the content that can be
  # expanded or collpased by clicking on the header.
  #
  # A right or downward arrow in the header will indicates the current expansion
  # state of the pane.
  #
  # ==== Params
  # header_label   : the label to show on the pane header. The pane and content
  #                  DOM ids will be generated out of this label. If the label
  #                  is 'India Is Great', the header id will be
  #                  'india_is_great_header' and the content container id will
  #                  be 'india_is_great_content'
  # other_sections : an *Array* of other sections names (labels) that need to be
  #                  expanded or collapsed when this pane's state is changed.
  #                  Default => []
  #
  def collapsible_content(header_label, other_sections = [], collapsed = true, options = {}, &block)
    block_content = capture(&block)

    id_prefix = "collapsible_#{SecureRandom.hex(3)}"
    header_id = "#{id_prefix}_header"
    content_id = "#{id_prefix}_content"

    # Clicable section header
    wrapper_class = 'exp_collapse_header '

    header_class = (options[:additional_header_class] || '')
    header_class += options[:load] ? 'cjs_load_on_click' : ''

    pane_content = if options[:render_panel]
      panel_options = {
        panel_class: options[:class],
        panel_id: options[:panel_id],
        panel_heading_class: header_class,
        panel_heading_id: header_id,
        panel_body_wrapper_class: (collapsed ? 'collapse' : 'collapse in'),
        panel_body_wrapper_id: content_id,
        panel_body_class: options[:pane_content_class],
        panel_footer_class: options[:pane_footer_content_class],
        icon_class: options[:icon_class],
        collapsible: options[:collapsible].nil? ? true : options[:collapsible],
        additional_right_links: options[:additional_right_links],
        drop_down_icon: (collapsed ? "fa fa-chevron-down" : "fa fa-chevron-up")
      }
      panel header_label, panel_options do
        block_content
      end
    else
      ibox_options = {
        :ibox_class => "#{collapsed ? "collapsed" : ""} #{options[:class]}",
        :right_links_class => wrapper_class,
        :collapse_link_class => header_class,
        :ibox_header_id => header_id,
        :content_class => options[:pane_content_class],
        :ibox_content_id => content_id,
        :ibox_footer_class => options[:pane_footer_content_class],
        :icon_class => options[:icon_class],
        :no_truncate => options[:no_truncate],
        :header_content => options[:header_content],
        :hide_header_title => options[:hide_header_title]
      }
      ibox header_label, ibox_options do
        block_content
      end
    end

    concat(pane_content)
  end

  # Renders links that act as filters for listing pages, like 'From Students'
  # and 'From Mentors' in membership requests listing page.
  #
  # ==== Usage:
  #   filter_info = [
  #     {:value => "all", :label => "From Students"},
  #     {:value => "available", :label => "From Mentors"}
  #   ]
  #
  #   filter_links("Show ", base_url, current_filteer, filter_info}
  #
  # ==== Params:
  # * <tt>filter_name</tt> : the name to show before the filter. Pass "" if
  #   nothing should be shown before the links.
  # * <tt>cur_filter</tt> : Currently applied filter.
  # * <tt>filters_info</tt> : Array containing definition of the filters as
  #   given above.
  # * <tt>do_not_clear_both</tt> : Boolean that instructs the function not to
  #   use the clear both style.
  #
  def filter_links(filter_name, cur_filter, filters_info, do_clear_both = true, options = {})
    links = []
    common_class = "btn btn-white btn-sm"

    filters_info.each do |info|
      label = info[:label]
      label << " (#{info[:count]})" if info[:count]
      if cur_filter && (cur_filter.to_s == info[:value].to_s)
        links << link_to(label, "javascript:void(0)", class: "#{common_class} active")
      elsif info[:url]
        # Direct url specified
        links << link_to(label, info[:url], class: common_class)
      else
        # Change parameters alone in the current url.
        links << link_to(label, url_for(params.to_unsafe_h.merge(:filter => info[:value], :page => 1)), class: common_class)
      end
    end

    filter_content = "".html_safe
    unless filter_name.blank?
      filter_content << content_tag(:div, "#{filter_name}: ", class: "font-bold pull-sm-left m-r-xs p-t-xxs")
    end
    filter_content << links.join("").html_safe

    # This has been done so as to allow adjacent content to float.
    options[:class] = options[:class].to_s + " btn-group btn-group-sm filter_links"
    content_tag(:div, filter_content, options)
  end

  # Renders a dynamic text filter box.
  #
  # ==== Usage:
  #   dynamic_text_filter_box("type a choice name",
  #          "find_and_select_#{common_answer.common_question.id}",
  #          "find_common_answer_#{common_answer.common_question.id}",
  #          "MultiSelectAnswerSelector",
  #          "common_answers_#{common_answer.common_question.id}")
  #
  # ==== Params:
  # * <tt>default_filter_text</tt> : the default value of the text filter box.
  # * <tt>container_id</tt> : id of the top most div of the rendered filter box.
  # * <tt>find_info_box_id</tt> : id of the div containing find label and the find text field.
  # * <tt>select_handler</tt> : Name of the JS handler that handles selectAll and deSelectAll functionality.
  # * <tt>options</tt>: A hash with the following optionla keys:
  #         :handler_argument => A string argument to be passed to the select_handler. This is an optional argument. Defaults to nil.
  #         :display_show_helper => A boolean that tells whether to display the "Show: Selected | All" in the filter box. Defaults to true.
  #         :display_select_helper => A boolean that tells whether to display the "Select: All | None" in the filter box. Defaults to false.
  #

  def dynamic_text_filter_box(container_id, find_box_id, select_handler, options = {})
    options.reverse_merge!(:handler_argument => nil, :display_show_helper => true, :display_select_helper => false)
    handler_argument = options[:handler_argument]
    display_show_helper = options[:display_show_helper]
    display_select_helper = options[:display_select_helper]
    filter_box_additional_class = options[:filter_box_additional_class] || ''
    quick_find_additional_class = options[:quick_find_additional_class] || ''
    filter_input_text = options[:filter_input_text] || "display_string.Quick_Search".translate
    filter_box_helper_text = "".html_safe
    filter_box_link_text = "".html_safe

    if display_show_helper
      filter_box_link_text += content_tag(:div, :class => 'input-group-btn') do
        button_tag(('display_string.Show'.translate + " " + content_tag(:span, "", class: "caret")).html_safe, class: "btn btn-white dropdown-toggle", "data-toggle" => "dropdown", type: 'button') +
        content_tag(:ul, class: "dropdown-menu pull-right") do
          content_tag(:li) do
            link_to_function('display_string.Selected'.translate, "#{select_handler}.showSelected(#{"'" + handler_argument + "'" if handler_argument})", :class => "show_selected")
          end +
          content_tag(:li) do
            link_to_function('display_string.All'.translate, "#{select_handler}.showAll(#{"'" + handler_argument + "'" if handler_argument})", :class => "divider-vertical show_all")
          end
        end
      end
    end

    if display_select_helper
      filter_box_link_text += content_tag(:div, :class => 'input-group-btn') do
        button_tag(('display_string.Select'.translate + " " + content_tag(:span, "", class: "caret")).html_safe, class: "btn btn-white dropdown-toggle", "data-toggle" => "dropdown", type: 'button') +
        content_tag(:ul, class: "dropdown-menu pull-right") do
          content_tag(:li) do
            link_to_function('display_string.All'.translate, "#{select_handler}.selectAll(#{"'" + handler_argument + "'" if handler_argument})", :class => "select_all")
          end +
          content_tag(:li) do
            link_to_function('display_string.None'.translate, "#{select_handler}.deSelectAll(#{"'" + handler_argument + "'" if handler_argument})", :class => "divider-vertical select_none")
          end
        end
      end
    end

    filter_box_helper_text += content_tag(:div, class: "input-group col-xs-12") do
      label_tag(:quick_find, "feature.profile_question.content.search_multi_select".translate, :for => "quick_#{find_box_id}", :class => 'sr-only') +
      text_field_tag(:quick_find, nil, :id => "quick_#{find_box_id}", :class => 'form-control ' + quick_find_additional_class, :placeholder => filter_input_text) +
      filter_box_link_text
    end

    filter_box_class = "col-xs-12 m-t-sm m-b-sm cui_find_and_select_item " + filter_box_additional_class
    content_tag(:div, :class => filter_box_class, :id => container_id) do
      filter_box_helper_text
    end
  end

  #
  # Renders vertical filters for filtering content per sub program.
  #
  def sub_program_filters(programs = nil)
    # Do not render if not logged in.
    return unless organization_view? && logged_in_organization?

    all_label = "common_text.search.all_results".translate(results: _programs)

    items = []

    # Remove :filter_program_id from the url for 'All programs' link.
    items << {
      :text => all_label,
      :url => url_for(params.merge(:filter_program_id => nil))
    }

    programs ||= wob_member.active_programs.ordered
    programs.each do |program|
      items << {
        :text => program.name,
        :url => url_for(params.merge(:filter_program_id => program.id))
      }
    end

    # ApplicationController#sub_program_search_options sets
    # @filtered_program to the program that is currently selected.
    selected_item = @filtered_program ? @filtered_program.name : all_label

    content_tag(:div, :id => 'sub_program_filter', :class => "well") do
      vertical_filters(selected_item, items)
    end
  end

  #
  # Renders vertical filters similar to Google's search filters.
  #
  # === Params
  # * <tt>selected_item</tt>  : currently selected filter text.
  # * <tt>all_items</tt>      : Array of filter items with the following keys
  #
  # ** :text => the text to show for the item
  # ** :count => count text to show as suffix to the item text
  # ** :disabled => show as a disabled item
  #
  def vertical_filters(selected_item, all_items)
    item_links = []
    klass = " list-group-item "
    all_items.each do |_item|
      item_html_opts = { :class => klass }
      item_html_opts.merge!(:class => 'font-bold gray-bg' + klass) if _item[:text] == selected_item

      link_html_opts = _item[:html_opts].presence || {}
      link_html_opts[:class] ||= ""
      link_html_opts[:class] += " btn-link disabled" if _item[:disabled]

      # If :disabled is set, link to "#" so as to disable the link
      item_url = _item[:disabled] ? "javascript:void(0)".html_safe : _item[:url].html_safe

      # Suffix the text with the count if available.
      item_text = _item[:text]
      item_text += " (#{_item[:count]})".html_safe if _item[:count]
      item_content = link_to(item_text, item_url, link_html_opts)
      if _item[:text] == selected_item
        item_content += highlight_selected_item_in_list_group
      end
      item_links << content_tag(:li, item_content, item_html_opts)
    end

    content_tag(:div, class: "vertical_filters") do
      content_tag(:ul, item_links.join.html_safe, :class => 'links list-group')
    end
  end

  # Creates template cache for angularjs directives
  #
  # ==== Usage:
  #   chrng_template_cache(template_cache_id, options = {})
  #
  # ==== Params:
  # * <tt>template_cache_id</tt> : The template cache id used for directive templateUrl.
  # * <tt>options</tt> : A hash with the following details
  #         :element_name => The DOM element name that you will be using in html pages
  #
  def chrng_template_cache(template_cache_id, options = {})
    (@_angularjs_element_directives ||= []) << options[:element_name] if options[:element_name]
    content_tag(:script, type: "text/ng-template", id: template_cache_id) do
      yield
    end
  end

  def secure_protocol
    Rails.application.config.force_ssl ? 'https' : 'http'
  end

  # Has there been a questions change for current user within past 2 weeks?
  def profile_questions_recently_updated?
    last_update_timestamp = @current_program.profile_questions_last_update_timestamp(current_user)
    return false unless last_update_timestamp > 0
    (Time.at(last_update_timestamp) > ProfileConstants::PROFILE_CHANGE_PROMPT_PERIOD.ago)
  end

  # True if
  #   - there was a recent update and there is no cookie
  #   - there was a recent update and there is a cookie with old timestamp
  # False if
  #   - there was no recent update
  #   - there was a recent update and there is a cookie with current timestamp

  #We are not using this function any where
  def render_profile_questions_change?
    return false unless current_user.is_mentor_or_student?
    # This circus to access cookie_value is to keep the integration test happy.
    # In integration test, request.cookies[] returns an array. In functionals
    # and in a real request, its a scalar value.
    cookie_value = Array(request.cookies[DISABLE_PROFILE_PROMPT]).first.to_i
    questions_last_update_at = @current_program.profile_questions_last_update_timestamp(current_user)
    answers_last_update_at = current_user.answers_last_updated_at

    # These conditions should be met
    # * a. Was there a recent questions update
    # * b. The user has answered at least one question
    # * c. The user's last update to answers happened at an earlier date than
    # the questions update
    # * d. There isn't a profile prompt disable cookie
    profile_questions_recently_updated? &&
      (answers_last_update_at > 0) &&
      (questions_last_update_at > answers_last_update_at) &&
      (cookie_value < questions_last_update_at)
  end

  #
  # Renders a JS tooltip (span + script).
  # ==== Params
  # node_identifier ::  The identifier (can be a class or id) of the div for which the tooltip is to be rendered
  # tip_text        ::  The tooltip text.
  # options         ::  Set is_identifier_class if node_identifier is a class
  #
  def tooltip(node_identifier, tip_text, _relative = false, options = {})
    node_identifier = options[:is_identifier_class] ? ".#{node_identifier}" : "##{node_identifier}"
    options.reverse_merge!({html_escape: true})
    placement = options[:placement] ? options[:placement] : "top"
    container = options[:container] ? options[:container] : "#{node_identifier}"
    escaped_tip_text = options[:html_escape] ? content_tag(:div, j(tip_text), class: options[:container_class]) : j(tip_text)
    javascript_tag(%Q[jQuery("#{node_identifier}").tooltip({html: true, title: '#{escaped_tip_text}', placement: "#{placement}", container: "#{container}", delay: { "show" : 500, "hide" : 100 } } );jQuery("#{node_identifier}").on("remove", function () {jQuery("#{node_identifier} .tooltip").hide().remove();})])
  end

  def popover(node_selector, title, tip_text, options={})
    escaped_title = content_tag(:div, title)
    escaped_tip_text = content_tag(:div, tip_text)
    placement = options[:placement].presence || "bottom"
    container = options[:container].presence || ""
    javascript_tag(%Q[jQuery("#{node_selector}").addClass("cjs-node-popover"); jQuery("#{node_selector}").popover({html: true, placement: "#{placement}", title: "#{j escaped_title}", content: "#{j escaped_tip_text}", container: "#{container}"});].html_safe)
  end

  def translated_tab_label(label)
    options = TabConstants.translation_key(label)
    options[:is_key?] ? options[:value].translate(:Mentoring => _Mentoring) : options[:value]
  end

  def get_icon_content(icon_class, options = {})
    options.reverse_merge!(
      container_stack_class: "fa-stack-2x",
      icon_stack_class: "fa-stack-1x",
      invert: "fa-inverse"
    )
    other_options = options.except(:container_stack_class, :icon_stack_class, :invert, :container_class, :stack_class)

    if icon_class.present?
      if options[:container_class]
        content_tag(:span,
          content_tag(:i, options[:content], class: "fa #{options[:container_class]} #{options[:container_stack_class]}") +
          content_tag(:i, "", class: "#{icon_class} #{options[:icon_stack_class]} #{options[:invert]}"),
          { class: "fa-stack fa-lg fa-fw m-r-xs #{options[:stack_class]}", style: options[:stack_style] }.merge(other_options)
        )
      else
        content_tag(:i, options[:content], { :class => icon_class + " fa-fw m-r-xs" }.merge(other_options))
      end
    else
      content_tag(:span, "")
    end
  end

  # Render an application tab
  # If tab_info.subtabs is string, which implies the subtabs are present in a partial,
  #   we render the partial in a div wrapper. Eg. Forums
  # If tab_info.subtabs is not a string, then it will be an array. Eg. Advice
  def render_tab(tab_info, tab_class, options = {})
    if tab_info.subtabs.nil?
      render_tab_without_subtabs(tab_info, tab_class, options)
    else
      content_tag(:li) do
        content = get_sidebar_navigation_header_content(tab_info)
        content += content_tag(:ul, :class => "nav collapse #{'in' if tab_info.open_by_default}", :id => "#{tab_info.tab_class}") do
          subtab_content = get_safe_string
          tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::LINKS_LIST].each do |subtab_key|
            subtab_class = "active" if tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::IS_ACTIVE_HASH][subtab_key]
            link_or_partial = tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::RENDER_PATH_HASH][subtab_key]

            subtab_content += if tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::HAS_PARTIAL_HASH][subtab_key]
              render(:partial => link_or_partial, :locals => {:tab_info => tab_info, :subtab_class => subtab_class})
            else
              render_subtab_in_tab(tab_info, subtab_key, link_or_partial, subtab_class)
            end
          end
          subtab_content
        end
        content
      end
    end
  end

  def render_mobile_tab(tab_info, options = {})
    modal_options = {}
    icon_content = get_icon_content("fa fa-fw fa-lg no-margins #{tab_info.iconclass}")
    badge_content = tab_info.mobile_tab_badge.present? ? content_tag(:span, tab_info.mobile_tab_badge, class: "label label-danger cui_footer_menu_badge m-l-n-sm") : ""
    modal_options.merge!({data: {toggle: "modal", target: tab_info.mobile_tab_modal_id}}) if tab_info.mobile_tab_modal_id.present?
    content_tag(:div, class: "no-padding #{options[:col_class]} text-center theme-font-color mobile_tab #{'b-b' if tab_info.active}") do
      link_to content_tag(:div, icon_content  + badge_content + content_tag(:div, tab_info.label.truncate(MobileTab::MAX_LABEL_LENGTH), class: "small text-white"), class: "p-xs"), tab_info.url, {class: "font-bold theme-font-color no-padding #{tab_info.mobile_tab_class}"}.merge(modal_options)
    end
  end

  def mobile_footer_dropup_quick_link(name, url_or_method, icon_class = nil, new_items_count = nil, options = {})
    display_name = name.blank? ? "" : name.html_safe
    add_badge = (new_items_count && new_items_count > 0)
    
    content = get_safe_string
    content += content_tag(:div, get_icon_content(icon_class), class: "media-left p-l-xxs")
    link_content = get_safe_string
    badge_content = add_badge ? content_tag(:div, new_items_count, class: "#{options[:badge_class].present? ? options[:badge_class] : 'badge-danger'}" + ' badge pull-right m-l-xs', id: options[:badge_id].present? ? options[:badge_id] : '')  : get_safe_string
    link_content += content_tag(:div, :class => "media-body p-l-xxs") do
      content_tag(:div, display_name, :class => "pull-left") + badge_content
    end
    content += link_content
    content = link_to(content, url_or_method, options)
    content.html_safe
  end

  def show_mobile_connections_tab?(user)
    user.program.ongoing_mentoring_enabled? && user.roles.for_mentoring.exists? && (user.opting_for_ongoing_mentoring? || user.groups.active.present?)
  end
  
  def render_subtab_in_tab(tab_info, subtab_key, link_or_partial, subtab_class)
    label = tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::LINK_LABEL_HASH][subtab_key]
    badge_count = tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::BADGE_COUNT_HASH][subtab_key] if tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::BADGE_COUNT_HASH].present?
    icon_class = tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::ICON_CLASS_HASH][subtab_key] if tab_info.subtabs[TabConfiguration::Tab::SubTabKeys::ICON_CLASS_HASH].present?
    
    if subtab_key == TabConstants::DIVIDER
      content_tag(:li, horizontal_line(:class => "no-margins"))
    else
      get_tab_link_content(icon_class, label, link_or_partial, {tab_class: subtab_class, tab_badge_count: badge_count, tab_badge_class: "badge-danger"})
    end
  end

  def get_tab_link_content(tab_icon_class, tab_label, tab_url, options = {})
    has_badge_count = options[:tab_badge_count].present? && options[:tab_badge_count] > 0
    content_tag(:li, :class => options[:tab_class]) do
      content = content_tag(:div, get_icon_content("fa fa-fw #{tab_icon_class}"), :class => "media-left no-horizontal-padding") +
      content_tag(:div, :class => "media-body row") do
        body_content = content_tag(:div, truncate_html(tab_label, {max_length: NAVIGATION_SIDEBAR_TRUNCATE_LENGTH}), :class => "#{has_badge_count ? 'col-md-10 col-xs-10' : 'col-md-12 col-xs-12'} no-horizontal-padding")
        if has_badge_count
          body_content += content_tag(:div, :class => "col-md-2 col-xs-2 no-horizontal-padding") do
            content_tag(:span, options[:tab_badge_count], class: "badge #{options[:tab_badge_class]} pull-right")
          end
        end
        body_content
      end
      link_to(content, tab_url, :class => "navigation_tab_link")
    end
  end

  def render_tab_without_subtabs(tab_info, tab_class, options = {})
    tab_label = translated_tab_label(tab_info.label)
    if tab_label == TabConstants::DIVIDER
      content_tag(:li, horizontal_line(:class => "no-margins"), :class => tab_class)
    elsif options[:non_logged_in]
      content_tag(:li, link_to(get_icon_content("fa #{tab_info.iconclass}") + tab_label, tab_info.url), :class => tab_class)
    else
      tab_class << " #{tab_info.tab_class}" if tab_info.tab_class.present?
      get_tab_link_content(tab_info.iconclass, tab_label, tab_info.url, {tab_class: tab_class})
    end
  end

  def get_sidebar_navigation_header_content(tab_info)
    content_tag(:div, content_tag(:div, get_safe_string + translated_tab_label(tab_info.label), {class: "col-xs-10 no-horizontal-padding"}) + content_tag(:div, get_icon_content("fa fa-caret-down fa-fw fa-lg pull-right m-r-xs cjs_open_icon #{'hide' unless tab_info.open_by_default}") + get_icon_content("fa fa-caret-left fa-fw fa-lg pull-right m-r-xs cjs_close_icon #{'hide' if tab_info.open_by_default}"), {class: "col-xs-2 no-horizontal-padding"}), {class: "cjs_navigation_header pointer gray-bg font-85percent p-l-sm p-t-xs font-600 p-b-xxs m-t-xs b-b clearfix #{tab_info.tab_class}", data: {toggle: "collapse", target: "##{tab_info.tab_class}"}})
  end

  # Renders inner tabs with the tab configurations in tab_info_list
  #
  # ==== Params
  # tab_info_list - array of <code>Hash</code>es where each hash contains the
  #                 attributes for a Tab viz., :active, :label and :url
  #
  def inner_tabs(tab_info_list, options = {})
    return if tab_info_list.blank?

    content_tag(:div, class: "tabs-container inner_tabs") do
      content_tag(:div, class: options[:tab_position_class]) do
        content_tag(:ul, class: "nav nav-tabs h5 no-margins") do
          inner_content = "".html_safe
          inner_content << collect_inner_tabs(tab_info_list)
          inner_content
        end
      end
    end
  end

  def collect_inner_tabs(tab_info_list)
    content = get_safe_string
    tab_info_list.each do |tab_info|
      selected_class = 'active' if tab_info[:active]
      content << content_tag(:li, class: "#{tab_info[:tab_class]} #{selected_class}") do
        if tab_info[:dropdown].present?
          build_dropdown_link(tab_info[:dropdown][:options], tab_info[:dropdown][:actions])
        else
          link_to(tab_info[:label], tab_info[:url], tab_info[:link_options])
        end
      end
    end
    return content
  end

  #
  # Render a radio button based filter
  # Args:
  #   filter_name: The label of the filter
  #   cur_value: The current value of the filter, typically set in the controller
  #   filter_value: The value to of the current filter being rendered
  #   param_name: The url param name of the filter
  #
  # Eg. radio_button_filter("Requests sent to me", @list_field, 'me', :list
  #
  def radio_button_filter(filter_name, cur_value, filter_value, param_name, options = {})
    # :page => 1 to start off with new params from page 1
    reload_url = url_for(params.to_unsafe_h.merge(param_name => filter_value, :page => 1))
    filter_loading_id_name = "filter_#{param_name}_#{filter_value}_loading"
    label = filter_name
    action_on_click = options[:js_action] || "RadioFilter.reloadPage('#{filter_loading_id_name}', '#{reload_url}')"

    content_tag(:label, :class => 'radio font-noraml') do
      should_be_checked = (cur_value == filter_value)
      radio_button_tag(param_name, filter_value, should_be_checked, :onclick => action_on_click) + label +
        get_icon_content("fa fa-spinner fa-spin hide no-margins", id: filter_loading_id_name)
    end
  end

  def ie6_request?
    request.user_agent && (request.user_agent =~ /MSIE 6\.0/)
  end

  # Location autocomplete text field.
  # When +is_empty+ is true, renders defaults prompt text.
  def location_autocomplete(object, method, is_empty = false, tag_options = {}, completion_options = {})
    default_options = {
      :onclick => "clearDefaultText(this, '#{"app_constant.city_town_name".translate}')",
      :onblur => "setDefaultText(this, '#{"app_constant.city_town_name".translate}')",
      :onfocus => "clearDefaultText(this, '#{"app_constant.city_town_name".translate}')",
      :autocomplete => "off"
    }

    default_options.merge!(:value => "app_constant.city_town_name".translate) if is_empty

    default_completion_options = {
      :min_chars => 3,
      :param_name => 'loc_name',
      :url => locations_path(:format => :json)
    }
    text_field_with_auto_complete(object, method, default_options.merge(tag_options), default_completion_options.merge(completion_options))
  end

  def search_view?
    !@search_query.nil?
  end

  #
  # Renders the status icon for listing pages of email templates, mentoring tips
  #
  # === Params:
  #   *<tt>object</tt> : email_template, mentoring_tip or facilitation_message object
  #   *<tt>disable_link</tt> : link for disabling
  #   *<tt>enable_link</tt> : link for enabling
  #   *<tt>is_enabled</tt> : boolean indicating whether currently enabled.
  #
  def fetch_status_icon(object, disable_link, enable_link, is_enabled, options = {})
    object_id = object.is_a?(Hash) ? object[:uid] : object.id
    icon_id = "toggle_img_#{object_id}"

    content_tag(:span, :id => "status_icon_#{object_id}", :class => options[:class]) do
      if is_enabled
        link_to(
          content_tag(:big, content_tag(:i, "",
            :title => "feature.email.content.click_icon_to_disable".translate,
            :id => icon_id,
            :class => "text-default fa fa-check-square-o")) + set_screen_reader_only_content("feature.email.content.click_icon_to_disable".translate),
          disable_link,
          :method => :patch,
          :remote => true,
          :onclick => "enableDisableStatus.statusLoading('#{icon_id}')")
      else
        link_to(
          content_tag(:big, content_tag(:i, "",
            :title => "feature.email.content.click_icon_to_enable".translate,
            :id => icon_id,
            :class => "text-default fa fa-square-o")) + set_screen_reader_only_content("feature.email.content.click_icon_to_enable".translate),
          enable_link,
          :method => :patch,
          :remote => true,
          :onclick => "enableDisableStatus.statusLoading('#{icon_id}')")
      end
    end
  end

  def fetch_dummy_status_icon(is_enabled)
    content_tag(:span) do
      is_enabled ? get_icon_content("fa fa-check-square-o text-default") : get_icon_content("fa fa-square-o text-default")
    end
  end

  def get_content_after_page_load(url)
    javascript_tag("jQuery(function(){jQuery.ajax('#{url}');})")
  end

  def match_score_tool_tip(score, options = {})
    options[:second_person] ||= 'display_string.you'.translate
    if options[:mentor_ignored]
      "feature.user.label.not_a_match_tooltip_text".translate(username: options[:member_name])
    elsif score.nil?
      'feature.preferred_mentoring.content.tooltips.match_score_nil'.translate
    elsif score.zero?
      current_program.zero_match_score_message
    else
      'feature.preferred_mentoring.content.tooltips.match_score'.translate(mentor: _mentor, mentee_or_you: options[:second_person])
    end
  end

  def my_meeting_popover(meeting, current_occurrence_time = nil)
    %Q[<span class="small p-r-xxs font-bold">#{content_tag(:big, get_icon_content("fa fa-fw fa-calendar"))}</span> #{meeting_time_for_display(meeting, current_occurrence_time)} <br/> <br/>
      <span class="small p-r-xxs  font-bold">#{content_tag(:big, get_icon_content("fa fa-fw fa-map-marker"))}</span> #{h(meeting.location)} <br/> <br/>
      <span class="small p-r-xxs  font-bold">#{content_tag(:big, get_icon_content("fa fa-fw fa-users"))}</span> #{h(meeting.members.collect(&:name).join(", "))}].html_safe
  end

  def match_score_class(score)
    'not_match' if score.zero?
  end

  def show_noscript_warning
    content_tag(:noscript) do
      content_tag(:div, :id => "noscript_warning", :class => "alert alert-danger m-b") do
        ("common_text.show_noscript_warning_html".translate(link: link_to("common_text.enable_javascript".translate, "https://www.google.com/support/bin/answer.py?answer=23852", :target => "_blank")))
      end
    end.html_safe
  end

  def content_for_sidebar(&block)
    @show_side_bar = true
    content_for :sidebar do
      capture(&block)
    end
  end

  # Renders an action button if *actions* size is one
  # Renders a action button dropdown if *actions* size is greater than one
  # The options in the dropdown can be optionally sorted alphabetically by setting
  # the argument *sort_by_label* to true
  def dropdown_buttons_or_button(actions, options = {})
    actions.flatten!
    suffix_string = append_suffix_actions(actions)

    if actions.size == 0
      suffix_string
    elsif actions.size == 1 && !options[:dropdown_title]
      class_name =  "btn #{options[:primary_btn_class] || 'btn-primary'} #{'btn-large' if options[:large]} #{options[:btn_class]} #{'btn-sm' if options[:small]}"
      render_action_for_dropdown_button(actions[0], "#{class_name} #{actions[0][:btn_class_name]}").html_safe << suffix_string
    else
      actions = actions.sort{|x,y| x[:label] <=> y[:label]} if options[:sort_by_label]

      # This is set when you donot want a split button but just a dropdwon button
      if options[:dropdown_title]
        build_dropdown_button(options[:dropdown_title], actions, options) << suffix_string
      else
        build_split_button(actions, options) << suffix_string
      end
    end
  end

  def link_or_drop_down_actions(actions, options = {})
    actions.flatten!
    suffix_string = append_suffix_actions(actions)

    if actions.size == 0
      suffix_string
    elsif actions.size == 1 && !options[:dropdown_title]
      render_action_for_dropdown_button(actions[0], "#{options[:font_class]} #{actions[0][:btn_class_name]}").html_safe << suffix_string
    else
      build_dropdown_filters_without_button(options[:dropdown_title], actions, options) << suffix_string
    end
  end

  def build_split_button(actions, options = {})
    class_name =  "btn #{options[:primary_btn_class] || 'btn-primary'} #{'btn-large' if options[:large]} #{'btn-sm' if options[:small]}"
    btn_class = options.delete(:btn_class) || ""
    button_content = content_tag(:div, :class => "btn-group #{btn_class}") do
      render_action_for_dropdown_button(actions[0], "#{class_name} #{actions[0][:btn_class_name]} #{options[:btn_group_btn_class]} #{options[:responsive_primary_btn_class]}", options).html_safe +
      link_to(set_screen_reader_only_content("display_string.dropdown".translate) + '<span class="caret"></span>'.html_safe, "#", :class => ("#{class_name} #{options[:responsive_caret_class]} dropdown-toggle"), 'data-toggle' => 'dropdown') +
      content_tag(:ul, :class => "dropdown-menu #{options[:dropdown_menu_class]}") do
        other_actions = "".html_safe
        actions[1..-1].each do |ac|
          if ac[:border_top]
            other_actions << content_tag(:li, "", :class => "divider")
          end
          other_actions << content_tag(:li, render_action_for_dropdown_button(ac, "", options))
          if ac[:border_bottom]
            other_actions << content_tag(:li, "", :class => "divider")
          end
        end
        other_actions
      end
    end
    button_content
  end

  def build_dropdown_button(title, actions, options = {})
    actions.flatten!
    suffix_string = append_suffix_actions(actions)
    caret_class = options[:large].present? ? "btn-large" : ""
    caret_class << (options[:is_not_primary].present? ? " #{options[:primary_btn_class]} " : " btn-primary")
    btn_class = options.delete(:btn_class) || ""
    button_title = (title + " " + content_tag(:span, "", :class => "caret")).html_safe
    button_content = content_tag(:div, :class => "btn-group #{btn_class} #{'dropup' if options[:dropup]}") do
      link_to(button_title + set_screen_reader_only_content("display_string.Actions".translate), "javascript:void(0);", :class => "btn dropdown-toggle #{options[:btn_group_btn_class]} #{options[:responsive_primary_btn_class]}" << caret_class, 'data-toggle' => 'dropdown', :id => options[:id]) +
      content_tag(:ul, :class => "dropdown-menu #{options[:dropdown_menu_class]}") do
        other_actions = "".html_safe
        actions.each do |ac|
          other_actions << content_tag(:li, render_action_for_dropdown_button(ac, "#{'text-muted' if ac[:disabled]}", options))
        end
        other_actions
      end
    end
    button_content << suffix_string
  end

  def build_dropdown_filter(title, content, options = {})
    caret_class = options[:large].present? ? "btn-large" : ""
    caret_class << (options[:is_not_primary].present? ? "" : " btn-primary")
    btn_class = options.delete(:btn_class) || ""
    id = options[:id] || 'filters_dropdown'
    button_content = content_tag(:div, :class => "btn-group #{btn_class}", :id => id) do
      link_to((get_safe_string + title +" " + content_tag(:span, "",:class => "caret")), "javascript:void(0);", :class => "btn dropdown-toggle #{options[:btn_dropdown_class]}" << caret_class, 'data-toggle' => 'dropdown') +
      content_tag(:ul, :class => "dropdown-menu dropdown-filter #{options[:dropdown_menu_class]}") do
        content_tag(:li, content)
      end
    end
    button_content
  end

  def build_dropdown_filters_without_button(title, actions, options = {})
    actions.flatten!
    font_class = options[:font_class] || "text-default"
    filter_content = content_tag(:div, :class => "inline-block group-filters btn-group  #{'dropup' if options[:dropup]} #{options[:btn_group_class]}") do
      link_to(title, "javascript:void(0);", class: font_class, 'data-toggle' => 'dropdown', id: options[:id]) +
      (options[:without_caret] ? "" : get_icon_content("fa fa-caret-down")) +
      content_tag(:ul, :class => "dropdown-menu #{options[:dropdown_menu_class]}") do
        other_actions = "".html_safe
        actions.each do |ac|
          other_actions << ac[:border_top]
          other_actions << content_tag(:li, render_action_for_dropdown_button(ac, "", options))
          other_actions << ac[:border_bottom]
        end
        other_actions
      end
    end
    filter_content
  end

  def render_action_for_dropdown_button(ac, class_name = '', options = {})
    if ac[:render]
      ac[:render]
    else
      label_text = ac.delete(:label)
      label = (options[:embed_icon] && ac[:icon]) ? (get_icon_content(ac[:icon]) + label_text) : label_text
      if options[:embed_image].present?
        label = (options[:embed_image] && ac[:user_image]) ? ac[:user_image] : label_text
      end
      id = ac.delete(:id) || ""
      title = ac.delete(:title) || ""
      class_val = ac[:additional_class].present? ? "#{class_name} #{ac[:additional_class]}" : (ac[:class] || class_name)
      link_options = {:id => id, :class => class_val, :title => title}
      link_options.merge!({:method => ac[:method]}) if ac[:method]
      ac.deep_merge!({data: {:confirm => ac[:confirm]}}) if ac[:confirm]
      link_options.merge!({:data => ac[:data]}) if ac[:data]
      link_options.merge!(ac[:link_options]) if ac[:link_options]
      link_options.merge!({:target => ac[:target]}) if ac[:target]
      if ac[:disabled]
        link_to(label, "javascript:void(0)", :class => "btn-link disabled no-margin #{ac[:class] || class_name}", :rel => 'tooltip', :title => ac[:tooltip], :id => id.presence)
      elsif ac[:url]
        link_to(label, ac[:url], link_options)
      elsif ac[:remote]
        link_to(label, ac[:remote], link_options.merge({:remote => true}))
      elsif ac[:text]
        link_to(label, "javascript:void(0)", :class => 'btn-link no-margin')
      else
        link_to_function(label, ac[:js], :id => id, :class => (class_name.presence || ac[:class] || ac[:additional_class]), :title => title, :data => link_options[:data], method: link_options[:method])
      end
    end
  end

  def append_time_zone_help_text
    unless working_on_behalf?
      click_here_link = link_to("display_string.Click_here".translate, edit_member_url(wob_member, :section => MembersController::EditSection::SETTINGS,
        :scroll_to => "settings_section_general", :focus_settings_tab => true))
      content = "".html_safe
      if wob_member.time_zone.present?
        content += " #{'feature.calendar.content.time_zone_info_html'.translate(time_zone: ('<b>'+wob_member.full_time_zone+'</b>').html_safe)}. ".html_safe +  "#{'feature.calendar.content.change_time_zone_html'.translate(click_here: click_here_link.html_safe)}".html_safe
      else
        content += " #{'feature.calendar.content.default_timezone_text_html'.translate(utc: '<b>(GMT+00:00) UTC</b>'.html_safe)} ".html_safe + "#{'feature.calendar.content.set_time_zone_html'.translate(click_here: click_here_link)}".html_safe
      end
      content += (@is_self_view && current_user.is_mentor?) ? " #{'feature.calendar.content.change_availability_settings'.translate}".html_safe : ". ".html_safe
      concat content.html_safe
    end
  end

  def controls(options = {}, &block)
    additional_class = options.delete(:class)
    content_tag(:div, capture(&block), {:class => "controls #{additional_class}"}.merge(options))
  end

  def control_group(options = {}, &block)
    additional_class = options.delete(:class)
    content_tag(:div, capture(&block), {:class => "#{additional_class} form-group form-group-sm"}.merge(options))
  end

  # TODO - Responsive UI - CLEAN - Use construct_input_group instead
  def input_group(options = {}, &block)
    additional_class = options.delete(:class)
    content_tag(:div, capture(&block), {:class => "#{additional_class} input-group m-b-sm"}.merge(options))
  end

  def prepend_icon(image_url, text = "", options = {})
    (content_tag(:i, image_tag(image_url, options), :class => "icon-all") + text).html_safe
  end

  def embed_icon(image_class, text = "", options = {})
    (content_tag(:i, "", {:class => image_class}.merge(options)) + text).html_safe
  end

  def append_text_to_icon(icon_class, text = "", options = {})
    icon = options[:icon_path].present? ? link_to(get_icon_content(icon_class, options), options[:icon_path]) : get_icon_content(icon_class, options)
    if options[:media_padding_with_icon]
      icon = content_tag(:div, icon, class: "media-left p-r-0 #{options[:additional_icon_class]}")
      text = content_tag(:div, text, class: "media-body")
    end
    (text.present? ? "#{icon}#{text}" : icon).html_safe
  end

  def mentoring_model_v2_icon(item, options = {})
    icon_class = ""
    case item
    when "manage_mm_milestones"
      icon_class = "fa fa-tasks"
    when "manage_mm_goals"
      icon_class = "fa fa-dot-circle-o"
    when "manage_mm_tasks"
      icon_class = "fa fa-check-square-o"
    when "manage_mm_meetings"
      icon_class = "fa fa-calendar-o"
    when "manage_mm_messages"
      icon_class = "fa fa-envelope-o"
    when "manage_mm_engagement_surveys"
      icon_class = "fa fa-comments-o"
    end
    container_option = options[:container_class] ? {:container_class => options[:container_class]} : {}
    get_icon_content(icon_class, container_option)
  end

  def auto_complete_li_class
    "list-group-item p-l-xs word_break"
  end

  def help_text_content(text, id)
    content_tag(:div, text.present? ? chronus_auto_link(text) : nil, class: "help-block small text-muted", id: "question_help_text_#{id}")
  end

  def email_recipients_note(recipients_text)
    content_tag(:p, "common_text.send_email_note_html".translate(Note: content_tag('b', "display_string.Note_with_colon".translate), recipients_text: recipients_text))
  end

  def bulk_action_users_or_members_list(users_or_members, viewer_info)
    if users_or_members.first.is_a?(User)
      bulk_action_users_list(users_or_members, render_profile_link: viewer_info[:program_admin])
    else
      bulk_action_members_list(users_or_members, render_profile_link: viewer_info[:organization_admin])
    end
  end

  def bulk_action_users_list(users, options = {})
    program_root = users[0].program.root # To render program level profile link
    users_list =
      if options[:render_profile_link]
        users.collect { |user| link_to(user.name(name_only: true), member_path(user.member_id, root: program_root)) }
      else
        users.collect { |user| user.name(name_only: true) }
      end.join(COMMON_SEPARATOR)
    options[:render_profile_link] ? users_list.html_safe : users_list
  end

  def bulk_action_members_list(members, options = {})
    members_list =
      if options[:render_profile_link]
        members.collect { |member| link_to(member.name, member_path(member, organization_level: true)) }
      else
        members.collect(&:name)
      end.join(COMMON_SEPARATOR)
    options[:render_profile_link] ? members_list.html_safe : members_list
  end

  def horizontal_line(options = {})
    tag(:hr, options)
  end

  # Returns an array of time slots eg. ["12:00am", "12:30am"...., "11:30pm", "12:00am"]
  # slot_duration - specify in minutes eg. 30
  # number_of_hours - The number of hours for which the slots needs to be generated
  def generate_slots_list(slot_duration, number_of_hours = 24)
    calendar_start = Time.new.beginning_of_day
    (0..(number_of_hours * (60/slot_duration))).collect do |time_index|
      DateTime.localize(calendar_start + (time_index * slot_duration).minutes, format: :short_time_small)
    end
  end

  def get_contact_admin_path(program, options = {})
    contact_admin_setting = program.try(:contact_admin_setting)
    organization = program.present? ? program.organization : options[:organization]
    label_name = options[:label].presence || (contact_admin_setting && contact_admin_setting.label_name.presence) || "app_layout.label.contact_admin_v1".translate(Admin: organization.admin_custom_term.term)
    label_name = options[:iconclass]  + " " + label_name if options[:iconclass].present?
    contact_url = (contact_admin_setting && contact_admin_setting.contact_url.presence) || contact_admin_url(options[:url_params])
    if options[:as_array].present?
      [h(label_name), contact_url]
    else
      options[:only_url].present? ? contact_url : content_tag(:a, label_name, :href => contact_url, class: "no-waves", target: options[:target])
    end
  end

  def has_importable_question?(profile_questions)
    profile_questions.any? { |question|  question.experience? }
  end

  def progress_bar(percentage, options = {})
    progress_bar_id = options[:id] || "progress_#{percentage}"
    progress_bar = content_tag(:div, :id => progress_bar_id, :class => "#{options[:class].to_s} progress #{options[:color_class] || ""}") do
      content_tag(:div, "", :class => "progress-bar", :style => "width: #{percentage}%")
    end
    progress_bar << append_tooltip(progress_bar_id, options[:tooltip_content] || "#{percentage}%") if options[:tooltip]
    progress_bar
  end

  def render_rjs(page, path)
    page << render(:template => path.sub(/.js.erb$/,""), :handlers => [:erb], :formats => [:js])
  end

  def append_time_zone(event_time, object)
    [event_time, object.short_time_zone].join(" ").html_safe
  end

  def embed_display_line_item(heading, content, options={})
    render :partial => "common/display_line_item", :locals => {:heading => heading, :content => content, :options => options}
  end

  # TODO_DATE_RANGE_FORMAT_GLOBALIZATION
  def to_daterangepicker_display_format_string(str)
    str.
      gsub("%m", "mm").
      gsub("%d", "dd").
      gsub("%Y", "yy")
  end

  def to_js_datetime_format_string(str)
    str.
      gsub("%m", "MM").
      gsub("%d", "dd").
      gsub("%Y", "yyyy")
  end

  def map_kendo_date_format(kendo_format)
    {
      "kendo_date_picker.formats.full_display_no_time".translate => :full_display_no_time,
      "kendo_date_picker.formats.date_range".translate => :date_range
    }[kendo_format]
  end

  def ajax_disabled_check
    javascript_tag(
      %Q[jQuery(document).ready(function(){
          jQueryAjaxEnabled("#{j('common_text.show_no_ajax_warning_html'.translate(link: link_to("common_text.enable_ajax".translate, "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/files/StepstoenableAJAX.pdf", :target => '_blank')))}");
        });]
    )
  end

  def display_time_zone_alert
    member_time_zone = wob_member.get_valid_time_zone
    member_time_zone_offset = ActiveSupport::TimeZone.new(member_time_zone).now.utc_offset
    javascript_tag(
      %Q[jQuery(document).ready(function(){
        timezoneJSTranslations = #{raw get_translations_hash_for_valid_timezone_identifiers.to_json};
        TimeZoneFlash.showTimeZoneInfo("#{member_time_zone}", #{member_time_zone_offset}, #{TimezoneConstants::VALID_TIMEZONE_IDENTIFIERS.to_json}, #{TimezoneConstants::OBSOLETE_TIMEZONES_HASH.to_json}, "#{notify_new_timezone_path}");
      });]
    )
  end

  def show_ajax_jquery_flash_message
    output = "".html_safe
    if flash[:notice].present? || flash[:error].present?
      if flash[:notice].present?
        output << raw("toastr.clear(); toastr.success('#{j flash[:notice]}', '', #{ToastrType::OPTIONS[ToastrType::SUCCESS].to_json});")
      elsif flash[:error].present?
        output << raw("toastr.clear(); toastr.error('#{j flash[:error]}');")
      end
      flash.discard
    end
    return output
  end

  def add_one_more_link(options = {})
    link_to(get_icon_content("fa fa-plus-circle") + "display_string.Add_one_more".translate, "", {:class => "help-block cjs_add_one_more_link btn-sm btn btn-white pull-left"}.merge(options))
  end

  def truncate_content(text, length)
    truncate_html(chronus_sanitize_while_render(auto_link(text.html_safe), :sanitization_version => @current_organization.security_setting.sanitization_version, :sanitization_options => {:attributes => %w[style href cellspacing cellpadding border], :tags => %w[tbody table tr td th a strong span ul li ol em u]}), :max_length => length, :status => true)
  end

  def display_ckeditor_content(text, allowed_tags)
    sanitize(text, :attributes => %w[class style _cke_saved_href accesskey align allowscriptaccess alt bgcolor border cellpadding cellspacing charset classid codebase colspan data-cke-realelement dir height href hspace id lang longdesc name onclick pluginspage quality rel rowspan scale scope src start summary tabindex target title type value vspace width wmode], :tags => allowed_tags).to_s.html_safe
  end

  def collapsible_mentor_search_filter(filter_params, title, field_name)
    value = (filter_params.present? && filter_params[title.downcase.to_sym].present?) ? filter_params[title.downcase.to_sym] : ""
    profile_filter_wrapper(title, value.empty?, true, false) do
      right = [
        {
          type: "btn",
          btn_options: {
            :onclick => %Q[jQuery(this).closest('form').submit();],
            :class => 'btn btn-primary btn-sm'
          },
          content: "display_string.Go".translate,
          class: "filter_actions form-actions"
        }, {
          type: "btn",
          btn_options: {
            :onclick => %Q[jQuery("#search_filters_#{field_name.to_s}").val(""); jQuery(this).closest('form').submit();],
            :class => 'clear_filter btn btn-sm btn-white',
            :id => "reset_filter_#{field_name.to_s}"
          },
          content: "display_string.Clear".translate,
          class: "hide"
        }
      ]

      construct_input_group([], right, :input_group_class => "input-group-sm") do
        label_tag(:search_filters, title, :for => "search_filters_#{field_name.to_s}", :class => 'sr-only') +
        text_field(:search_filters, field_name, :value => value, :class => "form-control input-sm")
      end
    end
  end

  def get_target_roles(filter_role, role, roles, user)
    filter_role ? filter_role : role ? [role] : roles ? roles : user ? user.role_names : nil
  end

  def render_more_less_rows(rows, limit = DEFAULT_TRUNCATION_ROWS_LIMIT, options = {})
    divider = options[:divider] || "<br/>"
    if rows.size > limit
      see_more_link = link_to 'display_string.show_more_down_count_html'.translate(:count => rows[3..-1].size, :down_arrow => get_icon_content("fa fa-chevron-down")), "javascript:void(0)", :class => "cjs_see_more_rows_link"
      result = content_tag( 'span', raw((rows[0..2]).join(divider)) + see_more_link)

      see_less_link = link_to 'display_string.show_less_up_html'.translate(:down_arrow => get_icon_content("fa fa-chevron-up")), "javascript:void(0)", :class => "cjs_see_less_rows_link"
      result += content_tag( 'span', raw((rows[3..-1]).join(divider)) + see_less_link, :style =>"display:none;")
    else
      raw(rows.join(divider))
    end
  end

  def render_more_less(content, limit = 60, options = {})
    truncated_text, truncated = truncate_html(content, max_length: limit, ellipsis: "... ", status: true)
    see_more_text = options[:more] ? options[:more] : 'display_string.show_more_raquo_html'.translate
    see_less_text = options[:less] ? options[:less] : 'display_string.laquo_show_less_html'.translate
    class_name = options[:class] ? options[:class] : ''
    if truncated
      see_more_link = link_to see_more_text, "javascript:void(0)", class: "#{class_name} cjs_see_more_link"
      result = content_tag('span', truncated_text + see_more_link, style: get_more_less_style(options[:default_state], :more))
      see_less_link = link_to see_less_text, "javascript:void(0)", class: "#{class_name} cjs_see_less_link"
      result += content_tag('span', (content + see_less_link).html_safe, style: get_more_less_style(options[:default_state], :less))
    else
      content_tag('span', truncated_text)
    end
  end

  def get_more_less_style(default_state, for_state)
    style = {more: "", less: "display:none;"}
    style = {more: "display:none;", less: ""} if default_state == :expanded
    style[for_state]
  end

  def get_detailed_list_toggle_buttons(detailed_view_link, list_view_link, list_view_active)
    general_class = "btn btn-white btn-sm"
    content_tag(:div, id: "toggle_bar", class: "pull-right m-l-sm #{hidden_on_mobile}") do
      content_tag(:div, class: "btn-group btn-group-sm") do
        link_to_function(get_icon_content("fa fa-th-large m-r-0") + set_screen_reader_only_content("display_string.grid_view".translate), detailed_view_link, class: list_view_active ? general_class : "#{general_class} active", id: "detailed_view", data: { title: "display_string.grid_view".translate, toggle: "tooltip" } ) +
        link_to_function(get_icon_content("fa fa-th-list m-r-0") + set_screen_reader_only_content("display_string.list_view".translate), list_view_link, class: list_view_active ? "#{general_class} active" : general_class, id: 'list_view', data: { title: "display_string.list_view".translate, toggle: "tooltip" } )
      end
    end
  end

  def get_time_for_time_zone(time, time_zone, format)
    DateTime.localize(time.in_time_zone(time_zone.presence || TimezoneConstants::DEFAULT_TIMEZONE), format: format)
  end

  def display_member_name(member)
    h("#{member.first_name} #{member.last_name}".strip)
  end

  def day_options_for_select
    [["display_string.Day".translate, '']] + (1..31).to_a
  end

  def month_options_for_select
    months = "date.abbr_month_names_array".translate
    [["display_string.Month".translate, '']] + (1..12).map{|month| [months[month-1], month]}
  end

  def year_options_for_select(years_range = nil)
    [["display_string.Year".translate, '']] + (years_range || ProfileConstants.valid_years)
  end

  def preserve_new_line(text_content)
    simple_format(h(text_content), {}, sanitize: false)
  end

  def wizard_wrapper(headers, selected_header, options = {}, wrap = true)
    if wrap
      wizard_headers(headers, selected_header, options) do
        yield
      end
    else
      ibox nil do
        yield
      end
    end
  end

  def wizard_headers(headers, selected_header, options = {})
    tab_array = []
    counter = 0
    headers.each do |header_key, header_value|
      counter += 1
      label = content_tag(:span, "#{counter}.", class: "h3 m-r-xs") + content_tag(:span, header_value[:label])
      disabled_class = (options[:disable_unselected] && (header_key != selected_header)) ? "disabled" : ""
      tab_array << { label: label, url: (header_value[:url] || "javascript:void(0)"), active: (header_key == selected_header), tab_class: "#{disabled_class} #{header_value[:class]}", link_options: (header_value[:link_options] || {}) }
    end

    content = ibox nil, ibox_class: "wizard_view no-margins", content_class: "no-padding" do
      inner_tabs(tab_array)
    end
    content += ibox nil, content_class: "#{options[:content_ibox_content_class]}" do
      yield
    end
    return content
  end

  def cjs_wizard(headers, selected_header, options = {})
    tab_array = []
    counter = 0
    headers.each do |header_key, header_value|
      counter += 1
      link_options = header_value[:link_options] ? header_value[:link_options] : {}
      link_options = link_options.merge({data: {toggle: "tab"}})
      label = content_tag(:span, "#{counter}.", class: "h3 m-r-xs") + content_tag(:span, header_value[:label])
      disabled_class = (options[:disable_unselected] && header_key != selected_header) ? "disabled" : ""
      tab_array << { label: label, url: (header_value[:url] || "javascript:void(0)"), active: (header_key == selected_header), tab_class: "#{disabled_class}", link_options: link_options }
    end

    content = ibox nil, ibox_id: "wizard_view", ibox_class: "no-margins", content_class: "no-padding" do
      inner_tabs(tab_array)
    end
    content += ibox nil, content_class: "tab-content" do
      yield
    end
    return content
  end

  def cjs_wizard_section(id, options = {})
    content_tag(:div, class: "tab-pane no-padding #{options[:class]}", id: id) do
      yield
    end
  end

  def bgcolor_for_match_score(score)
    score.to_i.zero? ? 'bg-darkgrey' : 'bg-greenhighlight'
  end

  def get_role_checkboxes(role_names, program, options={})
    content = []
    checkbox_tag_name = options.delete(:name) || "role_names[]"
    selected_roles = options.delete(:selected) || []
    role_names.each do |role_name|
      selected = selected_roles.include? role_name
      content << content_tag(:label, class: "checkbox inline m-r-xs") do
        check_box_tag(checkbox_tag_name, role_name, selected, options.merge(id: "#{role_name}_role")) +
        RoleConstants.human_role_string([role_name], program: program)
      end
    end

    choices_wrapper("display_string.Roles".translate, id: "role_names_select", class: "inline-block") do
      content.join("").html_safe
    end
  end

  def get_preview_checkboxes(role_names, program, options = {})
    ibox nil, :ibox_class => "form-horizontal" do
      control_group(class: "no-margin") do
        content_tag(:div, :class => "control-label false-label col-sm-2") do
          content_tag(:h4, "feature.profile_customization.label.select_roles_for_preview".translate)
        end +
        controls(class: "col-sm-10") do
          get_role_checkboxes(role_names, program, options)
        end
      end
    end
  end

  def get_logout_options(additional_class = "")
    { method: :delete, class: "cjs_signout_link #{additional_class}" }
  end

  def get_program_listing_options
    return {} unless @current_organization.active? && logged_in_organization?
    multiple_programs = get_active_member_programs(wob_member, @current_organization)
    {
      multiple_programs: multiple_programs,
      member_has_many_active_programs: (multiple_programs.size > 1),
      list_style: "list-group-item no-borders",
      list_class: "text-default"
    }
  end

  def include_ckeditor_tag
    javascript_include_tag "ckeditor/ckeditor_config.js"
  end

  def alert_badge(count)
    count = count || 0
    badge_class = count > 0 ? "badge-danger" : "badge-not-started"
    content_tag(:span, count, :class => "badge #{badge_class}")
  end

  def link_with_alert(name, url, alert_count)
    content_tag(:div, alert_badge(alert_count) + link_to(name, url, :class => "has-before"), :class => "has-below")
  end

  def owner_content_for_user_name(group, user)
    (current_user.can_manage_or_own_group?(group) && user.is_owner_of?(group)) ? " (#{'feature.connection.content.owner'.translate})" : ""
  end

  def flash_msg_for_not_allowing_mentoring_requests(program)
    program.allow_mentoring_requests_message.presence || "flash_message.mentor_request_flash.blocked_by_admin_v1".translate(program: _program, administrator: _admin)
  end

  def get_demo_program_url
    return "#{DEMO_URL_SUBDOMAIN}.#{DEFAULT_DOMAIN_NAME}"
  end

  def get_support_url(options = {})
    options.delete(:url) ? zendesk_session_url(options) : zendesk_session_path(options)
  end

  def get_support_link(options = {})
    content = get_safe_string
    content << get_icon_content("fa fa-fw fa-life-ring") if options.delete(:include_icon)
    content << "app_layout.label.support".translate
    link_to content, get_support_url(options), target: "_blank", class: "cjs_external_link"
  end

  def display_role_content(current_organization, role, role_description, display_content)
    string = content_tag(:span, display_content, class: "font-bold m-l-sm")
    string += content_tag(:div, get_role_description(current_organization, role, display_content), class: "m-l-sm font-noraml") if role.present?
    return string
  end

  #Should be removed when all programs are being created by solution pack only
  def get_role_description(current_organization, role, display_content)
    unless role.description.blank?
      return role.description.html_safe
    else
      if RoleConstants::MENTORING_ROLES.include?(role.name)
        description = "feature.membership_request.content.role_description.#{role.name}".translate(Mentors: _Mentors, Mentees: _Mentees, mentor: _mentor, mentees: _mentees)
        faq_page = if ([role.name] & RoleConstants::MENTORING_ROLES).any?
          current_organization.pages.find_by(title: RoleConstants::FAQ_PAGE[role.name])
        end
        link_to_faq_page = faq_page.present? ? link_to("feature.membership_request.content.role_description.faq_page_html".translate(title: display_content), page_path(faq_page, organization_level: true)) : ""
        "#{description} #{link_to_faq_page}".html_safe
      end
    end
  end

  def get_role_description_and_edit_options(current_organization, role, display_content)
    display_string = ''
    role_description = get_role_description(current_organization, role, display_content)
    display_string += role_description.present? ? role_description : content_tag(:span, "program_settings_strings.content.no_description".translate,class: "dim display:inline")
    display_string += ' ' + link_to("program_settings_strings.content.edit_description".translate, 'javascript:void(0)', :class => "strong ie-nowrap", :id => "role_description_edit_#{role.name}", :onclick => "ProgramSettings.roleDescriptionEdit('#{role.name}')")
    return role_description, display_string
  end

  def get_programs_and_portals_select_box(scope, options = {})
    wrapper_proc = Proc.new do |programs, opts, &block|
      content_tag(:optgroup, block.call(programs, opts), label: opts[:title]).html_safe
    end

    all_programs_options = options.delete(:include_all_programs) ? [["display_string.All_Programs_v1".translate(Programs: _Programs), -1]] : []

    result = options_for_select(all_programs_options)
    result += ProgramsListingService.list_programs scope, wrapper_proc do |programs, opts|
      programs_options = programs.collect do |p|
        options_parms = options[:options_proc].present? ? options[:options_proc].call(p) : {}
        [p.name, p.id.to_i] << options_parms
      end
      options_for_select(programs_options)
    end
  end

  def get_urls_for_attachments(prog_asset, attachment_type, second_locale)
    [I18n.default_locale, second_locale].inject([]) do |urls, locale|
      urls << GlobalizationUtils.run_in_locale(locale) do
        prog_asset.send(attachment_type).exists? ? prog_asset.send(attachment_type).url : nil
      end
    end
  end

  def hidden_on_web
    "hidden-lg hidden-md"
  end

  def hidden_on_mobile
    "hidden-xs hidden-sm"
  end

  def hidden_above_tab
    "hidden-lg"
  end

  def hidden_on_and_below_tab
    "hidden-sm hidden-xs hidden-md"
  end

  def show_search_box?
    program_view? && logged_in_program? && !current_user.profile_pending? && current_program.searchable_classes(current_user).any?
  end

  def fixed_layout?
    asset_type = program_context.logo_or_banner_url([:banner, :logo], true).last
    return (asset_type == :banner) || !@current_organization.fluid_layout?
  end

  def render_multi_column_variable_height_blocks(column_size, options = {})
    result = "".html_safe
    renderable_items = Hash.new{|hash, key| hash[key] = []}

    yield(renderable_items)

    column_size.times do |index|
      result << content_tag(:div, renderable_items[index].join(" ").html_safe, :class => "col-sm-#{GRID_SIZE/column_size} #{options[:additional_class]}")
    end

    return result
  end

  def set_required_field_label(label_text)
    "#{label_text} #{content_tag(:abbr, "simple_form.required.mark".translate, title: "simple_form.required.text".translate)}".html_safe
  end

  def sidepane_assets_pane(sidepane_assets, options = {}, &block)
    render :partial => "common/sidepane_assets_pane", :locals => {:sidepane_assets => sidepane_assets, :options => options}
  end

  def render_page_action(page_action, options = {})
    if page_action.is_a?(Array)
      if options[:dropdown_title].present?
        options = { :dropdown_menu_class => "pull-right" }.merge(options)
        build_dropdown_button(options.delete(:dropdown_title), page_action, options)
      else
        dropdown_options = { dropdown_menu_class: "pull-right" }
        if options[:small]
          dropdown_options[:small] = true
        else
          dropdown_options[:large] = true
        end
        dropdown_buttons_or_button(page_action, dropdown_options)
      end
    else
      label = page_action[:label]
      options = page_action.except(:label, :url, :js)

      if page_action[:url].present?
        link_to label, page_action[:url], options
      else
        link_to_function label, page_action[:js], options
      end
    end
  end

  def vertical_separator
    content_tag(:span, "|", class: "text-muted p-l-xxs p-r-xxs")
  end

  def horizontal_separator
    content_tag(:span, "-", class: "text-muted p-l-xxs p-r-xxs")
  end

  def circle_separator
    content_tag(:small, content_tag(:small, get_icon_content("fa fa-circle text-muted p-l-xxs p-r-xxs")))
  end

  def dismissable_alert(alert_content, options = {})
    alert_options = {:class => "alert #{options[:alert_class] ? options[:alert_class] : 'alert-warning'}"}
    alert_options.merge!(:id => options[:alert_id]) if options[:alert_id]
    close_link_data_options = {:dismiss => "alert"}
    close_link_data_options.merge!(:url => options[:close_link_url]) if options[:close_link_url]
    close_link_options = {:type => 'button', "aria-hidden" => "true"}
    close_link_options.merge!(:data => close_link_data_options)
    close_link_options.merge!(:class => "close #{options[:close_link_class]}")
    close_link_options.merge!(:id => options[:close_link_id]) if options[:close_link_id]
    alert_box = content_tag(:div, alert_options) do
      button_tag("&times;".html_safe, close_link_options) +
      alert_content.html_safe
    end
    alert_box
  end

  # options: { element_id: , icon_class: , only_value_container: true/false, in_listing: true/false }
  def display_stats(metric_value, metric_label = "", options = {})
    value_container = if options[:in_listing]
      content_tag(:span, metric_value, class: "views-number font-bold", id: options[:element_id])
    else
      content_tag(:h1, metric_value, class: "no-margins font-bold", id: options[:element_id])
    end
    return value_container if options[:only_value_container]

    right_small_label_container = if options[:right_small_label]
      content_tag(:span, options[:right_small_label], class: "small m-l-xs inline")
    else
      content_tag(:span, "")
    end
    label_container = content_tag(:div, class: "#{options[:container_class]}") do
      if options[:icon_class].present?
        append_text_to_icon(options[:icon_class], metric_label)
      elsif options[:is_link]
        link_to(metric_label, options[:url])
      else
        metric_label
      end
    end
    value_container + right_small_label_container + label_container
  end

  def render_tips_in_sidepane(tips, pane_header = "")
    sidepane_assets_pane tips,
      pane_header: pane_header.presence || "feature.question_answers.content.tips.header".translate,
      asset_icon_class: "fa fa-lightbulb-o",
      item_class: "no-borders"
  end

  # options: { class: , id: , method: , data: , get_page_action_hash: true/false, handle_html_data_attr: true/false, toggle_class: { active: , inactive: } }
  def toggle_button(url, contents, is_active, options = {})
    current_content = is_active ? contents[:active] : contents[:inactive]
    substitute_content = is_active ? contents[:inactive] : contents[:active]
    substitute_content.gsub!("\"", "'") if options[:handle_html_data_attr] # to handle the quotes in the data attribute

    action_hash = {
      label: current_content,
      js: "javascript:void(0)",
      class: "#{options[:class]} #{is_active ? options[:toggle_class][:active] : options[:toggle_class][:inactive]}",
      id: options[:id],
      method: options[:method].presence || :post,
      data: {
        url: url,
        replace_content: substitute_content,
        toggle_class: options[:toggle_class].values.join(" ")
      }
    }
    action_hash[:data].merge!(options[:data]) if options[:data].present?

    if options[:get_page_action_hash]
      action_hash[:btn_class_name] = action_hash.delete(:class)
      return action_hash
    end
    link_to_function action_hash[:label], action_hash[:js], action_hash.except(:label, :js)
  end

  def loc_loading(options = {})
    content_tag(:i, "", class: "fa fa-spinner fa-spin fa-fw #{options[:loader_class] || "loc-loading"} #{options[:class]}", :id => options[:id].to_s, :style => "display:none")
  end

  def construct_input_group(left = [], right = [], options = {}, &block)
    content_tag(:div, class: "input-group #{options[:input_group_class]}") do
      if left.present?
        lefts = left.is_a?(Array) ? left : [left]
        lefts.each do |left_group_element|
          concat construct_input_group_addon(left_group_element) if left_group_element.present?
        end
      end
      concat capture(&block)
      if right.present?
        rights = right.is_a?(Array) ? right : [right]
        rights.each do |right_group_element|
          concat construct_input_group_addon(right_group_element) if right_group_element.present?
        end
      end
    end
  end

  def filter_container_wrapper(mobile_footer_actions = {}, filter_title = nil, &block)
    return capture(&block) unless mobile_footer_actions.present?

    default_mobile_footer_actions = {
      see_n_results: {
        url: "javascript:void(0)",
        class: "font-bold",
        id: "cjs_see_n_results",
        data: { toggle: "offcanvasright" },
        wrapper_class: "col-xs-6 text-left p-l-0"
      },
      reset_filters: {
        label: append_text_to_icon("fa fa-refresh", "feature.connection.action.reset_all_v1".translate),
        wrapper_class: "col-xs-6 text-right p-r-0",
        id: "cjs_reset_all_filters"
      }
    }

    if mobile_footer_actions.present?
      mobile_footer = ""
      results_link_text = mobile_footer_actions[:see_n_results].delete(:results_link_text)
      mobile_footer_actions.each do |key, options|
        action_hash = (default_mobile_footer_actions[key] || {}).merge(options || {})
        results_link_text = results_link_text || "display_string.see_n_results".translate(count: action_hash.delete(:results_count).to_i)
        mobile_footer += content_tag(:div, class: "#{action_hash.delete(:wrapper_class)}") do
          label = if key == :see_n_results
            append_text_to_icon("fa fa-chevron-left", results_link_text, media_padding_with_icon: true)
          else
            action_hash.delete(:label)
          end
          link_to_wrapper(true, action_hash) { label }
        end
      end
    end

    @filters_in_sidebar = true
    @sidebar_footer_content = mobile_footer if mobile_footer.present?
    content_tag(:div, class: "filter_pane m-b-xl", id: "filter_pane") do
      ibox(filter_title, content_class: "no-padding") do
        content_tag(:div, class: "panel-group no-margins") do
          capture(&block)
        end
      end
    end
  end

  def link_to_wrapper(wrap = false, link_options = {}, &block)
    return capture(&block) unless wrap

    if link_options[:url]
      link_to link_options[:url], link_options.except(:url) do
        capture(&block)
      end
    elsif link_options[:js]
      link_to "javascript:void(0)", { onclick: link_options[:js] }.merge(link_options.except(:js)) do
        capture(&block)
      end
    end
  end

  # Why inline-block!?
  # http://getbootstrap.com/components/#labels
  def labels_container(labels = [], wrapper_options = {})
    labels = labels.flatten.reject(&:nil?)
    if labels.present?
      content_tag((wrapper_options[:tag] || :div), wrapper_options.except(:tag)) do
        content = ""
        labels.each do |label_hash|
          content += render_label_inline(label_hash)
        end
        content.html_safe
      end
    end
  end

  def render_label_inline(label_hash)
    content_tag(:span, { class: "label inline m-r-xs m-b-xxs #{label_hash[:label_class]}" }.merge(label_hash[:options] || {})) do
      label_hash[:content]
    end
  end

  # http://getbootstrap.com/css/#helper-classes-screen-readers
  def set_screen_reader_only_content(text, options = {})
    content_tag(:span, text, class: "sr-only #{options[:additional_class]}")
  end

  def get_device_based_sr_only_content(text)
    content_tag(:span, text, class: "hidden-xs") + set_screen_reader_only_content(text, additional_class: "visible-xs")
  end

  def choices_wrapper(label, options = {})
    options.reverse_merge!(class: "choices_wrapper", role: "group", aria: { label: label })
    content_tag(:div, options) do
      yield
    end
  end

  def listing_page(collection, options = {})
    content_tag(:div, class: "list-group") do
      content = "".html_safe
      list_group_item_padding = options[:list_group_item_padding] || "p-m"
      collection.each_with_index do |object, index|
        content += content_tag(:div, class: "#{options[:list_group_item_class]} clearfix list-group-item #{list_group_item_padding} #{"#{object.class.name.underscore.gsub('/', '_')}_#{object.try(:id)}"} word_break") do
          render partial: options[:partial], locals: { options[:collection_key] => object, "#{options[:collection_key]}_counter".to_sym => index }.merge(options[:locals] || {})
        end
        if options[:collection_key] == :topic
          content += topic_form_initializers(object, options)
        end
      end
      content
    end
  end

  def topic_form_initializers(object, options)
    mobile_view = (mobile_app? || mobile_device?).to_s.to_boolean
    javascript_tag(%Q[ jQuery(document).on("click", ".cjs_follow_topic_link_#{object.id}, .cjs_see_less_link", function(event) {
          event.stopPropagation();});
          jQuery(document).on('click', ".topic_#{object.id}", function(){ Discussions.renderSelectedTopic('#{object.id}', '#{ forum_topic_path(object.forum, object) }', #{options[:locals][:home_page]}, #{mobile_view})});].html_safe)
  end

  ## This method has been defined explicitly that
  # the data attributes are properly set ( as Strings and in parsable-date-formats )
  def date_picker_options(options = {})
    GlobalizationUtils.run_in_locale(I18n.default_locale) do
      date_picker_options = {}
      date_picker_options[:date_picker] = true
      date_picker_options[:rand_id] = "datepicker-#{SecureRandom.hex(3)}"
      if options[:min_date].present?
        date_picker_options[:min_date] = DateTime.localize(options[:min_date], format: :full_display_no_time)
      end
      if options[:max_date].present?
        date_picker_options[:max_date] = DateTime.localize(options[:max_date], format: :full_display_no_time)
      end
      if options[:current_date].present?
        date_picker_options[:current_date] = DateTime.localize(options[:current_date], format: :full_display_no_time)
      end
      date_picker_options.merge(options.pick(:disable_date_picker, :wrapper_class, :date_range))
    end
  end

  ## This method creates a select_tag to select the presets, 2 input_tags with date-pickers,
  # and a hidden field ( which is the value that gets submitted ). If only 'Custom', then select_tag will
  # not be shown.

  ## Options:
  # presets: <Array>, defaults to DateRangePresets.defaults
  # right_addon: <Hash>, will be passed as one of the right addon for the 'end' date of range
  # max_date: <Date>, maximum date that can be selected from date-picker
  # min_date: <Date>, minimum date that can be selected from date-picker
  # input_size_class: <String>, defaults to nil - can be 'input-sm', 'input-md', 'input-lg'
  # hidden_field_attrs: <Hash>
  # date_format: Date format for the hidden field
  def construct_daterange_picker(param_name, values = {}, options = {})
    presets = options[:presets] || DateRangePresets.defaults
    return unless presets.include?(DateRangePresets::CUSTOM)
    date_range_preset = options[:date_range_preset] || DateRangePresets::CUSTOM

    content = get_safe_string
    only_custom = (presets == [DateRangePresets::CUSTOM])
    rand_id = SecureRandom.hex(3)

    unless only_custom
      preset_options = []
      presets.each { |preset| preset_options << [DateRangePresets.translate(preset), preset] }
      presets_data = (presets.include?(DateRangePresets::PROGRAM_TO_DATE) && current_program.present?) ?
        { program_start_date: DateTime.localize(current_program.created_at, format: :date_range) } : {}
      content += control_group do
        label_tag(nil, "#{'chronus_date_range_picker_strings.presets.date_range'.translate} #{'display_string.Options'.translate}",
          class: "sr-only",
          for: "cjs_daterange_picker_presets_#{rand_id}") +
        select_tag("date_range_preset", options_for_select(preset_options, date_range_preset),
          class: "form-control cjs_daterange_picker_presets #{options[:input_size_class]}",
          data: presets_data.merge(ignore: true, current_date: DateTime.localize(Date.current, format: :date_range)),
          id: "cjs_daterange_picker_presets_#{rand_id}")
      end

      additional_input_fields = options[:additional_input_fields]
      additional_input_fields&.each { |additional_input_field| content += additional_input_field }
    end

    calendar_addon = { type: "addon", icon_class: "fa fa-calendar" }
    start_datepicker_data = {
      max_date: (values[:end].presence || options[:max_date]),
      min_date: options[:min_date],
      date_range: "start",
      wrapper_class: (options[:input_size_class].presence || "")
    }
    end_datepicker_data = {
      max_date: options[:max_date],
      min_date: (values[:start].presence || options[:min_date]),
      date_range: "end",
      wrapper_class: (options[:input_size_class].presence || "")
    }

    content += construct_input_group([calendar_addon], []) do
      label_tag(nil, "display_string.From".translate,
        class: "sr-only",
        for: "cjs_daterange_picker_start_#{rand_id}") +
      text_field_tag(nil, (values[:start].present? ? DateTime.localize(values[:start], format: :full_display_no_time) : ""),
        class: "cjs_daterange_picker_start #{'cjs_no_clear_selection' if options[:no_clear_selection]} form-control ",
        placeholder: "display_string.From".translate,
        id: "cjs_daterange_picker_start_#{rand_id}",
        autocomplete: :off,
        data: date_picker_options(start_datepicker_data).merge(ignore: true))
    end
    content += construct_input_group([calendar_addon], [options[:right_addon]].flatten.compact, input_group_class: "m-t-xs") do
      label_tag(nil, "display_string.To".translate,
        class: "sr-only",
        for: "cjs_daterange_picker_end_#{rand_id}") +
      text_field_tag(nil, (values[:end].present? ? DateTime.localize(values[:end], format: :full_display_no_time) : ""),
        class: "cjs_daterange_picker_end #{'cjs_no_clear_selection' if options[:no_clear_selection]} form-control ",
        placeholder: "display_string.To".translate,
        id: "cjs_daterange_picker_end_#{rand_id}",
        autocomplete: :off,
        data: date_picker_options(end_datepicker_data).merge(ignore: true))
    end

    # To support the BBQPlugin.addHashChangeListener method,
    # data-ignore is set to the input fields and hidden_field_tag is not used intentionally
    hidden_field_attrs = options[:hidden_field_attrs] || {}
    hidden_field_format = (options[:date_format].presence || "kendo_date_picker.formats.date_range".translate)
    hidden_field_options = { class: "hide cjs_daterange_picker_value #{hidden_field_attrs[:class]}", data: { date_format: hidden_field_format } }.merge(hidden_field_attrs.pick(:id))
    hidden_field_value = values.present? ? "#{DateTime.localize(values[:start], format: map_kendo_date_format(hidden_field_format))}#{DATE_RANGE_SEPARATOR}#{DateTime.localize(values[:end], format: map_kendo_date_format(hidden_field_format))}" : ""
    content += label_tag((hidden_field_attrs[:id].presence || param_name), (hidden_field_attrs[:label].presence || "chronus_date_range_picker_strings.presets.date_range".translate), class: "hide")
    text_field_tag_options = {}
    text_field_tag_options.merge!(id: options[:use_text_field_tag_id]) if options[:use_text_field_tag_id]
    content += text_field_tag(param_name, hidden_field_value, hidden_field_options.merge(text_field_tag_options))
    content += javascript_tag("jQuery(document).ready(function(){initialize.setDatePicker();jQuery('.cjs_daterange_picker_presets').trigger('change')})")

    return content_tag(:div, class: "cjs_daterange_picker") do
      content
    end
  end

  def date_range_filter_header(daterange_values, options = {})
    icon_content = get_icon_content("fa fa-clock-o no-margins m-r-xs")
    range_content = content_tag(:span, get_reports_time_filter(daterange_values, options), class: "cjs_reports_time_filter m-r-xs m-l-xs")
    link_content = content_tag(:span, icon_content + range_content + content_tag(:span, "", class: "caret"))
    link_to link_content, "javascript:void(0)", class: "dropdown-toggle no-waves #{options[:additional_header_class]}", data: { toggle: "dropdown" }, id: ("report_date_range" + options[:id_suffix].to_s)
  end

  def horizontal_or_separator(margin_class = "m", text = nil)
    text ||= "display_string.OR".translate
    content_tag(:div, class: "text-center login-separator-container table-bordered #{margin_class}") do
      content_tag(:span, text, class: "big text-muted p-r-xs p-l-xs login-separator font-bold white-bg")
    end
  end

  def get_tnc_privacy_policy_urls
    {
      terms: link_to("feature.user.content.acceptable_use_policy".translate, terms_path, target: "_blank", class: "cjs_external_url"),
      privacy_policy: link_to("feature.user.content.privacy_policy".translate, privacy_policy_path, target: "_blank", class: "cjs_external_url"),
      cookies: link_to(content_tag(:b, "feature.user.content.cookies".translate), privacy_policy_path(scroll_to: "chronus-cookie-policy"), target: "_blank", class: "cjs_external_url")
    }
  end

  def set_customized_terms_update_flash
    show_connection_settings_link = @current_program.try(:ongoing_mentoring_enabled?)
    overview_pages_link = link_to("feature.page.action.program_overview_pages".translate(program: _Program), about_path, target: "_blank")
    if show_connection_settings_link
      connection_settings_link = link_to("flash_message.organization_flash.connection_closure_reasons".translate(Mentoring_Connection: _Mentoring_Connection), edit_program_path(tab: ProgramsController::SettingsTabs::CONNECTION), target: "_blank")
      flash[:notice] = "flash_message.organization_flash.terms_changed_program_html".translate(overview_page: overview_pages_link, connection_settings_page: connection_settings_link)
    else
      flash[:notice] = "flash_message.organization_flash.terms_changed_html".translate(overview_page: overview_pages_link)
    end
  end

  def populate_feedback_id(params, current_program)
    return true unless params[:meeting_id].present?
    meeting = current_program.meetings.find_by(id: params[:meeting_id])
    return false unless meeting.present?
    @current_occurrence_time = params[:current_occurrence_time].present? ? Meeting.parse_occurrence_time(params[:current_occurrence_time]) : meeting.occurrences.first.start_time
    @hashed_feedback_selector = ".update_feedback_#{meeting.id}_#{@current_occurrence_time.to_i}"
    return true
  end

  def mobile_app_class_for_download_files
    is_ios_app? ? "cjs_external_link" : "cjs_android_download_files"
  end

  def mobile_app?
    is_ios_app? || is_android_app?
  end

  def is_ios_app?
    browser.platform.ios_webview?
  end

  def is_android_app?
    browser.platform.android? && request.user_agent && !(request.user_agent =~ /Chronusandroid/).nil?
  end

  def is_iab?
    is_android_app? && !(request.user_agent =~ /ChronusandroidIAB/).nil?
  end

  def is_kitkat_app?
    is_android_app? && browser.platform.android?("4.4.2")
  end

  def mobile_browser?
    ios_browser? || android_browser?
  end

  def ios_browser?
    browser.platform.ios? && !is_ios_app?
  end

  def android_browser?
    browser.platform.android? && !is_android_app?
  end

  def android_app_store_link(organization, source)
    if organization.present?
      "https://play.google.com/store/apps/details?id=com.chronus.mentorp&referrer=utm_source%3D#{organization.url}%26utm_medium%3D#{source}"
    else
      "https://play.google.com/store/apps/details?id=com.chronus.mentorp"
    end
  end

  def get_traffic_origin
    if mobile_app?
      'mobile_app'
    elsif mobile_browser?
      'mobile_browser'
    else
      'others'
    end
  end

  def is_external_link?(url)
    return false if !@current_organization.present?
    allowed_hosts = ["mentor.localhost.com", "mentor.chronus.com", "mentor.realizegoal.com", "standby.realizegoal.com", "secure.localhost.com", "secure.chronus.com", "secure.realizegoal.com", "securementorva.chronus.com", "securetraining.realizegoal.com", "securestandby.realizegoal.com", "securescanner.chronus.com", "securereleasestaging2.realizegoal.com", "securereleasestaging1.realizegoal.com", "secureproductioneu.chronus.com", "secureperformance.realizegoal.com", "secureopstesting.realizegoal.com", "securementornch.chronus.com", "securementorge.chronus.com", "securedemo.chronus.com"]
    org_hostnames = @current_organization.hostnames
    allowed_hosts = allowed_hosts + org_hostnames
    current_host = URI.parse(url).host
    return false if current_host.nil?
    return allowed_hosts.exclude?(current_host)
  end

  # https://github.com/nraboy/ng-cordova-oauth/issues/283#issuecomment-246137484
  def use_browsertab_for_external_link?(url)
    return false unless is_external_link?(url)

    [OpenAuthUtils::Configurations::Google::AUTHORIZE_ENDPOINT, OAuthCredential::Provider.supported_provider_urls].flatten.any? do |uri|
      uri = URI(uri)
      uri.query = ""
      url.match(uri.to_s).present?
    end
  end

  def mobile_platform
    return MobileDevice::Platform::IOS if is_ios_app?
    MobileDevice::Platform::ANDROID if is_android_app?
  end

  def get_program_context_path(program_context, src)
    program_context.is_a?(Program) ? program_root_path(:root => program_context.root, :src => src) : root_organization_path(:src => src)
  end

  def password_instructions
    password_message = @current_organization.chronus_auth.try(:password_message).try(:html_safe)
    return password_message.presence || "common_text.help_text.password_requirement".translate(n: 6)
  end

  def build_dropdown_link(options, actions)
    title = get_safe_string + (options[:title] || "") + content_tag(:span, "", class: "caret")
    content = link_to(title, "javascript:void(0)", data: { toggle: "dropdown" } )
    content += content_tag(:ul, class: "dropdown-menu") do
      inner_content = get_safe_string
      actions.each do |dropdown_action|
        inner_content += content_tag(:li, render_action_for_dropdown_button(dropdown_action), class: dropdown_action[:tab_class]||"")
      end
      inner_content
    end
    content
  end

  def user_media_container(user, time = nil, actions = nil, options = {}, &block)
    ie_class = options[:ie_browser_support] ? " cui_ie_maxwidth300" : ""
    content_tag(:div, class: "p-sm") do
      (actions || get_safe_string) +
      content_tag(:div, class: "media-left") do
        user_picture(user, { no_name: true, size: :medium, outer_class: "no-margins" }, { class: "img-circle" } )
      end +
      content_tag(:div, class: "media-body") do
        content_tag(:h4) do
          inner_content = get_safe_string
          inner_content += link_to_user(user, current_user: current_user)
          if time.present?
            inner_content += content_tag(:div, class: "m-t-xs small") do
              get_icon_content("fa fa-clock-o text-default no-margins") +
              content_tag(:span, formatted_time_in_words(time), class: "text-muted")
            end
          end
          inner_content
        end
      end +
      content_tag(:div, class: "p-t-sm clearfix" + ie_class) do
        capture(&block)
      end
    end
  end

  def render_mobile_floating_action_inline(options)
    return if options.blank?
    render(partial: "common/mobile_floating_action", locals: { options: options, inline: true } )
  end

  def is_mobile_tab_active?(tab_type, options = {})
    cname = options[:controller]
    aname = options[:action]
    case tab_type
    when MobileTab::Home
      is_mobile_home_tab_active?(cname, aname)
    when MobileTab::Request
      is_mobile_requests_tab_active?(cname, aname, options)
    when MobileTab::Message
      is_mobile_messages_tab_active?(cname, aname)
    when MobileTab::Discover
      (cname == 'groups' && aname == 'find_new')
    when MobileTab::Connection
      is_mobile_connections_tab_active?(cname, aname, options)
    when MobileTab::Match
      (cname == 'users' && aname == 'index')
    when MobileTab::Notification
      is_mobile_notifications_tab_active?(cname, aname, options)
    when MobileTab::Manage
      is_manage_tab_active?(cname, aname, options)
    end
  end

  def is_mobile_home_tab_active?(cname, aname)
    (cname == 'programs' && aname == 'show') || (cname == 'reports' && aname == "management_report")
  end

  def is_mobile_requests_tab_active?(cname, aname, options = {})
    (cname == 'mentor_requests' && aname == 'index') || (cname == 'meeting_requests' && aname == 'index') || (cname == 'mentor_offers' && aname == 'index') || (cname == 'program_events' && aname == 'index') || (cname == 'members' && aname == 'show' && options[:tab] == MembersController::ShowTabs::AVAILABILITY)
  end

  def is_mobile_messages_tab_active?(cname, aname)
    (cname == 'messages' && aname == 'index') || (cname == 'admin_messages' && aname == 'index')
  end

  def is_mobile_connections_tab_active?(cname, aname, options = {})
    group = @current_program.groups.find(options[:group_id]) if options[:group_id].present?
    mobile_connections_tab_active = !group.nil? && group.has_member?(@current_user)
    (cname == 'groups' && aname == 'show') || (cname == 'groups' && aname == 'index') || mobile_connections_tab_active || (!@current_program.calendar_enabled? && (cname == 'members' && aname == 'show' && options[:tab] == MembersController::ShowTabs::AVAILABILITY))
  end

  def is_mobile_notifications_tab_active?(cname, aname, options = {})
    (cname == 'messages' && aname == 'index') || (cname == 'admin_messages' && aname == 'index') || (cname == 'program_events' && aname == 'index') || (cname == 'project_requests' && aname == 'index') || (cname == 'members' && aname == 'show' && options[:tab] == MembersController::ShowTabs::AVAILABILITY && options[:meetings_tab] != MeetingsController::MeetingsTab::PAST)
  end

  def is_manage_tab_active?(cname, aname, options = {})
    (cname == 'pages') ||
    (cname == 'programs' && aname == 'manage') ||
    (cname == 'programs' && aname == 'edit') ||
    (cname == 'programs' && aname == 'new') ||
    (cname == 'mentor_requests' && (aname == 'index') || (aname == 'manage')) ||
    (cname == 'announcements') ||
    (cname == 'membership_requests') ||
    (cname == 'programs' && aname == 'invite_users') ||
    (cname == 'users' && aname == 'new') ||
    (cname == 'users' && aname == 'matches_for_student') ||
    (cname == 'users' && aname == 'new_from_other_program') ||
    (cname == 'csv_imports') ||
    (cname == 'bulk_matches') ||
    (cname == 'bulk_recommendations') ||
    (cname == 'questions') ||
    (cname == 'reports' && aname != "management_report") ||
    (cname == "admins") ||
    (cname == "groups" && aname == "index" && options[:show] != 'my') ||
    (cname == "groups" && aname == "new") ||
    (cname == "groups" && aname == "add_members") ||
    (cname == "mentoring_tips") ||
    (cname == 'surveys') ||
    (cname == 'survey_questions') ||
    (cname == 'programs' && aname == 'edit_analytics') ||
    (cname == 'program_invitations') ||
    (cname == 'confidentiality_audit_logs') ||
    (cname == 'admin_messages') ||
    (cname == 'forums' && aname != "show") ||
    (cname == 'mentor_request/instructions' && aname == "index") ||
    (cname == 'connection/questions' && aname == "index") ||
    (cname == 'themes') ||
    (cname == 'email_templates') ||
    (cname == 'profile_questions')||
    (cname == 'role_questions') ||
    (cname == 'mailer_templates') ||
    (cname == 'mailer_widgets') ||
    (cname == 'membership_questions') ||
    (cname == 'resources') ||
    (cname == 'admin_views') ||
    (cname == 'flags' && aname == 'index') ||
    (cname == 'posts' && aname == 'moderatable_posts') ||
    (cname == 'meetings' && aname == 'mentoring_sessions') ||
    (cname == 'data_imports') ||
    (cname == 'organization_languages') ||
    (cname == 'match_configs') ||
    (cname == 'mentoring_models') ||
    (cname == 'campaign_management/user_campaigns') ||
    (cname == 'group_checkins') ||
    (cname == 'campaign_management/abstract_campaign_messages') ||
    (cname == 'translations')||
    ((current_user && current_user.is_admin?) && cname == "project_requests" && aname == "index")
  end

  def render_report_tiles(current_count, icon_content, tile_title, tile_text, options={})
    render :partial => 'common/report_tile', :locals => {current_count: current_count, percentage: options[:percentage], prev_periods_count: options[:prev_periods_count], icon_content: icon_content, tile_title: tile_title, tile_text: tile_text}  
  end

  def back_to_reports_options(category = Report::Customizations::Category::HEALTH)
    { label: "feature.reports.header.reports".translate, link: category ? categorized_reports_path(category: category) : reports_path }
  end

  def get_ckeditor_type_classes(klass)
    case klass
    when CampaignManagement::AbstractCampaign.name
      "cjs_ckeditor_dont_register_for_tags_warning"
    when MentoringModel::FacilitationTemplate.name
      "cjs_ckeditor_dont_register_for_tags_warning cjs_ckeditor_dont_register_for_insecure_content"
    end
  end

  def get_page_subtitle(sub_title_class, screen_reader_content)
    content_tag(:span, get_icon_content("fa fa-map-signs"), :class => "#{sub_title_class} pointer vertical-align-text-top") + content_tag(:span, screen_reader_content, class: "sr-only")
  end

  def list_privacy_policy_points(translation_key, suffixes = [])
    return get_safe_string if suffixes.blank?

    content_tag(:ul) do
      suffixes.each do |suffix|
        concat content_tag(:li, "#{translation_key}#{suffix}".translate, class: "m-b-xs")
      end
    end
  end

  def render_privacy_policy_para(translation_key, suffixes = [])
    str = get_safe_string
    return str if suffixes.blank?

    suffixes.each do |suffix|
      str += content_tag(:div, "#{translation_key}#{suffix}".translate, class: "m-b-sm")
    end
    str
  end

  def get_data_hash_for_dropzone(owner_id, type_id, options = {})
    data_hash = {
      url: file_uploads_path,
      url_params: {
        type_id: type_id,
        owner_id: owner_id,
        uploaded_class: options[:uploaded_class]
      },
      accepted_types: (options[:accepted_types] || DEFAULT_ALLOWED_FILE_UPLOAD_TYPES).join(","),
      class_list: options[:class_list] || "",
      max_file_size: options[:max_file_size],
      max_file_size_limit_message: 'flash_message.profile_answer.file_attachment_profile_answer_v1'.translate(file_size: options[:max_file_size]/ONE_MEGABYTE)
    }
    options[:file_name].present? ? data_hash.merge({ init_file: { name: options[:file_name] } }) : data_hash
  end

  def render_select_all_clear_all(select_all_function, clear_all_function, options = {})
    select_all_text = options[:select_all_text] || "display_string.Select_all".translate
    clear_all_text = options[:clear_all_text] || "display_string.Clear".translate
    select_all_options = options[:select_all_options] || {}
    clear_all_options = options[:clear_all_options] || {}
    link_to_function(select_all_text, select_all_function, select_all_options) +
    vertical_separator +
    link_to_function(clear_all_text, clear_all_function, clear_all_options)
  end

  private

  def append_tooltip(progress_bar_id, content)
    tooltip(progress_bar_id, content)
  end

  def append_suffix_actions(actions)
    suffix_actions = actions.select{|action| action[:suffix] == true}
    suffix_content = "".html_safe
    suffix_actions.each do |sac|
      actions.delete(sac)
      suffix_content << sac[:content]
    end
    suffix_content
  end

  def path_eligibility_rules(role)
    admin_view = role.admin_view
    if admin_view.nil?
      return new_admin_view_path(format: :js, role: role, is_org_view: true)
    else
      return edit_admin_view_path(admin_view, format: :js, role: role, is_org_view: true, editable: true)
    end
  end

  def download_ck_attachment_if_exist
    if session[:ck_attachment_url].present? && logged_in_at_current_level?
      flash_message = "common_text.download_will_start_automatically".translate(link: link_to("display_string.click_here".translate, session[:ck_attachment_url]))
      content = javascript_tag %Q[redirect_to_ck_asset('#{j(session[:ck_attachment_url])}', '#{j(flash_message)}')] if Time.now - session[:ck_attachment_set_time] < CK_ATTACHMENT_SESSION_TIMEOUT
      session[:ck_attachment_url] = nil
      session[:ck_attachment_set_time] = nil
      return content
    end
  end

  def construct_input_group_addon(options = {})
    addon_class = options.delete(:class)
    if options[:type] == "addon"
      content_tag(:span, class: "input-group-addon gray-bg #{addon_class}", data: options[:data], style: options[:style], :id => options[:id]) do
        if options[:icon_class].present?
          get_icon_content("#{options[:icon_class]} m-r-0")
        else
          options[:content]
        end
      end
    elsif options[:type] == "btn"
      content_tag(:span, { class: "input-group-btn flat-border #{addon_class}" }.merge(options.pick(:id, :data, :style))) do
        button_tag options[:btn_options] do
          options[:content]
        end
      end
    end
  end

  def construct_comments_button(options={})
    if options[:type] == 'btn'
      button_options = options.except(:icon, :content, :type, :set_screen_reader_only)
      button_options[:class] ||= ""
      button_options[:class] += " pull-right cjs_comment_button"
      submit_button = (content_tag :span, append_text_to_icon("#{options[:icon]}", options[:set_screen_reader_only] ? "" : "#{options[:content]}"), class: "hidden-xs") +
        (content_tag :span, get_icon_content("#{options[:icon]} no-margins"), class: "visible-xs") +
        set_screen_reader_only_content(options[:content])
      button_options.deep_merge!({data: {disable_with: "#{submit_button}"}})
      button_tag submit_button, button_options
    elsif options[:type] == 'link'
      link_options = options.except(:icon, :content, :url, :type, :set_screen_reader_only)
      link_options[:class] ||= ""
      link_options[:class] +=" pull-right"
      link_to options[:url], link_options do
        (content_tag :span, append_text_to_icon("#{options[:icon]}", options[:set_screen_reader_only] ? "" : "#{options[:content]}"), class: "#{options[:link_class]} hidden-xs") +
        (content_tag :span, get_icon_content("#{options[:icon]} no-margins"), class: "visible-xs") + set_screen_reader_only_content(options[:content])
      end
    elsif options[:type] == 'file'
      wrapper_options = options[:wrapper_html] || {}
      wrapper_options[:class] ||= ""
      label_options = options[:label_html] || {}
      label_text = label_options.delete(:text) || "display_string.attach_file".translate
      label_options = label_options.except(:text, :for, :set_screen_reader_only)
      label_options[:class] ||= ""
      label_options[:class] += "sr-only"
      control_group(wrapper_options) do
        concat (label_tag options[:id], label_text, label_options) +
        (controls do
          file_field_tag options[:name], id: "#{options[:id]}", class: "#{options[:class]}", data: options[:data]
        end)
      end
    end
  end

  def render_comments_button_group(buttons = [])
    content = get_safe_string
    if buttons.present?
      buttons.each do |button|
        content += construct_comments_button(button)
      end
    end
    content
  end

  def get_match_details_for_display(user, profile_user, program_questions_for_user, options = {})
    match_details = user.get_match_details_of(profile_user, program_questions_for_user, options[:show_match_config_matches])
    tags_array = match_details.collect{|tag| tag[:answers]}
    total_match_configs_or_preferences_count = tags_array.count
    matched_configs_or_preferences_count = tags_array.count{|tag| tag.present?}
    tags = tags_array.flatten
    tags_content = "".html_safe
    tags.each do |tag|
      tags_content += content_tag(:span, tag, class: "label small status_icon inline cui_label_vertical_align_correction m-r-xs")
    end
    details_content = get_details_content_for_match_details(tags_content)
    [details_content, tags.count, matched_configs_or_preferences_count, total_match_configs_or_preferences_count]
  end

  def get_details_content_for_match_details(tags_content)
    details_content = "".html_safe
    if tags_content.present?
      details_content += content_tag(:span, class: "match_details no-padding cjs_match_details") do
        tags_content
      end
    end
    details_content
  end

  def highlight_selected_item_in_list_group
    get_icon_content("fa fa-check-circle fa-lg no-margins text-navy pull-right")
  end
end

# See CucumberAjaxCallTracker class for details
def cucumber_helper_track_page_load_begin()
  javascript_tag(%Q[window.cucumber_page_load_begin = true;].html_safe) if ENV['CUCUMBER_ENV'] && !ENV['CUCUMBER_DISABLE_PENDING_AJAX_CHECKS']
end

# See CucumberAjaxCallTracker class for details
def cucumber_helper_track_page_load_end()
  javascript_tag(%Q[jQuery(document).ready(function() {window.cucumber_page_load_end = true;});].html_safe) if ENV['CUCUMBER_ENV'] && !ENV['CUCUMBER_DISABLE_PENDING_AJAX_CHECKS']
end

def get_valid_emails(test_emails)
  return "" unless test_emails.present?
  emails = test_emails.split(',').map(&:strip).map(&:downcase).uniq
  emails.reject! {|email| ValidatesEmailFormatOf::validate_email_format(email).present?}
  emails.join(COMMON_SEPARATOR)
end