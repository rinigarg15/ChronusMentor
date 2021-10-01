require_relative './../../test_helper.rb'
require_relative './../../../app/helpers/application_helper'

class MemberMailerTest < ActionMailer::TestCase

  def setup
    super
    helper_setup
    chronus_s3_utils_stub
  end

  include Rails.application.routes.url_helpers

  def default_url_options
    ActionMailer::Base.default_url_options
  end

  def test_inbox_message_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    to_member = members(:f_mentor)
    from_member = members(:f_student)
    attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    message = create_message(:sender => from_member , :receiver => to_member, :attachment => attachment)
    message_receiver = message.message_receivers[0]
    organization = message.organization

    # Create the notification email
    @email = ChronusMailer.inbox_message_notification(to_member, message, sender: message.sender).deliver_now

    # Test the email
    assert_equal "#{message.subject}", @email.subject
    assert_equal [message.sender.email], @email.cc
    assert_equal "#{from_member.name} <#{MAILER_ACCOUNT[:email_address]}>", @email['from'].to_s
    assert_equal "#{from_member.name} <#{MAILER_ACCOUNT[:email_address]}>", @email['sender'].to_s
    assert_match /You have a/, get_html_part_from(@email)
    assert_match message.content, get_html_part_from(@email)
    assert_match(/is_inbox=true/, get_html_part_from(@email))
    assert_match /mailto:reply-/, get_html_part_from(@email)
    assert_match("login and reply to this message", get_html_part_from(@email))
    assert_match MAILER_ACCOUNT[:reply_to_address].call(message_receiver.api_token, ReplyViaEmail::MESSAGE), @email.reply_to[0]
    assert_equal(1, @email.attachments.size)
    assert_match(message.attachment_file_name, @email.attachments.first.filename)
    assert_match(/text\/plain/, @email.attachments.first.content_type)
    assert_no_match(/This is an automated email/, get_html_part_from(@email))
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(@email))
    assert_match(/To respond to/, get_html_part_from(@email))
  end

  def test_inbox_message_notification_wrt_to_locale
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    to_member = members(:f_mentor)
    from_member = members(:f_student)
    attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    message = create_message(:sender => from_member , :receiver => to_member, :attachment => attachment)
    message_receiver = message.message_receivers[0]
    organization = message.organization

    # Create the notification email
    @email = ChronusMailer.inbox_message_notification(to_member, message, sender: message.sender).deliver_now

    # Test the email
    assert_equal "#{message.subject}", @email.subject
    assert_equal [message.sender.email], @email.cc
    assert_equal "#{from_member.name} <#{MAILER_ACCOUNT[:email_address]}>", @email['from'].to_s
    assert_equal "#{from_member.name} <#{MAILER_ACCOUNT[:email_address]}>", @email['sender'].to_s
    assert_match /You have a/, get_html_part_from(@email)
    assert_match message.content, get_html_part_from(@email)
    assert_match(/is_inbox=true/, get_html_part_from(@email))
    assert_match /mailto:reply-/, get_html_part_from(@email)
    assert_match("login and reply to this message", get_html_part_from(@email))
    assert_match MAILER_ACCOUNT[:reply_to_address].call(message_receiver.api_token, ReplyViaEmail::MESSAGE), @email.reply_to[0]
    assert_equal(1, @email.attachments.size)
    assert_match(message.attachment_file_name, @email.attachments.first.filename)
    assert_match(/text\/plain/, @email.attachments.first.content_type)
    assert_no_match(/This is an automated email/, get_html_part_from(@email))
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(@email))
    assert_match(/To respond to/, get_html_part_from(@email))
  end

  def test_inbox_message_notification_should_not_have_notif_link
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    to_member = members(:f_mentor)
    from_member = members(:f_student)
    message = create_message(:sender => from_member , :receiver => to_member)
    organization = to_member.organization
    email = ChronusMailer.inbox_message_notification(to_member, message, sender: message.sender).deliver_now
    assert_equal [message.sender.email], email.cc
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(email))
    assert_equal [message.get_sender.email], email.cc
  end

  def test_new_scrap_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    to_member = members(:f_mentor)
    from_member = members(:mkr_student)
    group = groups(:mygroup)
    attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    scrap = create_scrap(:group => group, :sender => from_member, :attachment => attachment, :program => group.program)
    scrap_receiver = scrap.message_receivers[0]
    organization = to_member.organization
    # Create the notification email
    @email = ChronusMailer.inbox_message_notification(to_member, scrap, sender: scrap.sender).deliver_now

    # Test the email
    assert_equal [scrap.sender.email], @email.cc
    assert_equal "#{scrap.subject}", @email.subject
    assert_equal "#{from_member.name} <#{MAILER_ACCOUNT[:email_address]}>", @email['from'].to_s
    assert_equal "#{from_member.name} <#{MAILER_ACCOUNT[:email_address]}>", @email['sender'].to_s
    assert_match scrap.content, get_html_part_from(@email)
    assert_no_match(/is_inbox=true/, get_html_part_from(@email))
    assert_match group_url(group, :subdomain => organization.subdomain, :root => group.program.root), get_html_part_from(@email)
    assert_match MAILER_ACCOUNT[:reply_to_address].call(scrap_receiver.api_token, ReplyViaEmail::MESSAGE), @email.reply_to[0]
    assert_equal(1, @email.attachments.size)
    assert_match(scrap.attachment_file_name, @email.attachments.first.filename)
    assert_match(/text\/plain/, @email.attachments.first.content_type)
    assert_no_match(/This is an automated email/, get_html_part_from(@email))
    assert_match(/To respond to/, get_html_part_from(@email))
  end

  def test_inbox_message_notification_for_reply_to_admin
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    msg = messages(:first_admin_message)
    message = msg.build_reply(members(:f_admin))
    message.content = "Hi"
    message.sender = members(:f_admin)
    message.attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    message.save!

    ChronusMailer.inbox_message_notification(members(:f_admin), message, sender: message.sender).deliver_now
    email = ActionMailer::Base.deliveries.last

    # Verify email contents
    assert email.to[0].include?(users(:f_admin).email)
    assert_equal [message.sender.email], email.cc
    assert_equal "\"#{message.sender.name}\" <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "\"#{message.sender.name}\" <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal("#{message.subject}", email.subject)
    assert_match(/You have a .*message.* from/, get_text_part_from(email))
    assert_match(/#{message.content}/, get_text_part_from(email))
    assert_match(/just reply to this email/, get_text_part_from(email))
    assert_match(/is_inbox=true/, get_html_part_from(email))
    assert_match(/reply=true/, get_html_part_from(email))
    assert_match(/To respond to/, get_html_part_from(email))
    assert_equal(1, email.attachments.size)
    assert_match(message.attachment_file_name, email.attachments.first.filename)
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(email))
    assert_match(/text\/plain/, email.attachments.first.content_type)

    # Sender name is not visible
    message.sender.expects(:visible_to?).returns(false).at_least(1)
    ChronusMailer.inbox_message_notification(members(:f_admin), message, sender: message.sender).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [message.sender.email], mail.cc
    assert_equal "#{programs(:org_primary).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{programs(:org_primary).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_inbox_message_notification_with_no_change_notif_link_for_reply_to_admin
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    msg = messages(:first_admin_message)
    message = msg.build_reply(members(:f_admin))
    message.content = "Hi"
    message.sender = members(:f_admin)

    message.attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    message.save!
    organization = members(:f_admin).organization

    ChronusMailer.inbox_message_notification(members(:f_admin), message, sender: message.sender).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [message.sender.email], email.cc
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(email))
  end

  def test_auto_email_notification
    p = programs(:albers)
    user = users(:f_mentor)
    group = user.groups.first
    f_template = create_mentoring_model_facilitation_template

    message = nil
    assert_difference "AdminMessage.count" do
      message = AdminMessage.create_for_facilitation_message(f_template, user, members(:f_admin), group)
    end
    email = ActionMailer::Base.deliveries.last

    # Verify email contents
    assert email.to[0].include?(users(:f_mentor).email)
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal("#{message.subject} - #{group.name}", email.subject)
    assert_no_match(/You have a .*message.* from/, get_text_part_from(email))
    assert_match(/#{message.content}/, get_text_part_from(email))
    assert_match(/click here/, get_text_part_from(email))
    assert_match(/To contact the administrator, reply to this e-mail/, get_html_part_from(email))
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(email))
  end

  def test_auto_email_notification_without_group_name
    p = programs(:albers)
    user = users(:f_student)
    group = groups(:mygroup)
    f_template = create_mentoring_model_facilitation_template

    message = nil
    assert_difference "AdminMessage.count" do
      message = AdminMessage.create_for_facilitation_message(f_template, user, members(:f_admin), group)
    end
    email = ActionMailer::Base.deliveries.last

    # Verify email contents

    assert email.to[0].include?(users(:f_student).email)
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal("#{message.subject} - name & madankumarrajan", email.subject)
    assert_no_match(/You have a .*message.* from/, get_text_part_from(email))
    assert_match(/#{message.content}/, get_text_part_from(email))
    assert_match(/click here/, get_text_part_from(email))
    assert_match(/To contact the administrator, reply to this e-mail/, get_html_part_from(email))
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(email))
  end

  def test_mail_sent_wrt_member_locale
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    to_member = members(:f_mentor)
    message = messages(:first_message)
    current_locale = I18n.locale

    Language.set_for_member(to_member, I18n.default_locale)
    mailer = ChronusMailer.inbox_message_notification(to_member, message, sender: message.sender)
    assert_equal I18n.default_locale, mailer.instance_variable_get(:@mail_locale)
    assert_equal current_locale, I18n.locale

    Language.first.update_column(:language_name, "de")
    Language.set_for_member(to_member, :de)
    mailer = ChronusMailer.inbox_message_notification(to_member, message, sender: message.sender)
    assert_equal :de, mailer.instance_variable_get(:@mail_locale)
    assert_equal current_locale, I18n.locale
  end

  def test_inbox_message_notification_with_custom_erb
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    email_template = programs(:org_primary).mailer_templates.create!(:uid => InboxMessageNotification.mailer_attributes[:uid])
    custom_erb = %Q[has sent you a secret message]
    email_template.update_attribute(:source, custom_erb)

    to_member = members(:f_mentor)
    from_member = members(:f_student)
    message = create_message(sender: from_member, receiver: to_member)
    organization = message.organization
    # Create the notification email
    @email = ChronusMailer.inbox_message_notification(to_member, message, sender: message.sender).deliver_now

    # Test the email
    assert_equal "#{message.subject}", @email.subject
    assert_equal [message.sender.email], @email.cc
    assert_match /has sent you a secret message/, get_html_part_from(@email)
    assert_no_match(/This is an automated email/, get_html_part_from(@email))
  end

  def test_new_scrap_reply_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    group = groups(:mygroup)
    scrap = create_scrap(
      group: group,
      parent_id: messages(:mygroup_mentor_1),
      attachment: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    )
    to_member = scrap.receivers[0]
    scrap_receiver = scrap.message_receivers[0]
    organization = to_member.organization

    # Create the notification email
    @email = ChronusMailer.inbox_message_notification(to_member, scrap, sender: scrap.sender).deliver_now

    # Test the email
    assert_equal [scrap.sender.email], @email.cc
    assert_equal "#{scrap.subject}", @email.subject
    assert_equal "#{scrap.sender_user.name} <#{MAILER_ACCOUNT[:email_address]}>", @email['from'].to_s
    assert_equal "#{scrap.sender_user.name} <#{MAILER_ACCOUNT[:email_address]}>", @email['sender'].to_s
    assert_match scrap.content, get_html_part_from(@email)
    assert_no_match(/is_inbox=true/, get_html_part_from(@email))
    assert_match group_url(group, :subdomain => organization.subdomain, :root => group.program.root), get_html_part_from(@email)
    assert_match MAILER_ACCOUNT[:reply_to_address].call(scrap_receiver.api_token, ReplyViaEmail::MESSAGE), @email.reply_to[0]
    assert_equal(1, @email.attachments.size)
    assert_match(scrap.attachment_file_name, @email.attachments.first.filename)
    assert_match(/image\/png/, @email.attachments.first.content_type)
    assert_no_match(/This is an automated email/, get_html_part_from(@email))
    assert_match(/To respond to/, get_html_part_from(@email))
  end

  def test_email_change_notification
    member = members(:f_mentor)
    member.email_changer = members(:f_admin)

    # Notification email is sent to the user
    email = ChronusMailer.email_change_notification(member, "old_test@gmail.com").deliver_now

    # Verify email contents
    assert email.to.include?("old_test@gmail.com")
    assert_equal "#{programs(:org_primary).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:org_primary).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_match("Email address successfully updated", email.subject)

    assert_match(/Hi #{member.first_name},/, get_html_part_from(email))
    assert_match(/email address has been successfully updated /, get_html_part_from(email))
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_email_change_notification_with_custom_erb
    email_template = programs(:org_primary).mailer_templates.create!(:uid => EmailChangeNotification.mailer_attributes[:uid])
    custom_erb = %Q[You have tweaked your secret code from {{old_email_address}} to {{current_email_address}}.]
    email_template.update_attribute(:source, custom_erb)

    member = members(:f_mentor)
    member.email_changer = members(:f_admin)

    # Notification email is sent to the user
    email = ChronusMailer.email_change_notification(member, "old_test@gmail.com").deliver_now

    # Verify email contents
    assert email.to.include?("old_test@gmail.com")
    assert_match("Email address successfully updated", email.subject)
    assert_match(/You have tweaked your secret code from.*old_test@gmail.com.*to.*robert@example.com/, get_html_part_from(email))
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_forgot_password
    programs(:org_primary).default_program_domain.update_attribute(:domain, "albers.com")
    # Email for password change request.
    password = Password.create!(:member => users(:f_admin).member)

    ChronusMailer.forgot_password(password, users(:f_admin).program.organization).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal([users(:f_admin).email], email.to)
    assert_equal "#{users(:f_admin).program.organization.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{users(:f_admin).program.organization.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal("Reset your password", email.subject)
    assert_match change_password_url(
      subdomain: programs(:org_primary).subdomain,
      host: programs(:org_primary).domain,
      reset_code: password.reset_code), get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
    assert_match "Reset Password", get_html_part_from(email)
  end

  def test_forgot_password_mail_sent_wrt_member_locale
    to_member = members(:f_mentor)
    current_locale = I18n.locale
    password = Password.create!(member: to_member)
    Language.first.update_column(:language_name, "de")
    Language.set_for_member(to_member, :de)

    mailer = ChronusMailer.forgot_password(password, to_member.organization)
    assert_equal :de, mailer.instance_variable_get(:@mail_locale)
    assert_equal current_locale, I18n.locale
  end

  def test_member_logging_into_the_app_experience_with_multiple_programs
    member = members(:f_mentor)
    member.login_tokens.destroy_all
    ActivityLog.log_activity(users(:f_mentor_pbe), ActivityLog::Activity::PROGRAM_VISIT)
    member.create_login_token_and_send_email("uniq_token")
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{member.organization.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "Confirm your email on Primary Organization", mail.subject

    assert_select_helper_function_block "div.email_content", get_html_part_from(mail) do
      assert_select "a", text: "Confirm to login to your program", count: 1
    end

    match_str1 = "https://primary.#{DEFAULT_HOST_NAME}/p/pbe/pages/mobile_prompt?auth_config_id=#{member.organization.chronus_auth.id}&amp;mobile_app_login=true&amp;token_code=#{member.login_tokens.first.token_code}&amp;uniq_token=uniq_token"

    assert_match match_str1, get_html_part_from(mail)

    assert_match("We just need to verify that #{members(:f_mentor).email} is your email address, and then we will help you to log in to your Primary Organization.", get_html_part_from(mail))
    assert_match "<b>From your mobile device</b>, tap the button below to confirm:", get_html_part_from(mail)
    assert_match "If you didn't make this request, you can ignore this email and no further action will take place.", get_html_part_from(mail)
    assert_match "#{programs(:albers).organization.name}", get_html_part_from(mail)
    match_str = 'https://primary.' + DEFAULT_HOST_NAME
    assert_match match_str, get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_member_logging_into_the_app_experience_with_standalone_program
    member = members(:foster_mentor1)
    member.create_login_token_and_send_email("uniq_token")
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{users(:foster_mentor1).program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "Confirm your email on Foster School of Business", mail.subject
    assert_select_helper_function_block "div.email_content", get_html_part_from(mail) do
      assert_select "a", text: "Confirm to login to your program", count: 1
    end
    match_str = "https://foster.#{DEFAULT_HOST_NAME}/p/main/pages/mobile_prompt?auth_config_id=#{member.organization.chronus_auth.id}&amp;mobile_app_login=true&amp;token_code=#{member.login_tokens.first.token_code}&amp;uniq_token=uniq_token"
    assert_match match_str, get_html_part_from(mail)
    assert_match("We just need to verify that #{members(:foster_mentor1).email} is your email address, and then we will help you to log in to your Foster School of Business.", get_html_part_from(mail))
    assert_match "<b>From your mobile device</b>, tap the button below to confirm:", get_html_part_from(mail)
    assert_match "If you didn't make this request, you can ignore this email and no further action will take place.", get_html_part_from(mail)
    assert_match "#{programs(:foster).name}", get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_mentor_added_notification
    ChronusMailer.admin_added_notification(members(:f_mentor), members(:f_admin), nil,Password.create!(:member => members(:f_mentor))).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "\"#{users(:f_admin).name} via #{programs(:org_primary).name}\" <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{members(:f_admin).name} invites you to be an administrator!", mail.subject
    assert_match("#{members(:f_admin).name}", get_html_part_from(mail))
    assert_match("#{programs(:org_primary).name}", get_html_part_from(mail))
    assert_match "Please get started by reviewing the program and making adjustments/changes if needed.", get_html_part_from(mail)
    assert_match "Accept and sign up", get_html_part_from(mail)
    match_str = 'https://primary.' + DEFAULT_HOST_NAME
    assert_match match_str, get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
    # Sender name is not visible
    members(:f_admin).expects(:visible_to?).returns(false)
    ChronusMailer.admin_added_notification(members(:f_mentor), members(:f_admin), nil,Password.create!(:member => members(:f_mentor))).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:org_primary).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
  end

  def test_mentor_added_notification_with_message
    member = members(:f_mentor)
    admin_member = members(:f_admin)
    organization = member.organization

    ChronusMailer.admin_added_notification(member, admin_member, "Welcome", Password.create!(member: member)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    html_content = get_html_part_from(mail)
    assert_equal "#{admin_member.name} invites you to be an administrator!", mail.subject
    assert_match("#{admin_member.name}", html_content)
    assert_match("#{organization.name}", html_content)
    assert_match "https://primary.#{DEFAULT_HOST_NAME}", html_content
    assert_match('Welcome', html_content)
    assert_match(/This is an automated email/, html_content)
  end

  def test_user_promoted_to_admin_notification
    ChronusMailer.user_promoted_to_admin_notification(members(:f_mentor), members(:f_admin)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "You are now an administrator!", mail.subject
    assert_match("#{members(:f_admin).name} has added you as an administrator to #{programs(:org_primary).name}.", get_html_part_from(mail))
    assert_match("#{programs(:org_primary).name}", get_html_part_from(mail))
    org_login_url = login_url(:subdomain => programs(:org_primary).subdomain)
    assert_match "You can get started by reviewing the programs", get_html_part_from(mail)
    assert_match "#{org_login_url}", get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_new_admin_message_notification_to_member
    # Notification email is sent to the user
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    organization = programs(:org_primary)
    message = messages(:second_admin_message)
    message.program = organization
    message.save!

    ChronusMailer.new_admin_message_notification_to_member(organization.members.admins.first, message, sender: message.get_sender).deliver_now
    email = ActionMailer::Base.deliveries.last
    # Verify email contents
    assert email.to[0].include?(members(:f_admin).email)
    assert_equal [message.sender_email], email.cc
    assert_equal "#{message.sender_name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{message.sender_name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal("#{message.subject}", email.subject)
    assert_match(/You have a .*message.* from Test User/, get_html_part_from(email))
    assert_no_match(/in #{programs(:albers).name}/, get_html_part_from(email))
    assert_match(/#{message.content}/, get_html_part_from(email))
    assert_no_match(/This is an automated email/, get_html_part_from(email))
    assert_match(/To respond to/, get_html_part_from(email))
    assert_match(/click the button below or click reply to this email./, get_html_part_from(email))
    assert_match(/is_inbox=true/, get_html_part_from(email))
    assert_match(/reply=true/, get_html_part_from(email))
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(email))
    assert_match "Reply", get_html_part_from(email)
  end

  def test_org_level_email_in_multitrack_org
    #check logo, signature and email url for member part of multitrack org
    organization = programs(:org_primary)
    assert_false organization.standalone?
    ProgramAsset.create!({program_id: organization.id})
    assert_false organization.program_asset.logo.present?
    organization.reload.update_attributes(:logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    assert_equal "test_pic.png", organization.program_asset.logo_file_name

    # Email for password change request.
    password = Password.create!(:member => users(:f_admin).member)
    email = ChronusMailer.forgot_password(password, users(:f_admin).program.organization)
    email_content = get_html_part_from(email)
    assert_select_helper_function_block "div.email_content > div", email_content, text: /Thanks, \n/ do
      assert_select "a[href='https://#{organization.url}/']", text: "#{organization.name}"
    end
  end

  def test_org_level_email_in_standalone_org
    #check logo, signature and email url for member part of standalone org
    organization = programs(:org_foster)
    program = programs(:foster)
    assert organization.standalone?
    ProgramAsset.create!({program_id: organization.id})
    assert_false organization.program_asset.logo.present?
    organization.reload.update_attributes(:logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    assert_equal "test_pic.png", organization.program_asset.logo_file_name

    # Email for password change request.
    password = Password.create!(:member => users(:foster_admin).member)
    email = ChronusMailer.forgot_password(password, users(:foster_admin).program.organization)
    email_content = get_html_part_from(email)
    assert_select_helper_function_block "div.email_content > div", email_content, text: /Thanks, \n/ do
      assert_select "a[href='https://#{organization.url}/']", text: "#{organization.name}"
    end
  end

  def test_inbox_message_notification_for_track
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    to_member = members(:f_mentor)
    from_member = members(:f_student)
    attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    message = create_message(:sender => from_member, :receiver => to_member, :attachment => attachment)
    message_receiver = message.message_receivers[0]
    organization = message.organization

    # Create the notification email
    @email = ChronusMailer.inbox_message_notification_for_track(members(:f_mentor), programs(:albers), message, sender: message.sender).deliver_now

    # Test the email
    assert_equal "#{message.subject}", @email.subject
    assert_equal [message.sender.email], @email.cc
    assert_equal "#{from_member.name} <#{MAILER_ACCOUNT[:email_address]}>", @email['from'].to_s
    assert_equal "#{from_member.name} <#{MAILER_ACCOUNT[:email_address]}>", @email['sender'].to_s
    assert_match /You have a/, get_html_part_from(@email)
    assert_match /in Albers Mentor Program/, get_html_part_from(@email)
    assert_match message.content, get_html_part_from(@email)
    assert_match(/is_inbox=true/, get_html_part_from(@email))
    assert_match(/mailto:reply-/, get_html_part_from(@email))
    assert_match("login and reply to this message", get_html_part_from(@email))
    assert_match(/Albers Mentor Program/, get_html_part_from(@email))
    assert_match MAILER_ACCOUNT[:reply_to_address].call(message_receiver.api_token, ReplyViaEmail::MESSAGE), @email.reply_to[0]
    assert_equal(1, @email.attachments.size)
    assert_match(message.attachment_file_name, @email.attachments.first.filename)
    assert_match(/text\/plain/, @email.attachments.first.content_type)
    assert_no_match(/This is an automated email/, get_html_part_from(@email))
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(@email))
    assert_match(/To respond to/, get_html_part_from(@email))
  end

  def test_inbox_message_notification_for_track_in_member_locale
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    program = programs(:albers)
    to_member = members(:f_mentor)
    from_member = members(:f_student)
    message = create_message(:sender => from_member, :receiver => to_member)

    locale = :de
    Language.first.update_attribute(:language_name, locale)
    Language.set_for_member(to_member, locale)

    # Create the notification email
    mailer = ChronusMailer.inbox_message_notification_for_track(to_member, program, message, sender: message.sender)
    assert_equal locale, mailer.instance_variable_get(:@mail_locale)

    organization_languages(:hindi).program_languages.where(program_id: program.id).delete_all
    mailer = ChronusMailer.inbox_message_notification_for_track(to_member, program.reload, message, sender: message.sender)
    assert_equal :en, mailer.instance_variable_get(:@mail_locale)
  end

  def test_inbox_message_notification_for_track_for_upcoming_meetings_widget
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    to_member = members(:f_mentor)
    from_member = members(:mkr_student)
    attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    message = create_message(:sender => from_member, :receiver => to_member, :attachment => attachment)
    message_receiver = message.message_receivers[0]
    organization = message.organization
    programs(:albers).enable_feature(FeatureName::CALENDAR, true)

    time = Time.now + 30.minutes
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting.meeting_request.update_attribute(:status, AbstractRequest::Status::ACCEPTED)

    programs(:albers).meetings.reload

    upcoming_meetings = Meeting.get_meetings_for_upcoming_widget(programs(:albers), to_member, from_member)

    assert upcoming_meetings.present?
    assert_equal meeting, upcoming_meetings.find{|meeting_hash| !meeting_hash[:meeting].calendar_time_available?}[:meeting]

    # Create the notification email
    email = ChronusMailer.inbox_message_notification_for_track(members(:f_mentor), programs(:albers), message, sender: message.sender).deliver_now

    # Test the email

    email_content = get_html_part_from(email)
    assert_match /in Albers Mentor Program/, email_content
    assert_match /Upcoming Meetings/, email_content

    upcoming_meetings.each do |meeting_hash|
      meeting = meeting_hash[:meeting]
      assert_match "#{meeting.topic}", email_content
      assert_match "sub_src=#{SubSource::Meeting::UPCOMING_MEETINGS_WIDGET}", email_content
      assert_match "https://primary.#{DEFAULT_HOST_NAME}/p/albers/meetings/#{meeting.id}?current_occurrence_time=", email_content

      if meeting.calendar_time_available?
        assert_match DateTime.localize(meeting_hash[:current_occurrence_time].in_time_zone(members(:f_mentor).get_valid_time_zone), format: :full_display_with_zone), email_content
      else
        assert_match "Not Set", email_content
        assert_match "Set Meeting Time", email_content
        assert_match /setup_meeting_time=true/, email_content
      end
    end

    Meeting.any_instance.unstub(:get_meetings_for_upcoming_widget)

    programs(:albers).enable_feature(FeatureName::CALENDAR, false)

    email = ChronusMailer.inbox_message_notification_for_track(members(:f_mentor), programs(:albers), message, sender: message.sender).deliver_now

    # Test the email

    email_content = get_html_part_from(email)
    assert_match /in Albers Mentor Program/, email_content
    assert_no_match /Upcoming Meetings (Next 30 days)/, email_content
  end

  def test_inbox_message_notification_for_track_for_upcoming_meetings_widget_with_no_meetings
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    to_member = members(:f_mentor)
    from_member = members(:mkr_student)
    attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    message = create_message(:sender => from_member, :receiver => to_member, :attachment => attachment)
    message_receiver = message.message_receivers[0]
    organization = message.organization
    programs(:albers).enable_feature(FeatureName::CALENDAR, true)

    Meeting.stubs(:get_meetings_for_upcoming_widget).returns([])

    # Create the notification email
    email = ChronusMailer.inbox_message_notification_for_track(members(:f_mentor), programs(:albers), message, sender: message.sender).deliver_now

    # Test the email
    email_content = get_html_part_from(email)
    assert_match /in Albers Mentor Program/, email_content
    assert_no_match /Upcoming Meetings/, email_content
    assert_no_match /(Next 30 days)/, email_content
  end

  def test_inbox_message_notification_for_track_should_not_have_notif_link
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    to_member = members(:f_mentor)
    from_member = members(:f_student)
    message = create_message(:sender => from_member , :receiver => to_member)
    organization = to_member.organization
    email = ChronusMailer.inbox_message_notification_for_track(members(:f_mentor), programs(:albers), message, sender: message.sender).deliver_now
    assert_equal [message.sender.email], email.cc
    assert_match /in Albers Mentor Program/, get_html_part_from(email)
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(email))
    assert_match(/Albers Mentor Program/, get_html_part_from(email))
    assert_equal [message.get_sender.email], email.cc
  end

  def test_inbox_message_notification_for_track_for_reply_to_admin
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    msg = messages(:first_admin_message)
    message = msg.build_reply(members(:f_admin))
    message.content = "Hi"
    message.sender = members(:f_admin)
    message.attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    message.save!

    ChronusMailer.inbox_message_notification_for_track(members(:f_admin), programs(:albers), message, sender: message.sender).deliver_now
    email = ActionMailer::Base.deliveries.last

    # Verify email contents
    assert email.to[0].include?(users(:f_admin).email)
    assert_equal [message.sender.email], email.cc
    assert_equal "\"#{message.sender.name}\" <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal("#{message.subject}", email.subject)
    assert_match(/You have a .*message.* from/, get_text_part_from(email))
    assert_match /in Albers Mentor Program/, get_html_part_from(email)
    assert_match(/#{message.content}/, get_text_part_from(email))
    assert_match "just reply to this email", get_html_part_from(email)
    assert_match(/is_inbox=true/, get_html_part_from(email))
    assert_match(/reply=true/, get_html_part_from(email))
    assert_match(/Albers Mentor Program/, get_html_part_from(email))
    assert_match(/To respond to/, get_html_part_from(email))
    assert_equal(1, email.attachments.size)
    assert_match(message.attachment_file_name, email.attachments.first.filename)
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(email))
    assert_match(/text\/plain/, email.attachments.first.content_type)

    # Sender name is not visible
    message.sender.expects(:visible_to?).returns(false)
    ChronusMailer.inbox_message_notification_for_track(members(:f_admin), programs(:albers), message, sender: message.sender).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [message.sender.email], mail.cc
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
  end

  def test_inbox_message_notification_for_track_with_no_change_notif_link_for_reply_to_admin
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    msg = messages(:first_admin_message)
    message = msg.build_reply(members(:f_admin))
    message.content = "Hi"
    message.sender = members(:f_admin)

    message.attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    message.save!

    ChronusMailer.inbox_message_notification_for_track(members(:f_admin), programs(:albers), message, sender: message.sender).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [message.sender.email], email.cc
    assert_match /in Albers Mentor Program/, get_html_part_from(email)
    assert_no_match(/.*Click here.* to modify your email notifications.*/, get_html_part_from(email))
    assert_match(/Albers Mentor Program/, get_html_part_from(email))
  end

  def test_inbox_message_notification_for_track_with_custom_erb
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    email_template = programs(:org_primary).mailer_templates.create!(:uid => InboxMessageNotificationForTrack.mailer_attributes[:uid])
    custom_erb = %Q[has sent you a secret message]
    email_template.update_attribute(:source, custom_erb)

    to_member = members(:f_mentor)
    from_member = members(:f_student)
    message = create_message(:sender => from_member , :receiver => to_member)
    # Create the notification email
    @email = ChronusMailer.inbox_message_notification_for_track(members(:f_mentor), programs(:albers), message, sender: message.sender).deliver_now

    # Test the email
    assert_equal "#{message.subject}", @email.subject
    assert_equal [message.sender.email], @email.cc
    assert_match /has sent you a secret message/, get_html_part_from(@email)
    assert_match(/Albers Mentor Program/, get_html_part_from(@email))
    assert_no_match(/This is an automated email/, get_html_part_from(@email))
  end
end
