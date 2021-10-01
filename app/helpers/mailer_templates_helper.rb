module MailerTemplatesHelper
  def disable_status_change?(uid, prog_or_org)
    ChronusActionMailer::Base.always_enabled?(uid) || is_mail_feature_dependent?(uid, prog_or_org)
  end

  def is_mail_feature_dependent?(uid, prog_or_org)
    email_klass = ChronusActionMailer::Base.get_descendant(uid)
    feature_list = FeatureName.dependent_emails.select{|feature, mailer_hash| mailer_hash[:enabled].include?(email_klass)}.keys
    feature_list.present? ? feature_list.inject(false){|always_enabled, feature| always_enabled || prog_or_org.has_feature?(feature)} : false
  end

  def update_all_alert_for_rollout
    content_tag(:table, class: "no-border no-margin") do
      content_tag(:tr) do
        content_tag(:td) do
          content_tag(:span, "feature.email.content.rollout_update_all_alert_message_v1".translate)
        end +
        content_tag(:td) do
          link_to("feature.email.content.rollout_update_all".translate, update_all_rollout_emails_path, class: "btn btn-primary has-before-1 cui-rollout-flash-button", method: :patch, data: { :confirm => "feature.email_customization.rollout.update_all_confirmation".translate, :disable_with => "display_string.Please_Wait".translate }, id: "rollout_update_all_help_text") + tooltip("rollout_update_all_help_text", "feature.email.content.rollout_update_all_help_text".translate(:program => _program))
        end +
        content_tag(:td) do
          link_to("feature.email.content.update_non_customized".translate, update_all_rollout_emails_path(non_customized: true), class: "btn btn-primary has-before-1 cui-rollout-flash-button", method: :patch, data: { :confirm => "feature.email_customization.rollout.update_non_coustomized_confirmation".translate, :disable_with => "display_string.Please_Wait".translate}, id: "update_non_customized_help_text") + tooltip("update_non_customized_help_text", "feature.email.content.update_non_customized_help_text".translate)
        end
      end
    end
  end

  def email_edit_link_params(enable_update, email, options = {})
    link_txt = enable_update ? "feature.email.action.Customize".translate : "feature.email.action.Preview".translate
    link_url = email[:rollout] ? "javascript:void(0)" : edit_mailer_template_path(email[:uid])
    link_class = email[:rollout] ? "eamil_preview_link cjs_email_rollout_link" : "eamil_preview_link"
    link_data_url = email[:rollout] ? rollout_popup_rollout_email_path(email[:uid], format: :js, :edit_page => false) : nil
    return link_txt, link_url, {class: "#{link_class} #{options[:additional_class]} btn btn-sm btn-primary", data: {url: link_data_url}}
  end

  def self.handle_space_quotes_in_mail_content(content)
    content.gsub(/\s+/, "").gsub(/\"/, "'")
  end

  def rollout_popup_dismiss_link(mailer_template, edit_page)
    if edit_page
      link_to_function get_icon_content("fa fa-times") + set_screen_reader_only_content("display_string.Close".translate), "closeQtip()", class: "close"
    else
      link_to get_icon_content("fa fa-times") + set_screen_reader_only_content("display_string.Close".translate), rollout_dismiss_popup_by_admin_rollout_email_path(mailer_template.uid), method: :post, class: "close"
    end
  end

  def sanitized_mail_content_for_rollout_popup(content)
    chronus_sanitize_while_render(content, :sanitization_version => ChronusSanitization::HelperMethods::SANITIZATION_VERSION_V1, :sanitization_options => {:attributes => %w[style _cke_saved_href accesskey align alt border cellpadding cellspacing charset colspan data-cke-realelement dir href id lang longdesc name onclick rel rowspan scope src start summary tabindex target title type], :tags => %w[address blockquote br caption div em h1 h2 h3 h4 h5 h6 img li ol p pre span strong table tbody td tfoot th thead tr u ul]})
  end

  def rollout_popup_keep_current_content_button_link(mailer_template, edit_page)
    if edit_page
      link_to "feature.email.content.keep_current_content".translate, "javascript:void(0)", {class: "btn btn-default cjs_keep_current_content_btn", data: {url: rollout_keep_current_content_rollout_email_path(mailer_template.uid), :disable_with => "display_string.Please_Wait".translate}}
    else
      link_to "feature.email.content.keep_current_content".translate, rollout_keep_current_content_rollout_email_path(mailer_template.uid), method: :post, :class => "btn btn-default", data: { :disable_with => "display_string.Please_Wait".translate }
    end
  end

  def rollout_html_for_old_and_new_content(old_content_html, new_content_html)
    content_tag(:div, class: "row") do
      content_tag(:div, class: "col-md-6") do
        old_content_html.html_safe
      end +
      content_tag(:div, class: "col-md-6") do
        new_content_html.html_safe
      end
    end
  end

  def rollout_popup_horizontal_divider
    rollout_html_for_old_and_new_content(content_tag(:hr), content_tag(:hr))
  end

  def content_last_updated_at_info(uid, program)
    return unless Mailer::Template.content_customized?(program, ChronusActionMailer::Base.get_descendant(uid))
    content_changer_member, updation_time = Mailer::Template.content_updater_and_updation_time(uid, program)
    content_changer = program.is_a?(Program) ? content_changer_member.user_in_program(program) : content_changer_member if content_changer_member.present?
    return get_icon_content("fa fa-clock-o") + content_tag(:em, "feature.email.content.content_updation_info_html".translate(updation_date: DateTime.localize(updation_time, format: :short), user_link: link_to_user(content_changer, :no_hovercard => true)), :class => "small") if content_changer.present? && updation_time.present?
  end

  def email_enabled_and_disabled_info(subcategory_mails_hash, program)
    subcategory_emails_uid = subcategory_mails_hash.collect{|mailer_attribute| mailer_attribute[:uid]}
    disabled_mailer_templates_count = program.mailer_templates.where(:uid => subcategory_emails_uid, :enabled => false).count
    disabled_mailer_templates_count += program.organization.mailer_templates.where(:uid => subcategory_emails_uid, :enabled => false).count if program.is_a?(Program) && program.organization.standalone?
    return content_tag(:span, "feature.email.content.subcategory_enabled_disabled_mails_count_html".translate(:enabled_count => subcategory_emails_uid.count - disabled_mailer_templates_count, :disabled_count => disabled_mailer_templates_count), :class => "small dim cjs_subtegory_enabled_disabled_info")
  end

  def invitation_mails_info_text(subcategory, program)
    return unless program.is_a?(Program)
    content = "".html_safe
    if subcategory == EmailCustomization::NewCategories::SubCategories::INVITATION
      content += content_tag(:div, :class => "small m-t-xs") do
        content_tag(:span, "feature.email.content.invitation_subcategory_description_html".translate(:invitation_emails_url => new_program_invitation_path, :admin => program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).term_downcase))
      end
    end
  end

  def render_empty_invitation_subcategory(program)
    subcategory = EmailCustomization::NewCategories::SubCategories::INVITATION
    ibox "#{EmailCustomization.get_translated_email_subcategory_name(EmailCustomization::NewCategories::SubCategories::NAMES[subcategory]).call(program)} #{email_enabled_and_disabled_info({}, program)} #{invitation_mails_info_text(subcategory, program)}", :ibox_id => "subcategory_#{subcategory}", :content_class => "no-padding" do
    end
  end

  def link_to_admin_adding_users
    link_to("display_string.click_here".translate, url_to_admin_adding_users, :target => "_blank")
  end

  def url_to_admin_adding_users(program_root = current_root)
    category_mails_mailer_templates_path(category: EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT, root: program_root, scroll_to: "subcategory_#{EmailCustomization::NewCategories::SubCategories::ADMIN_ADDING_USERS}")
  end

  def preview_mail_link_text(mailer_template, mentoring_model, options = {})
    preview_mail_path = if options[:facilitation_template_id].present?
                          preview_email_mentoring_model_facilitation_templates_path(mentoring_model)
                        else
                          preview_email_mailer_template_path(mailer_template.uid)
                        end

    preview_mail_link = link_to "display_string.Click_here".translate, preview_mail_path, :id => "cjs_preview_email_link"

    content = "feature.email.content.click_to_send_test_mail_v1_html".translate(Click_here: preview_mail_link)
    content += "feature.facilitation_message.content.preview_mail_help_text".translate if options[:facilitation_template_id].present?
    return content
  end

  def get_preview_email_js_options(facilitation_template_id = nil)
    if facilitation_template_id.present?
      form_selector = "#cjs_new_mentoring_model_facilitation_template_#{facilitation_template_id}"
      {
        subjectId: "#{form_selector} #mentoring_model_facilitation_template_subject",
        sourceId: "#{form_selector} #mentoring_model_facilitation_template_message",
        previewEmailSelector: "#preview_email_#{facilitation_template_id} .cjs_preview_email",
        facilitationTemplateId: facilitation_template_id,
        editorId: "mentoring_model_facilitation_template_message"
      }.to_json
    else
      {
        subjectId: "form #mailer_template_subject",
        sourceId: "form #mailer_template_source",
        previewEmailSelector: "#edit_email form .cjs_preview_email"
      }.to_json
    end

  end
end
