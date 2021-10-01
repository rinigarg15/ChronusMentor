# encoding: utf-8

require_relative './../../test_helper.rb'

class UserMailerHelperTest < ActionView::TestCase
  def test_html_line_break
    assert_equal '<br/>', html_line_break
  end

  def test_notification_settings_link
    @user = users(:f_student)
    @organization = programs(:org_primary)
    notification_link = notification_settings_link
    assert_match account_settings_url(:subdomain => @organization.subdomain), notification_link

    @user = users(:f_student)
    @program = programs(:albers)
    @organization = programs(:org_primary)
    notification_link = notification_settings_link
    assert_match /.*Click here.* to modify your notification settings.*/, notification_link
    assert_match edit_member_url(@user.member, section: MembersController::EditSection::SETTINGS, subdomain: @organization.subdomain, root: @program.root, focus_notification_tab: true, scroll_to: NOTIFICATION_SECTION_HTML_ID).gsub("&", "&amp;"), notification_link

    @group = groups(:mygroup)
    @show_mentoring_area_notif_setting = true
    notification_link = notification_settings_link
    assert_match /.*Click here.* to modify your notification settings.*/, notification_link
  end

  def test_contact_admin_link
    @organization = programs(:org_primary)
    @program = programs(:albers)
    setup_admin_custom_term

    assert_select_helper_function_block "span", contact_admin_link, text: "Contact Super Admin for any questions." do
      assert_select "a", text: "Contact Super Admin"
    end
  end

  def test_strip_html_comments
    message = "<div class = 'email_content'><p>This is a <b>sample</b> text<!-- this is an html - comment -->.</div>".html_safe
    @program = programs(:albers)
    @organization = programs(:org_primary)
    template = email_template() do
      message
    end
    assert_match "<div class = 'email_content'><p>This is a <b>sample</b> text.</div>", template
    assert_no_match /Chronus Mentor/, template
    assert_no_match /this is an html.*comment/, template
  end

  def test_template_methods
    @program = programs(:albers)
    @organization = programs(:org_primary)
    assert_nil @is_reply_enabled

    assert_select_helper_function "span", do_not_reply, text: "This is an automated email - please don't reply."
    assert_select_helper_function_block "a[target='_blank']", email_footer_logo do
      assert_select "img", alt: "Logo", width: "90", style: "display: block; font-family: Helvetica, Arial, sans-serif; color: #666666; font-size: 14px;", border: "0", src: "https://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/Powered_By_Chronus.png"
    end
  end

  def test_email_footer_logo_with_white_labelling_enabled
    @program = programs(:albers)
    @organization = programs(:org_primary)
    @organization.white_label = true
    @organization.save!
    assert_nil email_footer_logo
  end

  def test_download_mobile_apps_info
    assert_nil download_mobile_apps_info

    @organization = programs(:org_primary)
    @organization.enable_feature(FeatureName::MOBILE_VIEW, false)
    assert_false @organization.mobile_view_enabled?
    assert_nil download_mobile_apps_info

    @organization.enable_feature(FeatureName::MOBILE_VIEW, true)
    assert_match link_to(image_tag(APP_CONFIG[:android_app_google_play_icon]), android_app_store_link(@organization, CordovaHelper::AndroidAppStoreSource::EMAIL), :style => "padding-right:5px;", :target => "_blank"), download_mobile_apps_info
    assert_match link_to(image_tag(APP_CONFIG[:ios_app_store_icon]), APP_CONFIG[:ios_chronus_app_store_link], :target => "_blank"), download_mobile_apps_info
  end

  def test_notification_email_to_member_group_member_links
    @program = programs(:albers)
    @organization = programs(:org_primary)
    set_host_name_for_urls(@organization, @program)
    members = [users(:mentor_2), users(:mentor_3), users(:mentor_4)]

    text = group_member_links(members)
    expected_text = "you, #{link_to(users(:mentor_2).name, member_url(members(:mentor_2), :subdomain => 'primary'))}, " +
        "#{link_to(users(:mentor_3).name, member_url(members(:mentor_3), :subdomain => 'primary'))} and" +
        " #{link_to(users(:mentor_4).name, member_url(members(:mentor_4), :subdomain => 'primary'))}"
    assert_equal expected_text, text

    text2 = group_member_links(members, false)
    expected_text2 = "#{link_to(users(:mentor_2).name, member_url(members(:mentor_2), :subdomain => 'primary'))}, " +
        "#{link_to(users(:mentor_3).name, member_url(members(:mentor_3), :subdomain => 'primary'))} and" +
        " #{link_to(users(:mentor_4).name, member_url(members(:mentor_4), :subdomain => 'primary'))}"
    assert_equal expected_text2, text2
  end

  def test_group_members_list_by_role
    @program = programs(:albers)
    @organization = programs(:org_primary)
    members_by_role_hash = {"Mentors" => [users(:f_mentor)], "Mentees" => [users(:f_student)]}

    set_response_text group_members_list_by_role(members_by_role_hash, false)
    assert_select "table" do
      assert_select "tr" do
        assert_select "td", :text => "Mentors:"
        assert_select "td", :text => "Good unique name"
      end
      assert_select "tr" do
        assert_select "td", :text => "Mentees:"
        assert_select "td", :text => "student example"
      end
    end
  end

  def test_raise_if_erb
    content = "sample"
    assert_nothing_raised do
      raise_if_erb(content)
    end

    content = "%sample"
    assert_nothing_raised do
      raise_if_erb(content)
    end

    content = "<%=sample"
    e = assert_raise RuntimeError do
      raise_if_erb(content)
    end
    assert_equal "+ erb tags in mailer views +", e.message

    content = "<%sample"
    e = assert_raise RuntimeError do
      raise_if_erb(content)
    end
    assert_equal "+ erb tags in mailer views +", e.message
  end

  def test_links_at_bottom
    current_user_is :f_mentor
    time = 2.days.from_now
    @user = users(:f_mentor)
    @organization = @user.member.organization
    setup_admin_custom_term
    @program = @user.program
    @internal_attributes = {}
    mentor_secret = members(:f_mentor).calendar_api_key

    assert_select_helper_function_block "span", links_at_bottom, text: "Contact Super Admin for any questions." do
      assert_select "a", href: "http://primary.#{DEFAULT_HOST_NAME}/p/albers/contact_admin?src=email"
    end
  end

  def test_get_hidden_text
    message = "<div class = 'email_content'><p>This is a <b>sample</b> text<!-- this is an html - comment --> https://chronus.com .</div>".html_safe
    assert_match "This is a sample text  .", get_hidden_text(message)
  end

  def test_program_logo
    @program = programs(:albers)
    @organization = @program.organization

    program_asset = @program.create_program_asset
    program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program_asset.save!
    organization_asset = @organization.create_program_asset
    organization_asset.logo = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    organization_asset.save!

    image_options = {
      id: 'program-logo-or-banner',
      height: "75",
      alt: "emails.default_content.program_logo".translate(program: @organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term.to_s.force_encoding('UTF-8')),
      align: 'left',
      hspace: '10',
      style: 'max-width: 90% !important;'
    }
    program_logo_code = image_tag(ImportExportUtils.file_url(@program.logo_url), image_options)
    org_logo_code = image_tag(ImportExportUtils.file_url(@organization.logo_url), image_options)

    @level = EmailCustomization::Level::PROGRAM
    assert_equal program_logo, link_to(program_logo_code, program_root_url(subdomain: @organization.subdomain, root: @program.root)).html_safe

    @program = nil
    assert_equal program_logo, link_to(org_logo_code, root_organization_url(subdomain: @organization.subdomain)).html_safe

    @program = programs(:albers)
    @level = EmailCustomization::Level::ORGANIZATION
    assert_equal program_logo, link_to(org_logo_code, root_organization_url(subdomain: @organization.subdomain)).html_safe
  end

  def test_get_logo_height
    file_path =  Rails.root.to_s + "/test/fixtures/files/test_pic.png"
    o = Paperclip::Geometry.stubs(:from_file).returns(Paperclip::Geometry.new)
    o.stubs(:resize_to).returns(Paperclip::Geometry.new)
    Paperclip::Geometry.any_instance.expects(:height).returns(48.0).at_least(1)
    assert_equal "50", get_logo_height(file_path)

    Paperclip::Geometry.any_instance.expects(:height).returns(950.0).at_least(1)
    assert_equal "75", get_logo_height(file_path)

    Paperclip::Geometry.any_instance.expects(:height).returns(75.0).at_least(1)
    assert_equal "75", get_logo_height(file_path)

    Paperclip::Geometry.any_instance.expects(:height).returns(50.0).at_least(1)
    assert_equal "50", get_logo_height(file_path)

    Paperclip::Geometry.any_instance.expects(:height).returns(62.0).at_least(1)
    assert_equal "62", get_logo_height(file_path)

    Paperclip::Geometry.any_instance.expects(:height).returns(0).at_least(1)
    assert_equal "50", get_logo_height(file_path)
  end

  def test_connection_membership_pending_notification_text
    pending_notification = PendingNotification.new
    pending_notification.action_type = RecentActivityConstants::Type::USER_SUSPENSION
    pending_notification.ref_obj = users(:f_mentor)
    assert_equal "Good unique name has been suspended", connection_membership_pending_notification_text(pending_notification)
    pending_notification.action_type = RecentActivityConstants::Type::GROUP_MEMBER_LEAVING
    assert_equal "Good unique name has left", connection_membership_pending_notification_text(pending_notification)
    pending_notification.action_type = RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
    assert_equal "Members have been updated", connection_membership_pending_notification_text(pending_notification)
    pending_notification.action_type = RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE
    pending_notification.ref_obj = groups(:mygroup)
    assert_equal "Expiry date changed to #{DateTime.localize(groups(:mygroup).expiry_time.in_time_zone("Asia/Kolkata"), format: :abbr_short)}", connection_membership_pending_notification_text(pending_notification, {user_time_zone: "Asia/Kolkata"})
    pending_notification.action_type = RecentActivityConstants::Type::TOPIC_CREATION
    topic = create_topic
    pending_notification.ref_obj = topic
    assert_equal "'Title' was discussed", connection_membership_pending_notification_text(pending_notification)
    pending_notification.action_type = RecentActivityConstants::Type::POST_CREATION
    post = create_post(topic: topic)
    pending_notification.ref_obj = post
    assert_equal "'Title' was discussed", connection_membership_pending_notification_text(pending_notification)
    pending_notification.action_type = RecentActivityConstants::Type::MENTORING_MODEL_TASK_CREATION
    mentoring_model_task = MentoringModel::Task.new(title: 'task title')
    pending_notification.ref_obj = mentoring_model_task
    assert_equal "Task 'task title' was added", connection_membership_pending_notification_text(pending_notification)
  end

  def test_digest_v2_url_for_connection_update
    pending_notification = PendingNotification.new
    url_options = {a: 1}
    group = groups(:mygroup)
    forum = create_forum(group_id: group.id)
    group.reload.forum
    pending_notification.action_type = RecentActivityConstants::Type::TOPIC_CREATION
    assert_match /forums\/#{forum.id}\?a=1/, digest_v2_url_for_connection_update(pending_notification, group, url_options)
    pending_notification.action_type = RecentActivityConstants::Type::POST_CREATION
    assert_match /forums\/#{forum.id}\?a=1/, digest_v2_url_for_connection_update(pending_notification, group, url_options)
    pending_notification.action_type = "anything_else"
    assert_match /groups\/1\?a=1\&show_plan=true/, digest_v2_url_for_connection_update(pending_notification, group, url_options)
  end

  def test_digest_v2_group_end_date_not_shown_in_pending_group
    group = groups(:group_pbe_0)
    forum = group.forum
    mentor = group.mentors.first
    student = group.students.first
    group.reload.forum
    create_topic(forum: forum, user: student, title: "Pending Group")
    mentor.last_group_update_sent_time = mentor.last_group_update_sent_time - 9.days
    mentor.save!
    DigestV2Utils::Trigger.new.send "send_digest_v2_for_user", mentor.id, {}
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)

    assert_select_helper_function "span", email_content, count: 1, text: "'Pending Group' was discussed"
    assert_select_helper_function "span", email_content, count: 0, text: /Ends on/
    assert_match /Click here.*? to modify your notification settings/, email_content
  end

  def test_digest_v2_group_end_date_shown_in_active_group
    group = groups(:group_pbe)
    forum = group.forum
    mentor = group.mentors.first
    student = group.students.first
    group.reload.forum
    create_topic(forum: forum, user: student, title: "Pending Group")
    mentor.last_group_update_sent_time = mentor.last_group_update_sent_time - 9.days
    mentor.save!

    DigestV2Utils::Trigger.new.send "send_digest_v2_for_user", mentor.id, {}
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_select_helper_function "span", email_content, count: 1, text: "'Pending Group' was discussed"
    assert_select_helper_function "span", email_content, count: 1, text: /Ends on/
  end

  def test_set_level_object
    @level = EmailCustomization::Level::PROGRAM
    @program = programs(:albers)
    @organization = programs(:org_primary)

    set_level_object
    assert_equal @level_object, @program

    @program = nil
    set_level_object
    assert_equal @level_object, @organization

    @level = EmailCustomization::Level::ORGANIZATION

    set_level_object
    assert_equal @level_object, @organization
  end

  def test_get_sender_name
    @user = users(:f_admin)

    sender_name = get_sender_name(@user)
    assert_equal sender_name, @user.name

    @user = users(:f_student)
    sender_name = get_sender_name(@user)
    assert_equal sender_name, @user.name

    @user.member.email = SUPERADMIN_EMAIL
    sender_name = get_sender_name(@user)
    assert_equal sender_name, @user.name(name_only: true)
  end

  private

  def prepare_plain_text(string)
    string = string.html_safe
    string_within_wrapper = "<div class = 'email_content'>" + string + "</div>"
    html_to_plain_text(string_within_wrapper.html_safe)
  end
end