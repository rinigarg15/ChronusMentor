require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/mailer_templates_helper"


class MailerTemplatesHelperTest < ActionView::TestCase

  def test_email_edit_link_params
    params_1 = email_edit_link_params(true, {uid: '1234', rollout: true})
    assert_equal ['Customize', "javascript:void(0)", {class: 'eamil_preview_link cjs_email_rollout_link  btn btn-sm btn-primary', data: {url: rollout_popup_rollout_email_path('1234', format: :js, :edit_page => false)}}], params_1

    params_2 = email_edit_link_params(false, {uid: '1234', rollout: false})
    assert_equal ['Preview', edit_mailer_template_path('1234'), {class: 'eamil_preview_link  btn btn-sm btn-primary', data: {url: nil}}], params_2
  end

  def test_rollout_popup_dismiss_link
    program = programs(:albers)
    uid = ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]
    mailer_template = program.mailer_templates.where(:uid => uid).first

    assert_equal link_to_function(get_icon_content("fa fa-times") + set_screen_reader_only_content("display_string.Close".translate), "closeQtip()", class: "close"), rollout_popup_dismiss_link(mailer_template, true)
    assert_equal link_to(get_icon_content("fa fa-times") + set_screen_reader_only_content("display_string.Close".translate), rollout_dismiss_popup_by_admin_rollout_email_path(uid), method: :post, class: "close"), rollout_popup_dismiss_link(mailer_template, false)
  end

  def test_rollout_popup_keep_current_content_button_link
    program = programs(:albers)
    uid = ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]
    mailer_template = program.mailer_templates.where(:uid => uid).first

    assert_equal link_to('Keep current content', "javascript:void(0)", {class: "btn btn-default cjs_keep_current_content_btn", data: {url: rollout_keep_current_content_rollout_email_path(uid), :disable_with => "display_string.Please_Wait".translate}}), rollout_popup_keep_current_content_button_link(mailer_template, true)
    assert_equal link_to("Keep current content", rollout_keep_current_content_rollout_email_path(uid), method: :post, :class => "btn btn-default", data: { :disable_with => "display_string.Please_Wait".translate }), rollout_popup_keep_current_content_button_link(mailer_template, false)
  end

  def test_sanitized_mail_content_for_rollout_popup
    program = programs(:albers)
    mailer_template = program.mailer_templates.where(:uid => ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]).first

    assert_equal "Hello,<br>\n<br>\nI would like to invite you to join the {{subprogram_or_program_name}} {{as_role_name_articleized}}.<br>\n<br>\nClick here to accept the invitation and sign up for {{subprogram_or_program_name}}. Once you do that, you can fill out your profile (which we use to match you up with other participants with similar interests and goals) and participate in the program activities.<br>\n<br>\nI look forward to your participation! If you have any questions, please contact me here.", sanitized_mail_content_for_rollout_popup(mailer_template.source)
    assert_not_equal mailer_template.source, sanitized_mail_content_for_rollout_popup(mailer_template.source)
  end

  def test_rollout_html_for_old_and_new_content
    old_content_html = "<b>Old Content</b>"
    new_content_html = "<b>New Content</b>"
    assert_equal "<div class=\"row\"><div class=\"col-md-6\"><b>Old Content</b></div><div class=\"col-md-6\"><b>New Content</b></div></div>", rollout_html_for_old_and_new_content(old_content_html, new_content_html)
  end

  def test_rollout_popup_horizontal_divider
    assert_equal "<div class=\"row\"><div class=\"col-md-6\"><hr></hr></div><div class=\"col-md-6\"><hr></hr></div></div>", rollout_popup_horizontal_divider
  end

  def test_handle_space_quotes_in_mail_content
    content = "Hello,<br />\n\t<br />\nI would like to invite you to\r join the&nbsp; <a href=\"{{subprogram_or_program_name}}\">{{as_role_name_articleized}}</a>.<br />"
    assert_equal MailerTemplatesHelper.handle_space_quotes_in_mail_content(content), "Hello,<br/><br/>Iwouldliketoinviteyoutojointhe&nbsp;<ahref='{{subprogram_or_program_name}}'>{{as_role_name_articleized}}</a>.<br/>"
  end

  def test_update_all_alert_for_rollout
    assert_select_helper_function_block "table[class=\"no-border no-margin\"]", update_all_alert_for_rollout do
      assert_select "tr" do
        assert_select "td" do
          assert_select "span", text: "A new content update is now available! This update includes new and improved subject lines and content for your emails. On the right, you can choose to update all emails or only those you have not customized. Alternatively, view each email individually to preview the changes and update them one at a time. We recommend updating all emails at once for the best results."
        end
        assert_select "td" do
          assert_select "a[class=\"btn btn-primary has-before-1 cui-rollout-flash-button\"][data-confirm=\"This will update all your emails, and overwrite existing content. Proceed?\"][data-disable-with=\"Please Wait...\"][data-method=\"patch\"][href=\"/rollout_emails/update_all\"][id=\"rollout_update_all_help_text\"][rel=\"nofollow\"]", text: "Update all emails"
          assert_select "script", text: "\n//<![CDATA[\njQuery(\"#rollout_update_all_help_text\").tooltip({html: true, title: '<div>Updates all your program emails to the new content.</div>', placement: \"top\", container: \"#rollout_update_all_help_text\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\"#rollout_update_all_help_text\").on(\"remove\", function () {jQuery(\"#rollout_update_all_help_text .tooltip\").hide().remove();})\n//]]>\n"
        end
        assert_select "td" do
          assert_select "a[class=\"btn btn-primary has-before-1 cui-rollout-flash-button\"][data-confirm=\"Any emails you have not customized will be updated to the new content. Emails you edited will not be touched. Proceed?\"][data-disable-with=\"Please Wait...\"][data-method=\"patch\"][href=\"/rollout_emails/update_all?non_customized=true\"][id=\"update_non_customized_help_text\"][rel=\"nofollow\"]", text: "Update non-customized emails"
          assert_select "script", text: "\n//<![CDATA[\njQuery(\"#update_non_customized_help_text\").tooltip({html: true, title: '<div>Updates only emails you have not made edits to. Edited emails stay unchanged.</div>', placement: \"top\", container: \"#update_non_customized_help_text\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\"#update_non_customized_help_text\").on(\"remove\", function () {jQuery(\"#update_non_customized_help_text .tooltip\").hide().remove();})\n//]]>\n"
        end
      end
    end
  end

  def test_content_last_updated_at_info
    mt = Mailer::Template.non_campaign_mails.first
    mt.content_changer_member = mt.program.users.first.member
    mt.content_updated_at = Time.now
    mt.save!

    assert_false Mailer::Template.content_customized?(mt.program, ChronusActionMailer::Base.get_descendant(mt.uid))
    assert_nil content_last_updated_at_info(mt.uid, mt.program)

    mt.source = "new source"
    mt.save!

    assert Mailer::Template.content_customized?(mt.program, ChronusActionMailer::Base.get_descendant(mt.uid))

    assert_equal "<i class=\"fa fa-clock-o fa-fw m-r-xs\"></i><em class=\"small\">Updated last on #{DateTime.localize(mt.content_updated_at, format: :short)} by #{link_to_user(mt.content_changer_member.user_in_program(mt.program), :no_hovercard => true)}.</em>", content_last_updated_at_info(mt.uid, mt.program)

    mt.program = mt.program.organization
    mt.save!

    assert_equal "<i class=\"fa fa-clock-o fa-fw m-r-xs\"></i><em class=\"small\">Updated last on #{DateTime.localize(mt.content_updated_at, format: :short)} by #{link_to_user(mt.content_changer_member, :no_hovercard => true)}.</em>", content_last_updated_at_info(mt.uid, mt.program)
  end

  def test_email_enabled_and_disabled_info
    program = programs(:albers)
    enabled_mailer_templates_uid = Mailer::Template.where(:enabled => true, :program_id => program.id).first(2).collect(&:uid)
    disabled_mailer_templates_uid = Mailer::Template.where(:enabled => false, :program_id => program.id).first(2).collect(&:uid)

    emails = ChronusActionMailer::Base.get_descendants.select{|e| (enabled_mailer_templates_uid+disabled_mailer_templates_uid).include?(e.mailer_attributes[:uid])}
    emails_hash = emails.collect{|e| e.mailer_attributes.dup }

    assert_equal "<span class=\"small dim cjs_subtegory_enabled_disabled_info\">(<span class='cjs_enabled_count'>0</span> enabled, <span class='cjs_disabled_count'>2</span> disabled)</span>", email_enabled_and_disabled_info(emails_hash, program)

    # for standalone organization
    organization = program.organization
    program.mailer_templates.create!(:uid => DemotionNotification.mailer_attributes[:uid], :enabled => false)
    organization.mailer_templates.create!(:uid => MemberActivationNotification.mailer_attributes[:uid], :enabled => true)
    emails_hash = [DemotionNotification, MemberActivationNotification].collect{|e| e.mailer_attributes.dup }

    Organization.any_instance.stubs(:standalone?).returns(true)

    assert_equal "<span class=\"small dim cjs_subtegory_enabled_disabled_info\">(<span class='cjs_enabled_count'>1</span> enabled, <span class='cjs_disabled_count'>1</span> disabled)</span>", email_enabled_and_disabled_info(emails_hash, program)
  end

  def test_invitation_mails_info_text
    subcategory = EmailCustomization::NewCategories::SubCategories::INVITATION
    
    assert_nil invitation_mails_info_text(subcategory, programs(:org_primary))

    assert_equal "<div class=\"small m-t-xs\"><span>Emails which are sent out when an administrator sends out the invitations to the users are listed <a href='/program_invitations/new'>here</a>.</span></div>", invitation_mails_info_text(subcategory, programs(:albers))
  end

  def test_render_empty_invitation_subcategory
    program = programs(:albers)
    subcategory = EmailCustomization::NewCategories::SubCategories::INVITATION
    
    expected_output = ibox "#{EmailCustomization.get_translated_email_subcategory_name(EmailCustomization::NewCategories::SubCategories::NAMES[subcategory]).call(program)} #{email_enabled_and_disabled_info({}, program)} #{invitation_mails_info_text(subcategory, program)}", :ibox_id => "subcategory_#{subcategory}", :content_class => "no-padding" do
    end

    assert_equal expected_output, render_empty_invitation_subcategory(program)
  end

  
  def test_is_mail_feature_dependent
    program = programs(:albers)
    calendar_sync_dependant_emails_uids =  FeatureName.dependent_emails[FeatureName::CALENDAR_SYNC][:enabled].collect{|mailer|mailer.mailer_attributes[:uid]}
    program.enable_feature(FeatureName::CALENDAR_SYNC, true)
    calendar_sync_dependant_emails_uids.each do |uid|
      assert is_mail_feature_dependent?(uid, program)
    end
    programs(:albers).enable_feature(FeatureName::CALENDAR_SYNC, false)
    assert_false program.calendar_sync_enabled?
    calendar_sync_dependant_emails_uids.each do |uid|
      assert_false is_mail_feature_dependent?(uid, program)
    end
  end

  def test_disable_status_change
    program = programs(:albers)
    always_enabled_emails = [AnnouncementNotification, AnnouncementUpdateNotification, CompleteSignupExistingMemberNotification, CompleteSignupNewMemberNotification, ForgotPassword, ProgramInvitationCampaignEmailNotification]
    always_enabled_emails.collect{|mailer|mailer.mailer_attributes[:uid]}.each do |uid|
      assert disable_status_change?(uid, program)
    end
    uid = "random_id"
    self.stubs(:is_mail_feature_dependent?).returns(false)
    assert_false disable_status_change?(uid, program)
    self.stubs(:is_mail_feature_dependent?).returns(true)
    assert disable_status_change?(uid, program)
  end

  def test_preview_mail_link_text
    mailer_template = mailer_templates(:mailer_templates_3)
    assert_equal "<a id=\"cjs_preview_email_link\" href=\"/mailer_templates/#{mailer_template.uid}/preview_email\">Click here</a> to send a test email.", preview_mail_link_text(mailer_template, nil)
    mentoring_model = mentoring_models(:mentoring_models_1)
    assert_equal "<a id=\"cjs_preview_email_link\" href=\"/mentoring_models/#{mentoring_model.id}/facilitation_templates/preview_email\">Click here</a> to send a test email. The salutation and signature will be appended to the body before sending the email.", preview_mail_link_text(nil, mentoring_model, facilitation_template_id: "new")
  end

  private

  def _program
    "program"
  end
end
