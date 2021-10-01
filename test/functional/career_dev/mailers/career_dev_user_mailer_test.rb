require_relative './../../../test_helper.rb'
require_relative './../../../../app/helpers/application_helper'

class CareerDevUserMailerTest < ActionMailer::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"

  include Rails.application.routes.url_helpers
  include ApplicationHelper

  def default_url_options
    ActionMailer::Base.default_url_options
  end

  def setup
    super
    helper_setup
    chronus_s3_utils_stub

    #Changing the default customized terms
    org = programs(:org_nch)
    program = programs(:primary_portal)
    org.admin_custom_term.update_attributes!(:term => 'Test Administrator', :term_downcase => 'test administrator', :pluralized_term => 'Test Administrators', :pluralized_term_downcase => 'test administrators', :articleized_term => 'a Test Administrator', :articleized_term_downcase => 'a test administrator')
    program.roles.find_by(name: RoleConstants::EMPLOYEE_NAME).customized_term.save_term('Test Employee', CustomizedTerm::TermType::ROLE_TERM)
    program.roles.find_by(name: RoleConstants::ADMIN_NAME).customized_term.save_term('Test Administrator', CustomizedTerm::TermType::ROLE_TERM)
    program.mails_disabled_by_default.each do |mail_class|
      mt = program.mailer_templates.where(uid: mail_class.mailer_attributes[:uid]).first
      mt.enabled = true
      mt.save!
    end
  end

  def test_welcome_message_to_portal_admin
    program = programs(:primary_portal)
    user = users(:portal_admin)
    ChronusMailer.welcome_message_to_admin(user).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:primary_portal).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal([user.email], mail.to)
    assert_equal("#{user.first_name}, welcome to #{program.name}!", mail.subject)
    assert_match(/Congratulations! You are now a test administrator in Primary Career Portal./, get_text_part_from(mail).gsub("\n", " "))
    assert_match(/Get started by visiting the Customer Support Center \(CSC\)/, get_text_part_from(mail).gsub("\n", " "))
    assert_match(/where you can browse through comprehensive articles on the different features of the program/, get_text_part_from(mail).gsub("\n", " "))
    assert_match(/Here are two articles we think you'll find helpful:/, get_text_part_from(mail).gsub("\n", " "))
    match_str = "https:\/\/nch." + DEFAULT_HOST_NAME + "\/p\/portal\/session\/zendesk"
    assert_match(/#{match_str}/, get_text_part_from(mail).gsub("\n", " "))
    assert_match(/Measuring the health of your program/, get_text_part_from(mail).gsub("\n", " "))
    assert_match(/http:\/\/chronusmentor.chronus.com\/entries\/23313057-Why-custom-user-views-are-crucial/, get_text_part_from(mail).gsub("\n", " "))
    assert_match(/http:\/\/chronusmentor.chronus.com\/entries\/29618078-Measuring-the-health-of-your-program/, get_text_part_from(mail).gsub("\n", " "))
    assert_match(/Why custom user views are helpful/, get_text_part_from(mail).gsub("\n", " "))
  end

  def test_welcome_message_to_portal_admin_with_custom_erb
    email_template = programs(:primary_portal).mailer_templates.create!(:uid => WelcomeMessageToAdmin.mailer_attributes[:uid])

    custom_template = %Q[Added by: {{administrator_name}}
                         URL Customize Profile Form: {{url_customize_profile_form}}
                         URL Customize Program: {{url_customize_program}}
                         URL Customer Support: {{url_customer_support}}]
    email_template.update_attributes(:source => custom_template)

    organization = programs(:org_nch)

    ChronusMailer.welcome_message_to_admin(users(:portal_admin)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:primary_portal).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal([users(:portal_admin).email], mail.to)
    assert_match("#{users(:portal_admin).first_name}, welcome to Primary Career Portal!", mail.subject)
    assert_match(get_support_url(subdomain: organization.subdomain, url: true),get_html_part_from(mail))
    assert_match(programs(:primary_portal).get_program_health_url, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_portal_member_with_set_of_roles_added_notification_to_review_profile
    pending_member = create_member(organization: programs(:org_nch), email: "pending_protal_user@chronus.com")
    user  = create_user(:member => pending_member, :program => programs(:primary_portal), :role_names => [:employee])
    user.state = User::Status::PENDING
    user.save
    user.reload
    ChronusMailer.portal_member_with_set_of_roles_added_notification_to_review_profile(user, users(:portal_admin), Password.create!(:member => pending_member)).deliver_now
    mail = ActionMailer::Base.deliveries.last

    assert_equal "Primary Career Portal <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal("#{user.first_name}, #{users(:portal_admin).name(:name_only => true)} invites you to join as a Test Employee!", mail.subject)
    assert_match("#{users(:portal_admin).name(:name_only => true)}", get_html_part_from(mail))
    assert_match("#{programs(:primary_portal).name}", get_html_part_from(mail))
    match_str = "https://nch." +  DEFAULT_HOST_NAME
    assert_match match_str, get_html_part_from(mail)
    assert_match(/You have been invited by Freakin Admin to join Primary Career Portal as a Test Employee./, get_html_part_from(mail))
    assert_match(/After you accept the invite, it is important that you complete and publish your profile./, get_html_part_from(mail))
    assert_match(/Accept and sign-up/, get_html_part_from(mail))
    assert_match(/If you have any questions, please contact the test administrator/, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_portal_member_with_set_of_roles_added_notification
    active_member = create_member(organization: programs(:org_nch), email: "protal_user@chronus.com")
    user  = create_user(:member => active_member, :program => programs(:primary_portal), :role_names => [:employee])
    user.reload
    ChronusMailer.portal_member_with_set_of_roles_added_notification(user, users(:portal_admin), Password.create!(:member => active_member)).deliver_now
    mail = ActionMailer::Base.deliveries.last

    assert_equal "Primary Career Portal <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal("#{user.first_name}, #{users(:portal_admin).name(:name_only => true)} invites you to join as a Test Employee!", mail.subject)
    assert_match("#{users(:portal_admin).name(:name_only => true)}", get_html_part_from(mail))
    assert_match("#{programs(:primary_portal).name}", get_html_part_from(mail))
    match_str = "https://nch." +  DEFAULT_HOST_NAME
    assert_match match_str, get_html_part_from(mail)

    url_invite = match_str+"/p/#{programs(:primary_portal).root}/users/new_user_followup"
    assert_match url_invite, get_html_part_from(mail)

    assert_match(/You have been invited by Freakin Admin to join Primary Career Portal as a Test Employee./, get_html_part_from(mail))
    assert_match(/It is important that you review and complete your profile./, get_html_part_from(mail))
    assert_match(/Accept and sign-up/, get_html_part_from(mail))
    assert_match(/If you have any questions, please contact the test administrator/, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end


  def test_portal_member_with_set_of_role_added_notification_should_send_correct_tags
    active_member = create_member(organization: programs(:org_nch), email: "pending_protal_user@chronus.com")
    user  = create_user(:member => active_member, :program => programs(:primary_portal), :role_names => [:employee])
    user.save
    email_template = programs(:org_nch).mailer_templates.create!(:uid => PortalMemberWithSetOfRolesAddedNotification.mailer_attributes[:uid])
    custom_template = %Q[{{url_invite}}
                         {{invitor_name}}
                         {{role_names}}
                         {{accept_and_sign_up_button}}
                         {{url_contact_admin}}]

    email_template.update_attributes(:source => custom_template)

    ChronusMailer.portal_member_with_set_of_roles_added_notification(user, users(:portal_admin), Password.create!(:member => active_member)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(mail)
    match_str = "https://nch." +  DEFAULT_HOST_NAME
    url_invite = match_str+"/p/#{programs(:primary_portal).root}/users/new_user_followup"
    assert_match url_invite, email_content
    assert_match "#{users(:portal_admin).name(:name_only => true)}", email_content
    assert_match /a Test Employee/, email_content
    assert_match /Accept and sign-up/, email_content
    match_str = "https://nch." +  DEFAULT_HOST_NAME
    contact_admin_url = match_str +"/p/#{programs(:primary_portal).root}/contact_admin"
    assert_match contact_admin_url, email_content
  end

  def test_portal_member_with_set_of_role_added_notification_to_review_should_send_correct_tags
    pending_member = create_member(organization: programs(:org_nch), email: "pending_protal_user@chronus.com")
    user  = create_user(:member => pending_member, :program => programs(:primary_portal), :role_names => [:employee])
    user.state = User::Status::PENDING
    user.save
    email_template = programs(:org_nch).mailer_templates.create!(:uid => PortalMemberWithSetOfRolesAddedNotificationToReviewProfile.mailer_attributes[:uid])
    custom_template = %Q[{{url_invite}}
                         {{invitor_name}}
                         {{role_names}}
                         {{accept_and_sign_up_button}}
                         {{url_contact_admin}}]

    email_template.update_attributes(:source => custom_template)

    ChronusMailer.portal_member_with_set_of_roles_added_notification_to_review_profile(user, users(:portal_admin), Password.create!(:member => pending_member)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(mail)
    match_str = "https://nch." +  DEFAULT_HOST_NAME
    url_invite = match_str+"/p/#{programs(:primary_portal).root}/users/new_user_followup"
    assert_match url_invite, email_content
    assert_match "#{users(:portal_admin).name(:name_only => true)}", email_content
    assert_match /a Test Employee/, email_content
    assert_match /Accept and sign-up/, email_content
    match_str = "https://nch." +  DEFAULT_HOST_NAME
    contact_admin_url = match_str +"/p/#{programs(:primary_portal).root}/contact_admin"
    assert_match contact_admin_url, email_content
  end

  def test_welcome_message_to_portal_user
    user = users(:portal_employee)
    program = user.program
    organization = program.organization

    ChronusMailer.welcome_message_to_portal_user(user, users(:portal_admin)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_match(login_url(subdomain: organization.subdomain, root: program.root), get_html_part_from(mail))

    user.member.stubs(:can_signin?).returns(false)
    ChronusMailer.welcome_message_to_portal_user(user, users(:portal_admin)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [user.email], mail.to
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_match("#{user.first_name}, welcome to #{program.name}", mail.subject)
    assert_match(/You have been added as a Test Employee in #{program.name}./, get_html_part_from(mail))
    assert_match(/Click here.* to visit #{program.name}./, get_html_part_from(mail))
    assert_match(new_user_followup_users_url(subdomain: organization.subdomain, reset_code: ""), get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_welcome_message_to_portal_user_with_custom_erb
    user = users(:portal_employee)
    program = user.program
    organization = program.organization
    email_template = program.mailer_templates.create!(uid: WelcomeMessageToPortalUser.mailer_attributes[:uid], content_changer_member_id: 1, content_updated_at: Time.now)
    custom_template = %Q[Added By: {{administrator_name}}
      Visit Program Button: {{visit_program_button}}
      Url Contact Admin: {{url_contact_admin}}
      Url Edit Profile: {{url_edit_profile}}
    ]
    email_template.update_attributes(source: custom_template)

    user.member.stubs(:can_signin?).returns(false)
    ChronusMailer.welcome_message_to_portal_user(user, users(:portal_admin)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [user.email], mail.to
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_match("#{user.first_name}, welcome to #{program.name}", mail.subject)
    assert_match(/Added By: Freakin Admin \(Test Administrator\)/, get_html_part_from(mail))
    assert_match(login_url(subdomain: program.organization.subdomain, root: program.root), get_html_part_from(mail))
    assert_match(get_contact_admin_path(program, only_url: true, url_params: { subdomain: organization.subdomain, root: program.root } ), get_html_part_from(mail))
    assert_match(new_user_followup_users_url(subdomain: organization.subdomain, reset_code: ""), get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_welcome_message_to_portal_user_with_custom_erb_to_existing_member
    user = users(:portal_employee)
    program = user.program
    email_template = program.mailer_templates.create!(uid: WelcomeMessageToPortalUser.mailer_attributes[:uid], content_changer_member_id: 1, content_updated_at: Time.now)
    email_template.update_attributes(source: "Url Edit Profile: {{url_edit_profile}}")

    ChronusMailer.welcome_message_to_portal_user(user, users(:portal_admin)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [user.email], mail.to
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail["from"].to_s
    assert_match("#{user.first_name}, welcome to #{program.name}", mail.subject)
    assert_match(edit_member_url(user.member, subdomain: program.organization.subdomain, root: program.root), get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_portal_mail_should_show_updated_example_and_description_for_tags
    program = programs(:primary_portal)
    assert_equal "We have organized a grand lunch and networking event next friday at our cafeteria between noon and 2.00pm. This will be a great platform to extend your professional network.", AnnouncementUpdateNotification.mailer_attributes[:tags][:specific_tags][:announcement_body][:example].call(program)
    assert_equal "a test employee", InviteNotification.mailer_attributes[:tags][:specific_tags][:invited_as][:example].call(program)
    assert_equal "as a test employee", InviteNotification.mailer_attributes[:tags][:specific_tags][:as_role_name_articleized][:example].call(program)
    assert_equal "a test employee", NotEligibleToJoinNotification.mailer_attributes[:tags][:specific_tags][:roles_applied_for][:example].call(program)

    assert_match "fill out your application as a Test Employee.", AdminMessageNotification.mailer_attributes[:tags][:specific_tags][:message_content][:example].call(program)
    assert_equal "Joining as a test employee", AdminMessageNotification.mailer_attributes[:tags][:specific_tags][:message_subject][:example].call(program)
    assert_equal "a test employee", MembershipRequestAccepted.mailer_attributes[:tags][:specific_tags][:member_role][:example].call(program)
    assert_equal "a Test Employee", WelcomeMessageToPortalUser.mailer_attributes[:tags][:specific_tags][:user_role][:example].call(program)
    assert_equal "a Test Employee", PortalMemberWithSetOfRolesAddedNotification.mailer_attributes[:tags][:specific_tags][:role_names][:example].call(program)
    assert_equal "a Test Employee", PortalMemberWithSetOfRolesAddedNotificationToReviewProfile.mailer_attributes[:tags][:specific_tags][:role_names][:example].call(program)
    assert_equal "When is the next networking event for program members?", QaAnswerNotification.mailer_attributes[:tags][:specific_tags][:question_summary][:example].call(program)
    assert_equal "The next networking event is coming next Saturday at 5:00 pm.", QaAnswerNotification.mailer_attributes[:tags][:specific_tags][:answer][:example].call(program)
    assert_equal "Role of the member added to the program appended with (a/an)", DemotionNotification.mailer_attributes[:tags][:specific_tags][:role_name][:description].call(program)
    assert_equal "a test employee", DemotionNotification.mailer_attributes[:tags][:specific_tags][:role_name][:example].call(program)
    assert_equal "a test employee", PromotionNotification.mailer_attributes[:tags][:specific_tags][:promoted_role_articleized][:example].call(program)
    assert_equal "test employee", PromotionNotification.mailer_attributes[:tags][:specific_tags][:promoted_role][:example].call(program)
    assert_equal "It looks like you are enrolled in the program.", CompleteSignupExistingMemberNotification.mailer_attributes[:tags][:specific_tags][:user_state_content][:example].call(program)
    assert_equal "Hello Mark! Can you please review my resume?", ReplyToAdminMessageFailureNotification.mailer_attributes[:tags][:specific_tags][:content][:example].call(program)
    assert_equal "We have organized a grand lunch and networking event next friday at our cafeteria between noon and 2.00pm. This will be a great platform to extend your professional network.", AnnouncementNotification.mailer_attributes[:tags][:specific_tags][:announcement_body][:example].call(program)
    example = ProgramReportAlert.mailer_attributes[:tags][:specific_tags][:alert_details][:example].call(program)
    assert_match /Pending Membership Requests/, example
    assert_match /3 Membership Requests are pending more than 15 days/,  example
  end

  def test_admin_weekly_status_mail
    Timecop.freeze(Time.now.beginning_of_day + 22.hours) do
      program = programs(:primary_portal)
      admin_user = program.admin_users.first
      admin_user.member.update_attribute(:time_zone, "Asia/Tokyo")
      admin_user.reload

      member = members(:nch_mentor)
      program.roles.find_by(name: RoleConstants::EMPLOYEE_NAME).update_attributes(membership_request: true)
      MembershipRequest.create!(:member => member, :email => member.email, :program => programs(:primary_portal), :first_name => member.first_name, :last_name => member.last_name, :role_names => [RoleConstants::EMPLOYEE_NAME])

      ac = ArticleContent.create!(:title => "What", :type => "text", :status => ArticleContent::Status::PUBLISHED)
      Article.create!({:article_content => ac, :author => members(:nch_admin), :organization => programs(:org_nch), :published_programs => [programs(:primary_portal)]})

      program.reload
      precomputed_hash = program.get_admin_weekly_status_hash
      ChronusMailer.admin_weekly_status(admin_user, program, precomputed_hash).deliver_now

      email = ActionMailer::Base.deliveries.last

      since = 1.week.ago
      since_time = DateTime.localize(since.in_time_zone(admin_user.member.get_valid_time_zone), format: :short)
      current_time = DateTime.localize(Time.now.in_time_zone(admin_user.member.get_valid_time_zone), format: :short)
      assert_equal "Your weekly activity summary (#{since_time} to #{current_time}) for #{program.name}", email.subject
      email_html_content = get_html_part_from(email)

      assert_match /Pending Membership Requests/, email_html_content
      assert_match /New test employees/, email_html_content
      assert_match /New articles/, email_html_content
      # assert_match /New articles/
      assert_no_match /Mentoring Requests Received/, email_html_content
      assert_no_match /Mentoring Connections Established/, email_html_content
      assert_no_match /Mentoring Requests Pending/, email_html_content
      assert_no_match /Meeting Requests Received/, email_html_content
      assert_no_match /Meeting Requests Pending/, email_html_content
      assert_no_match /New Survey Responses/, email_html_content


      mr_roles = program.roles.select{|r| r.membership_request || r.join_directly? }
      mr_roles.each do |role|
        role.membership_request = false
        role.join_directly = false
        role.save!
      end

      SurveyAnswer.where(common_question_id: program.survey_question_ids).destroy_all

      survey = ProgramSurvey.create!(
        :program => programs(:primary_portal),
        :name => "First Survey",
        :recipient_role_names => [:employee],
        :edit_mode => Survey::EditMode::MULTIRESPONSE)

      survey_question = SurveyQuestion.create!(
        {:program => programs(:primary_portal),
          :question_text => "How are you?",
          :question_type => CommonQuestion::Type::STRING,
          :survey => survey})

      answer_1 = SurveyAnswer.create!(
      {:answer_text => "My answer", :user => users(:portal_employee), :last_answered_at => Time.now.utc,
        :survey_question => survey_question})


      program.membership_requests.destroy_all
      program.articles.destroy_all
      program.reload
      precomputed_hash = program.get_admin_weekly_status_hash
      assert_equal precomputed_hash[:new_survey_responses], 1

      ChronusMailer.admin_weekly_status(admin_user, program, precomputed_hash).deliver_now
      email = ActionMailer::Base.deliveries.last
      email_html_content = get_html_part_from(email)

      since = 1.week.ago
      since_time = DateTime.localize(since.in_time_zone(admin_user.member.get_valid_time_zone), format: :short)
      current_time = DateTime.localize(Time.now.in_time_zone(admin_user.member.get_valid_time_zone), format: :short)
      assert_equal "Your weekly activity summary (#{since_time} to #{current_time}) for #{program.name}", email.subject

      assert_false program.has_membership_requests?

      assert_no_match /Pending Membership requests/, email_html_content
      assert_match /New test employees/, email_html_content
      assert_match /New Survey Responses/, email_html_content

      assert_no_match /Mentoring Requests Received/, email_html_content
      assert_no_match /Mentoring Connections Established/, email_html_content
      assert_no_match /Mentoring Requests Pending/, email_html_content
      assert_no_match /New articles/, email_html_content
      assert_no_match /strong Meeting Requests Received/, email_html_content.gsub(/[^0-9a-z ]/i, '')
      assert_no_match /strong Meeting Requests Pending/, email_html_content.gsub(/[^0-9a-z ]/i, '')
    end
  end

  def test_promotion_notification_mail
    email_template = programs(:primary_portal).mailer_templates.create!(:uid => PromotionNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)

    custom_template = %Q[{{promoted_role}} welcome to the world of Career development!!]
    email_template.update_attributes(:source => custom_template)

    user = users(:portal_employee)
    promoted_roles = [RoleConstants::ADMIN_NAME]
    promoted_by = users(:portal_admin)

    ChronusMailer.promotion_notification(user, promoted_roles, promoted_by, '').deliver_now

    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:primary_portal).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal([users(:portal_employee).email], mail.to)
    assert_match(/test administrator welcome to the world of Career development!!/, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  private

  def helpers
    ActionController::Base.helpers
  end
end