require_relative './../../test_helper.rb'
require_relative './../../../app/helpers/application_helper'

class UserMailerTest < ActionMailer::TestCase
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
    @_mentoring_connection = "mentoring connection"
    chronus_s3_utils_stub

    #Changing the default customized terms
    org = programs(:org_primary)
    program = programs(:albers)
    org.admin_custom_term.update_attributes!(:term => 'Test Administrator', :term_downcase => 'test administrator', :pluralized_term => 'Test Administrators', :pluralized_term_downcase => 'test administrators', :articleized_term => 'a Test Administrator', :articleized_term_downcase => 'a test administrator')
    program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.save_term('Test Mentor', CustomizedTerm::TermType::ROLE_TERM)
    program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.save_term('Test Student', CustomizedTerm::TermType::ROLE_TERM)
    program.roles.find_by(name: RoleConstants::ADMIN_NAME).customized_term.save_term('Test Administrator', CustomizedTerm::TermType::ROLE_TERM)
    program.mails_disabled_by_default.each do |mail_class|
      mt = program.mailer_templates.where(uid: mail_class.mailer_attributes[:uid]).first
      mt.enabled = true
      mt.save!
    end
    program.enable_feature(FeatureName::CALENDAR_SYNC, false)
    program.reload
    @_admin_string = "administrator"
  end

  def test_banner_fallback_when_no_logo_present
    program = programs(:albers)
    organization = program.organization
    setup_banner_fallback(organization, nil)

    group = groups(:mygroup)
    mentor = group.mentors.first
    group.message = "Hi, Admin wishes you best of luck for the connection"
    ChronusMailer.group_creation_notification_to_mentor(mentor, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_match ImportExportUtils.file_url(organization.banner_url), get_html_part_from(email)
  end

  def test_group_creation_notification_to_mentor
    users(:f_mentor).program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.update_attribute(:articleized_term_downcase, "an orange")
    group = groups(:mygroup)
    group.message = "Hi, Admin wishes you best of luck for the connection"
    ChronusMailer.group_creation_notification_to_mentor(users(:f_mentor), group).deliver_now
    email = ActionMailer::Base.deliveries.last

    mail_content = get_html_part_from(email)
    assert_match /Hi, Admin wishes you best of luck for the connection/, mail_content
    assert_match /#{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}/, mail_content
    assert_equal "Connect with your test student!", email.subject
    assert_equal users(:f_mentor).email, email.to.first
    assert_match users(:mkr_student).name, mail_content
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), mail_content
    assert_match /This is an automated email/, mail_content
    assert_match "mkr_student madankumarrajan</a> as your test student.", mail_content
    assert_match "Please review your profile and verify all the information there is still correct. Update your profile information if anything is wrong or no longer valid. This will help your test student learn more about you and your common interests.", mail_content
    assert_match "Connect with your test student today in the mentoring connection area.", mail_content
    assert_match "Start by reviewing initial tasks for both you and your test student.", mail_content
    assert_match "/p/albers/groups/#{group.id}?src=mail\"", mail_content
    assert_match "Visit your mentoring connection area", mail_content
    assert_match "/p/albers/contact_admin\"", mail_content
    # With url_signup
    email_template = groups(:mygroup).program.mailer_templates.create!(:uid => GroupCreationNotificationToMentor.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    email_template.source = "#{email_template.source} {{url_signup}}"
    email_template.save!

    ChronusMailer.group_creation_notification_to_mentor(users(:f_mentor), group).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_no_match /Message from the administrator/, mail_content
    match_str = "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/users\/new_user_followup\?reset_code"
    assert_match match_str, mail_content
  end

  # Subject when students count is singular
  def test_articleize_student_name
    group = groups(:mygroup)
    users(:f_mentor).program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.update_attribute(:articleized_term_downcase, "a fellow")
    ChronusMailer.group_creation_notification_to_mentor(users(:f_mentor), group).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_match /#{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}/, mail_content
    assert_equal "Connect with your test student!", email.subject
    assert_match "This is an automated email", mail_content
    assert_match "as your test student.", mail_content
    assert_match "Visit your mentoring connection area", mail_content
    assert_match "/p/albers/groups/#{group.id}?src=mail", mail_content
    assert_match "/p/albers/contact_admin", mail_content
  end

  def test_group_creation_notification_to_mentor_with_more_than_1_student
    allow_one_to_many_mentoring_for_program(programs(:albers))
    users(:f_mentor).update_attribute(:max_connections_limit, 10)
    users(:f_mentor).mentoring_groups.destroy_all
    group = create_group(:mentors => [users(:f_mentor)], :students => [users(:f_student), users(:student_1)])
    ChronusMailer.group_creation_notification_to_mentor(users(:f_mentor), group).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_equal "Connect with your test students!", email.subject
    assert_equal users(:f_mentor).email, email.to.first
    assert_match users(:f_student).name, get_html_part_from(email)
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_creation_notification_to_mentor_should_show_student_profile_link
    make_member_of(:moderated_program, :rahim)
    p = programs(:moderated_program)
    group = create_group(:mentors => [users(:moderated_mentor)], :students => [users(:rahim)], :program => p)
    ChronusMailer.group_creation_notification_to_mentor(users(:moderated_mentor), group).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_equal "Connect with your student!", email.subject
    assert_equal users(:moderated_mentor).email, email.to.first
    assert_match users(:rahim).name, get_html_part_from(email)
    assert_match "/p/modprog/members/#{users(:rahim).id}\"", get_html_part_from(email)
    assert_match group_url(group, :subdomain => programs(:org_primary).subdomain, :root => programs(:moderated_program).root), get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_creation_notification_to_students
    group = groups(:mygroup)
    stu = group.students.first
    group.message = "Hi, Admin wishes you best of luck for the connection"
    ChronusMailer.group_creation_notification_to_students(stu, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_match /Hi, Admin wishes you best of luck for the connection/, mail_content
    assert_match /#{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}/, mail_content
    assert_equal "You have been assigned a test mentor!", email.subject
    assert_equal users(:mkr_student).email, email.to.first
    assert_match users(:f_mentor).name, mail_content
    assert_match "Hi #{stu.first_name},", mail_content
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), mail_content
    assert_match /This is an automated email/, mail_content
    assert_match "/p/albers/members/#{users(:f_mentor).id}\"", mail_content
    assert_match "as your test mentor.", mail_content
    assert_match "Please review your profile and verify all the information there is still correct. Update your profile information if anything is wrong or no longer valid. This will help your test mentor learn more about you and your common interests.", mail_content
    assert_match "Connect with your test mentor today in the mentoring connection area.", mail_content
    assert_match "Start by reviewing initial tasks for both you and your test mentor.", mail_content
    assert_match "/p/albers/groups/1?src=mail\"", mail_content
    assert_match "Visit your mentoring connection area", mail_content
    assert_match "/p/albers/contact_admin\"", mail_content
    # With url_signup
    email_template = groups(:mygroup).program.mailer_templates.create!(:uid => GroupCreationNotificationToStudents.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    email_template.source = "#{email_template.source} {{url_signup}}"
    email_template.save!

    ChronusMailer.group_creation_notification_to_students(stu, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_no_match /Message from the administrator/, mail_content
    match_str = "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/users\/new_user_followup\?reset_code"
    assert_match match_str, mail_content
  end

  def test_group_termination_notification_because_of_inactivity
    group = groups(:mygroup)

    group.auto_terminate_due_to_inactivity!
    assert group.reload.closed_due_to_inactivity?
    ChronusMailer.group_termination_notification(users(:f_mentor), group.actor, group).deliver_now
    email = ActionMailer::Base.deliveries.last

    connection_term_lower_case = group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase

    assert_equal "Your #{connection_term_lower_case}, #{group.name} has come to a close", email.subject
    assert_equal users(:f_mentor).email, email.to.first
    assert_match(/This is an automated email/, get_html_part_from(email))
    assert_match "/contact_admin", get_html_part_from(email)
    assert_match "Auto-terminated due to inactivity", get_html_part_from(email)
    assert_match("You will be able to continue to access all the information inside the #{connection_term_lower_case}", get_html_part_from(email))
  end

  def test_group_reactivation_notification_to_mentor
    group = groups(:mygroup)
    assert_equal "the program test administrator", GroupReactivationNotification.mailer_attributes[:tags][:specific_tags][:administrator_or_owner_name][:example].call(programs(:albers))
    ChronusMailer.group_reactivation_notification(users(:f_mentor), group, users(:f_mentor)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "Your mentoring connection has been reactivated", email.subject
    assert_equal users(:f_mentor).email, email.to.first
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), get_html_part_from(email)
    assert_match /Your mentoring connection end date has also been changed to /, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_reactivation_notification_to_mentor_by_owner
    group = groups(:mygroup)
    make_user_owner_of_group(group, users(:f_mentor))
    ChronusMailer.group_reactivation_notification(users(:f_mentor), group, users(:f_mentor)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "Your mentoring connection has been reactivated", email.subject
    assert_equal users(:f_mentor).email, email.to.first
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), get_html_part_from(email)
  end

  def test_group_reactivation_notification_to_student
    group = groups(:mygroup)
    ChronusMailer.group_reactivation_notification(users(:mkr_student), group, users(:f_admin)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "Your mentoring connection has been reactivated", email.subject
    assert_equal users(:mkr_student).email, email.to.first
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), get_html_part_from(email)
    assert_match /Your mentoring connection end date has also been changed to/, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_inactivity_notification
    group = groups(:mygroup)

    # For mentor
    ChronusMailer.group_inactivity_notification(users(:f_mentor), group).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)

    assert_equal "Inactivity reminder: We've missed hearing from you!", email.subject
    assert_equal [users(:f_mentor).email], email.to
    assert_match users(:f_mentor).first_name, mail_content
    assert_match html_escape(group_url(group, :subdomain => 'primary', :root => 'albers', :src => 'mail', :activation => 1)), mail_content
    assert_match(/This is an automated email/, mail_content)
    assert_match "/p/albers/groups/1?src=mail\"", mail_content
    assert_match "Visit your mentoring connection area", mail_content
    assert_match "If you have any questions or concerns about your partnership or this software, please contact me", mail_content
    assert_match "/p/albers/contact_admin", mail_content

    # For student
    ChronusMailer.group_inactivity_notification(users(:mkr_student), group).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:mkr_student).email], email.to
  end

  def test_group_member_addition_notification_to_new_member_mentor_added
    group = groups(:mygroup)
    old_members_by_role = group.members_by_role
    add_users_to_group(group, [users(:mentor_3)], :mentor)

    ChronusMailer.group_member_addition_notification_to_new_member(users(:mentor_3), group, users(:f_admin), {message: "Added to the group"}).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You have been added as a test mentor to name & madankumarrajan", email.subject
    assert_equal [users(:mentor_3).email], email.to
    assert_match /Hi #{users(:mentor_3).first_name}/, get_html_part_from(email)
    assert_match_with_squeeze /indicated in your profile, you have been selected to join #{h group.name} as a test mentor/, get_html_part_from(email)
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), get_html_part_from(email)
    assert_match /#{old_members_by_role[:mentors].first.name}/, get_html_part_from(email)
    assert_match /Visit your mentoring connection area/, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_member_addition_notification_to_new_member_mentee_added
    allow_one_to_many_mentoring_for_program(programs(:albers))
    assert programs(:albers).reload.allow_one_to_many_mentoring?
    users(:f_mentor).update_attribute(:max_connections_limit, 5)
    assert_equal 5, users(:f_mentor).max_connections_limit

    group = groups(:mygroup)
    old_members_by_role = group.members_by_role
    add_users_to_group(group, [users(:student_3)], :student)

    member_addition_ra = RecentActivity.last
    ChronusMailer.group_member_addition_notification_to_new_member(users(:student_3), group, users(:f_admin), {message: "Please connect"}).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_match /Please connect/, mail_content
    assert_equal "You have been added as a test student to name & madankumarrajan", email.subject
    assert_equal [users(:student_3).email], email.to
    assert_match /Hi #{users(:student_3).first_name}/, mail_content
    assert_match_with_squeeze /indicated in your profile, you have been selected to join #{h group.name} as a test student/, get_html_part_from(email)
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), mail_content
    assert_match /Your mentoring connection will end on #{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}/, get_text_part_from(email)
    assert_match /Visit your mentoring connection area/, mail_content
    assert_match /#{group.mentors.first.name}/, mail_content
    assert_match(/This is an automated email/, mail_content)
  end

  def test_group_member_addition_notification_to_new_member_multiple_mentors_added
    group = groups(:mygroup)
    old_members_by_role = group.members_by_role
    add_users_to_group(group, [users(:mentor_3), users(:mentor_4), users(:mentor_5)], :mentor)

    ChronusMailer.group_member_addition_notification_to_new_member(users(:mentor_4), group, nil, {message: "Please connect"}).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You have been added as a test mentor to name & madankumarrajan", email.subject
    assert_equal [users(:mentor_4).email], email.to
    assert_match /Hi #{users(:mentor_4).first_name}/, get_html_part_from(email)
    assert_match_with_squeeze /indicated in your profile, you have been selected to join #{h group.name} as a test mentor/, get_html_part_from(email)
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), get_html_part_from(email)
    assert_match /Your mentoring connection will end on #{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}/, get_html_part_from(email)
    assert_match /Visit your mentoring connection area/, get_html_part_from(email)
    assert_match /#{old_members_by_role[:mentors].first.name}/, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_member_addition_notification_to_new_member_multiple_mentees_added
    allow_one_to_many_mentoring_for_program(programs(:albers))
    assert programs(:albers).reload.allow_one_to_many_mentoring?
    users(:f_mentor).update_attribute(:max_connections_limit, 5)
    assert_equal 5, users(:f_mentor).max_connections_limit

    group = groups(:mygroup)
    old_members_by_role = group.members_by_role
    add_users_to_group(group, [users(:student_3), users(:student_4), users(:student_5)], :student)

    ChronusMailer.group_member_addition_notification_to_new_member(users(:student_4), group, users(:f_admin)).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_no_match /Message from test administrator/, mail_content
    assert_equal "You have been added as a test student to name & madankumarrajan", email.subject
    assert_equal [users(:student_4).email], email.to
    assert_match /Hi #{users(:student_4).first_name}/, mail_content
    assert_match_with_squeeze /indicated in your profile, you have been selected to join #{h group.name} as a test student/, get_html_part_from(email)
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), mail_content
    assert_match /#{old_members_by_role[:mentees].first.name}/, mail_content
    assert_match /Visit your mentoring connection area/, mail_content
    assert_match(/This is an automated email/, mail_content)
  end

  def test_group_member_addition_notification_to_new_member_by_owner
    allow_one_to_many_mentoring_for_program(programs(:albers))
    assert programs(:albers).reload.allow_one_to_many_mentoring?
    users(:f_mentor).update_attribute(:max_connections_limit, 5)
    assert_equal 5, users(:f_mentor).max_connections_limit

    group = groups(:mygroup)
    old_members_by_role = group.members_by_role
    add_users_to_group(group, [users(:student_3), users(:student_4), users(:student_5)], :student)
    make_user_owner_of_group(group, users(:student_3))

    ChronusMailer.group_member_addition_notification_to_new_member(users(:student_4), group, users(:student_3)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You have been added as a test student to name & madankumarrajan", email.subject
    assert_equal [users(:student_4).email], email.to
    assert_match /Hi #{users(:student_4).first_name}/, get_html_part_from(email)
    assert_match_with_squeeze /indicated in your profile, you have been selected to join #{h group.name} as a test student/, get_html_part_from(email)
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), get_html_part_from(email)
    assert_match /#{old_members_by_role[:mentors].first.name}/, get_html_part_from(email)
    assert_match /#{old_members_by_role[:mentees].first.name}/, get_html_part_from(email)
    assert_match /Visit your mentoring connection area/, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_member_addition_notification_to_new_member_mentor_and_mentee_added_sent_to_mentor
    group = groups(:mygroup)
    old_members_by_role = group.members_by_role
    add_users_to_group(group, [users(:mentor_3)], :mentor)
    add_users_to_group(group, [users(:student_3)], :student)

    ChronusMailer.group_member_addition_notification_to_new_member(users(:mentor_3), group, users(:f_admin)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You have been added as a test mentor to name & madankumarrajan", email.subject
    assert_equal [users(:mentor_3).email], email.to
    assert_match /Hi #{users(:mentor_3).first_name}/, get_html_part_from(email)
    assert_match_with_squeeze /indicated in your profile, you have been selected to join #{h group.name} as a test mentor/, get_html_part_from(email)
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), get_html_part_from(email)
    assert_match /#{old_members_by_role[:mentors].first.name}/, get_html_part_from(email)
    assert_match /#{old_members_by_role[:mentees].first.name}/, get_html_part_from(email)
    assert_match /Visit your mentoring connection area/, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end


  def test_group_member_addition_notification_to_new_member_mentor_and_mentee_added_sent_to_mentee
    group = groups(:mygroup)
    old_members_by_role = group.members_by_role
    new_members = [users(:mentor_3), users(:student_3)]
    add_users_to_group(group, [users(:mentor_3)], :mentor)
    add_users_to_group(group, [users(:student_3)], :student)

    ChronusMailer.group_member_addition_notification_to_new_member(users(:student_3), group, users(:f_admin)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You have been added as a test student to name & madankumarrajan", email.subject
    assert_equal [users(:student_3).email], email.to
    assert_match /Hi #{users(:student_3).first_name}/, get_html_part_from(email)
    assert_match_with_squeeze /indicated in your profile, you have been selected to join #{h group.name} as a test student/, get_html_part_from(email)
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), get_html_part_from(email)
    assert_match /#{old_members_by_role[:mentors].first.name}/, get_html_part_from(email)
    assert_match /#{old_members_by_role[:mentees].first.name}/, get_html_part_from(email)
    assert_match /Visit your mentoring connection area/, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_member_removal_notification_to_removed_member_sent_to_mentor
    group = groups(:mygroup)
    old_members_by_role = group.members_by_role
    add_users_to_group(group, [users(:mentor_3)], :mentor)
    add_users_to_group(group, [users(:student_3)], :student)

    ChronusMailer.group_member_removal_notification_to_removed_member(users(:mentor_3), group, old_members_by_role, users(:f_admin)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You have been removed from name & madankumarrajan by the program test administrator", email.subject
    assert_equal [users(:mentor_3).email], email.to
    assert_match users(:mentor_3).first_name, get_html_part_from(email)
    assert_match_with_squeeze /You have been removed from .* by the program test administrator/, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
    contact_admin_url = "primary." + DEFAULT_DOMAIN_NAME + "/p/albers/contact_admin"
    assert_match contact_admin_url, get_html_part_from(email)
  end

  def test_group_member_removal_notification_to_removed_member_sent_to_mentor_by_owner
    group = groups(:mygroup)
    old_members_by_role = group.members_by_role
    add_users_to_group(group, [users(:mentor_3)], :mentor)
    add_users_to_group(group, [users(:student_3)], :student)

    make_user_owner_of_group(group, users(:student_3))

    ChronusMailer.group_member_removal_notification_to_removed_member(users(:mentor_3), group, old_members_by_role, users(:student_3)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You have been removed from name & madankumarrajan by #{users(:student_3).name(name_only: true)}", email.subject
    assert_equal [users(:mentor_3).email], email.to
    assert_match users(:mentor_3).first_name, get_html_part_from(email)
    assert_match_with_squeeze /You have been removed from .* by #{users(:student_3).name(name_only: true)}/, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_member_removal_notification_to_removed_member_sent_to_mentee
    group = groups(:mygroup)
    old_members_by_role = group.members_by_role
    add_users_to_group(group, [users(:mentor_3)], :mentor)
    add_users_to_group(group, [users(:student_3)], :student)

    ChronusMailer.group_member_removal_notification_to_removed_member(users(:student_3), group, old_members_by_role, users(:f_admin)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You have been removed from name & madankumarrajan by the program test administrator", email.subject
    assert_equal [users(:student_3).email], email.to
    assert_match users(:student_3).first_name, get_html_part_from(email)
    assert_match_with_squeeze /You have been removed from .* by the program test administrator/, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_member_removal_and_addition_notification
    group = groups(:mygroup)
    group.update_members([users(:f_mentor)], [users(:mkr_student)] + [users(:student_3)])
    old_members_by_role = group.reload.members_by_role
    group.update_members([users(:f_mentor)] + [users(:mentor_3)], [users(:mkr_student)])
    ChronusMailer.group_member_addition_notification_to_new_member(users(:mentor_3), group.reload, users(:f_admin)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You have been added as a test mentor to name & madankumarrajan", email.subject
    assert_equal [users(:mentor_3).email], email.to
    assert_match /Hi #{users(:mentor_3).first_name}/, get_html_part_from(email)
    assert_match_with_squeeze /indicated in your profile, you have been selected to join #{h group.name} as a test mentor/, get_html_part_from(email)
    assert_no_match /#{users(:student_3).name}/, get_html_part_from(email)
    assert_match /#{old_members_by_role[:mentees].first.name}/, get_html_part_from(email)
    assert_match /#{old_members_by_role[:mentors].first.name}/, get_html_part_from(email)
    match_str = "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/groups\/1"
    assert_match match_str,get_html_part_from(email)
    assert_match /Visit your mentoring connection area/, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  #####

  def test_group_mentoring_offer_added_notification_to_new_mentee
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    group = groups(:mygroup)
    mentee = group.students.first
    mentor = group.mentors.first

    ChronusMailer.group_mentoring_offer_added_notification_to_new_mentee(mentee, group, mentor, sender: mentor).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert group.program.organization.audit_user_communication?
    assert_equal [mentor.member.email], email.cc

    assert_equal "#{mentor.name} via #{group.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{mentor.name} via #{group.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "You have a new test mentor!", email.subject
    assert_equal [mentee.email], email.to
    assert_match /#{mentor.name}.* has added you to a new mentoring connection/, get_html_part_from(email)
    assert_match /Visit mentoring connection area/, get_text_part_from(email)
    assert_match /Start by reviewing initial tasks for both you and your test\nmentor/, get_text_part_from(email)
    match_str = "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/groups\/1"
    assert_match match_str,get_text_part_from(email)
    # Sender name is not visible
    mentor.expects(:visible_to?).returns(false)
    ChronusMailer.group_mentoring_offer_added_notification_to_new_mentee(mentee, group, mentor, sender: mentor).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{group.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{group.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    group.update_members([users(:f_mentor)] + [users(:mentor_3)], [users(:mkr_student)])
    group = group.reload
    mentee = group.students.first
    mentor = group.mentors.first
    ChronusMailer.group_mentoring_offer_added_notification_to_new_mentee(mentee, group, mentor).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_match /Start by reviewing initial tasks for both you and your test\nmentors/, get_text_part_from(email)
  end

  def test_group_mentoring_offer_added_notification_to_new_mentee_display_settings
    program = programs(:albers)
    # enable offer mentoring
    program.enable_feature(FeatureName::OFFER_MENTORING)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.mentor_offer_needs_acceptance?
    assert_false GroupMentoringOfferAddedNotificationToNewMentee.mailer_attributes[:program_settings].call(program)
    # mentor offer does not need acceptance
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert GroupMentoringOfferAddedNotificationToNewMentee.mailer_attributes[:program_settings].call(program)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false GroupMentoringOfferAddedNotificationToNewMentee.mailer_attributes[:program_settings].call(program)
  end

  def test_group_conversation_creation_notification
    program = programs(:albers)
    assert GroupConversationCreationNotification.mailer_attributes[:program_settings].call(program)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false GroupConversationCreationNotification.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    assert GroupConversationCreationNotification.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert GroupConversationCreationNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_group_mentoring_offer_notification_to_new_mentee_display_settings
    program = programs(:albers)
    # enable offer mentoring
    program.enable_feature(FeatureName::OFFER_MENTORING)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.mentor_offer_needs_acceptance?
    assert GroupMentoringOfferNotificationToNewMentee.mailer_attributes[:program_settings].call(program)
    # mentor offer does not need acceptance
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert_false GroupMentoringOfferNotificationToNewMentee.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false GroupMentoringOfferNotificationToNewMentee.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
  end

  def test_mentor_offer_accepted_notification_to_mentor_display_settings
    program = programs(:albers)
    # enable offer mentoring
    program.enable_feature(FeatureName::OFFER_MENTORING)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.mentor_offer_needs_acceptance?
    assert MentorOfferAcceptedNotificationToMentor.mailer_attributes[:program_settings].call(program)
    # mentor offer does not need acceptance
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert_false MentorOfferAcceptedNotificationToMentor.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorOfferAcceptedNotificationToMentor.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
  end

  def test_mentor_offer_closed_for_recipient_display_settings
    program = programs(:albers)
    assert_equal MentorOfferClosedForRecipient.mailer_attributes[:feature], FeatureName::OFFER_MENTORING
    # enable offer mentoring
    program.enable_feature(FeatureName::OFFER_MENTORING)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.mentor_offer_needs_acceptance?
    assert MentorOfferClosedForRecipient.mailer_attributes[:program_settings].call(program)
    # mentor offer does not need acceptance
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert_false MentorOfferClosedForRecipient.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorOfferClosedForRecipient.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
  end

  def test_mentor_offer_closed_for_sender_display_settings
    program = programs(:albers)
    assert_equal MentorOfferClosedForSender.mailer_attributes[:feature], FeatureName::OFFER_MENTORING
    # enable offer mentoring
    program.enable_feature(FeatureName::OFFER_MENTORING)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.mentor_offer_needs_acceptance?
    assert MentorOfferClosedForSender.mailer_attributes[:program_settings].call(program)
    # mentor offer does not need acceptance
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert_false MentorOfferClosedForSender.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorOfferClosedForSender.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
  end

  def test_mentor_offer_rejected_notification_to_mentor_display_settings
    program = programs(:albers)
    # enable offer mentoring
    program.enable_feature(FeatureName::OFFER_MENTORING)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.mentor_offer_needs_acceptance?
    assert MentorOfferRejectedNotificationToMentor.mailer_attributes[:program_settings].call(program)
    # mentor offer does not need acceptance
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert_false MentorOfferRejectedNotificationToMentor.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorOfferRejectedNotificationToMentor.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    example_text = MentorOfferRejectedNotificationToMentor.mailer_attributes[:tags][:specific_tags][:view_mentees_button][:example].call(program)
    assert_equal "View all test students →", ActionController::Base.helpers.strip_tags(example_text)
  end

  def test_mentor_offer_withdrawn_display_settings
    program = programs(:albers)
    assert_equal MentorOfferWithdrawn.mailer_attributes[:feature], FeatureName::OFFER_MENTORING
    # enable offer mentoring
    program.enable_feature(FeatureName::OFFER_MENTORING)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.mentor_offer_needs_acceptance?
    assert MentorOfferWithdrawn.mailer_attributes[:program_settings].call(program)
    # mentor offer does not need acceptance
    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert_false MentorOfferWithdrawn.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorOfferWithdrawn.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    example_text = MentorOfferWithdrawn.mailer_attributes[:tags][:specific_tags][:view_mentors_button][:example].call(program)
    assert_equal "View Test Mentors →", ActionController::Base.helpers.strip_tags(example_text)
  end

  def test_mentor_request_accepted_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.matching_by_mentee_alone?
    assert MentorRequestAccepted.mailer_attributes[:program_settings].call(program)

    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false MentorRequestAccepted.mailer_attributes[:program_settings].call(program)

    program.unstub(:matching_by_mentee_alone?)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorOfferWithdrawn.mailer_attributes[:program_settings].call(program)
  end

  def test_meeting_rsvp_notification_to_self_display_settings
    program = programs(:org_primary)

    program.stubs(:calendar_sync_enabled?).returns(false)
    assert_false program.calendar_sync_enabled?
    assert_false MeetingRsvpNotificationToSelf.mailer_attributes[:program_settings].call(program)

    program.stubs(:calendar_sync_enabled?).returns(true)
    assert MeetingRsvpNotificationToSelf.mailer_attributes[:program_settings].call(program)

    assert_equal [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING], MeetingRsvpNotificationToSelf.mailer_attributes[:feature]
  end

  def test_meeting_cancellation_notification_to_self_display_settings
    program = programs(:org_primary)

    program.stubs(:calendar_sync_enabled?).returns(false)
    assert_false program.calendar_sync_enabled?
    assert_false MeetingCancellationNotificationToSelf.mailer_attributes[:program_settings].call(program)

    program.stubs(:calendar_sync_enabled?).returns(true)
    assert MeetingCancellationNotificationToSelf.mailer_attributes[:program_settings].call(program)

    assert_equal [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING], MeetingCancellationNotificationToSelf.mailer_attributes[:feature]
  end

  def test_meeting_rsvp_sync_notification_failure_mail_display_settings
    program = programs(:org_primary)

    program.stubs(:calendar_sync_enabled?).returns(false)
    assert_false program.calendar_sync_enabled?
    assert_false MeetingRsvpSyncNotificationFailureMail.mailer_attributes[:program_settings].call(program)

    program.stubs(:calendar_sync_enabled?).returns(true)
    assert MeetingRsvpSyncNotificationFailureMail.mailer_attributes[:program_settings].call(program)

    assert_equal [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING], MeetingRsvpSyncNotificationFailureMail.mailer_attributes[:feature]
  end

  def test_meeting_edit_notification_to_self_display_settings
    program = programs(:org_primary)

    program.stubs(:calendar_sync_enabled?).returns(false)
    assert_false program.calendar_sync_enabled?
    assert_false MeetingEditNotificationToSelf.mailer_attributes[:program_settings].call(program)

    program.stubs(:calendar_sync_enabled?).returns(true)
    assert MeetingEditNotificationToSelf.mailer_attributes[:program_settings].call(program)

    assert_equal [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING], MeetingEditNotificationToSelf.mailer_attributes[:feature]
  end

  def test_mentor_request_closed_for_recipient_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.matching_by_mentee_alone?
    assert MentorRequestClosedForRecipient.mailer_attributes[:program_settings].call(program)

    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false MentorRequestClosedForRecipient.mailer_attributes[:program_settings].call(program)

    program.unstub(:matching_by_mentee_alone?)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorRequestClosedForRecipient.mailer_attributes[:program_settings].call(program)
  end

  def test_mentor_request_closed_for_sender_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.matching_by_mentee_alone?
    assert MentorRequestClosedForSender.mailer_attributes[:program_settings].call(program)

    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false MentorRequestClosedForSender.mailer_attributes[:program_settings].call(program)

    program.unstub(:matching_by_mentee_alone?)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorRequestClosedForSender.mailer_attributes[:program_settings].call(program)
    example_text = MentorRequestClosedForSender.mailer_attributes[:tags][:specific_tags][:view_mentors_button][:example].call(program)
    assert_equal "View Test Mentors →", ActionController::Base.helpers.strip_tags(example_text)
  end

  def test_mentor_request_rejected_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.matching_by_mentee_alone?
    assert_false program.matching_by_mentee_and_admin?
    assert MentorRequestRejected.mailer_attributes[:program_settings].call(program)

    program.stubs(:matching_by_mentee_and_admin?).returns(true)
    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert MentorRequestRejected.mailer_attributes[:program_settings].call(program)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorRequestRejected.mailer_attributes[:program_settings].call(program)
    example_text = MentorRequestRejected.mailer_attributes[:tags][:specific_tags][:view_mentors_button][:example].call(program)
    assert_equal "View Test Mentors →", ActionController::Base.helpers.strip_tags(example_text)
  end

  def test_mentor_requests_export_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.matching_by_mentee_alone?
    assert_false program.matching_by_mentee_and_admin?
    assert MentorRequestsExport.mailer_attributes[:program_settings].call(program)

    program.stubs(:matching_by_mentee_and_admin?).returns(true)
    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert MentorRequestsExport.mailer_attributes[:program_settings].call(program)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorRequestsExport.mailer_attributes[:program_settings].call(program)
  end

  def test_mentor_request_expired_to_sender_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.matching_by_mentee_alone?
    assert_false !program.mentor_request_expiration_days.nil?
    assert_false MentorRequestExpiredToSender.mailer_attributes[:program_settings].call(program)

    # set expiry limit for mentor request
    program.update_attribute(:mentor_request_expiration_days, 1)
    assert MentorRequestExpiredToSender.mailer_attributes[:program_settings].call(program)
    example_text = MentorRequestExpiredToSender.mailer_attributes[:tags][:specific_tags][:view_mentors_button][:example].call(program)
    assert_equal "View Test Mentors →", ActionController::Base.helpers.strip_tags(example_text)

    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false MentorRequestsExport.mailer_attributes[:program_settings].call(program)

    program.unstub(:matching_by_mentee_alone?)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorRequestsExport.mailer_attributes[:program_settings].call(program)
  end

  def test_mentor_request_reminder_notification_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.matching_by_mentee_alone?
    assert_false program.needs_mentoring_request_reminder?
    assert_false MentorRequestReminderNotification.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:needs_mentoring_request_reminder, true)
    assert MentorRequestReminderNotification.mailer_attributes[:program_settings].call(program)

    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false MentorRequestReminderNotification.mailer_attributes[:program_settings].call(program)

    program.unstub(:matching_by_mentee_alone?)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorRequestReminderNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_mentor_request_withdrawn_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.matching_by_mentee_alone?
    assert_false program.allow_mentee_withdraw_mentor_request?
    assert_false MentorRequestWithdrawn.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:allow_mentee_withdraw_mentor_request, true)
    assert MentorRequestWithdrawn.mailer_attributes[:program_settings].call(program)


    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false MentorRequestWithdrawn.mailer_attributes[:program_settings].call(program)
    program.unstub(:matching_by_mentee_alone?)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorRequestWithdrawn.mailer_attributes[:program_settings].call(program)
  end

  def test_mentor_request_withdrawn_to_admin_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert_false program.matching_by_mentee_and_admin?
    assert_false program.allow_mentee_withdraw_mentor_request?
    assert_false MentorRequestWithdrawnToAdmin.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:allow_mentee_withdraw_mentor_request, true)
    assert_false MentorRequestWithdrawnToAdmin.mailer_attributes[:program_settings].call(program)

    program.stubs(:matching_by_mentee_and_admin?).returns(true)
    assert MentorRequestWithdrawnToAdmin.mailer_attributes[:program_settings].call(program)

    program.unstub(:matching_by_mentee_and_admin?)
    assert_false MentorRequestWithdrawnToAdmin.mailer_attributes[:program_settings].call(program)
    program.stubs(:matching_by_mentee_and_admin?).returns(true)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false MentorRequestWithdrawnToAdmin.mailer_attributes[:program_settings].call(program)
  end

  def test_new_mentor_request_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.matching_by_mentee_alone?
    assert program.allow_mentoring_requests?
    assert NewMentorRequest.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:allow_mentoring_requests, false)
    assert_false NewMentorRequest.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:allow_mentoring_requests, true)

    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false NewMentorRequest.mailer_attributes[:program_settings].call(program)
  end

  def test_new_mentor_request_to_admin_display_settings
    program = programs(:albers)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert_false program.matching_by_mentee_and_admin?
    assert program.allow_mentoring_requests?
    assert_false NewMentorRequestToAdmin.mailer_attributes[:program_settings].call(program)

    program.stubs(:matching_by_mentee_and_admin?).returns(true)
    assert NewMentorRequestToAdmin.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:allow_mentoring_requests, false)
    assert_false NewMentorRequestToAdmin.mailer_attributes[:program_settings].call(program)
  end

  def test_not_eligible_to_join_notification_display_settings
    program = programs(:albers)

    assert_false program.has_allowing_join_with_criteria?
    assert_false NotEligibleToJoinNotification.mailer_attributes[:program_settings].call(program)

    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    role.update_attribute(:eligibility_rules, true)

    assert program.has_allowing_join_with_criteria?
    assert NotEligibleToJoinNotification.mailer_attributes[:program_settings].call(program)

    role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role.update_attribute(:eligibility_rules, true)

    assert program.has_allowing_join_with_criteria?
    assert NotEligibleToJoinNotification.mailer_attributes[:program_settings].call(program)
    example_text = NotEligibleToJoinNotification.mailer_attributes[:tags][:specific_tags][:roles_applied_for][:example].call(program)
    assert_equal "a test mentor", ActionController::Base.helpers.strip_tags(example_text)
  end

  def test_group_mentoring_offer_notification_to_new_mentee
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    group = groups(:mygroup)
    mentee = group.students.first
    mentor = group.mentors.first
    mentor_offer = create_mentor_offer(:mentor => mentor, :student => mentee)
    mentor_offer.group = groups(:mygroup)

    ChronusMailer.group_mentoring_offer_notification_to_new_mentee(mentee, mentor_offer, mentor, sender: mentor).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [mentor.member.email], email.cc
    assert program.organization.audit_user_communication?
    assert_equal "You have received a new offer for mentoring!", email.subject
    assert_equal [mentee.email], email.to
    assert_match /#{mentor.name}.* has offered to be your test mentor/, get_html_part_from(email)
    match_str = get_text_part_from(email).gsub(/\n/, " ")
    assert_match /If you think it is a good fit, please accept their offer as soon as possible/, match_str
    match_str = "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/mentor_offers"
    assert_match match_str,get_text_part_from(email)
    assert_match "View Offer", get_text_part_from(email)
  end


  def test_mentor_request_reminder_notification_to_not_raise_error_when_url_is_present_in_message
    program = programs(:albers)
    user = users(:f_mentor)

    mentor_request = user.received_mentor_requests.first
    mentor_request.update_attribute(:message, "asdfsf\r\nhttps://www.google.com\r\nThanks\r\ndanielsam\r\n")
    #Premailer if a stylesheet and a link is present at the start of the new line , we receive an error from the premailer gem which can cause a failure so made a hack to append spaces
    ChronusMailer.mentor_request_reminder_notification(mentor_request.student, mentor_request).deliver_now
    email = ActionMailer::Base.deliveries.last

    #Check if message is there
    assert_match /Thanks\ndanielsam/, get_html_part_from(email)
    assert_match /\n https:\/\/www.google.com/, get_html_part_from(email)
  end

  def test_meeting_request_reminder_notification_to_not_raise_error_when_url_is_present_in_description
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request

    meeting.update_attribute(:description, "asdfsf\r\nhttps://www.google.com\r\nThanks\r\ndanielsam\r\n")
    #Premailer if a stylesheet and a link is present at the start of the new line , we receive an error from the premailer gem which can cause a failure so made a hack to append spaces
    ChronusMailer.meeting_request_reminder_notification(users(:f_mentor), meeting_request).deliver_now
    email = ActionMailer::Base.deliveries.last

    #Check if description is there
    assert_match /Thanks\ndanielsam/, get_html_part_from(email)
    assert_match /\n https:\/\/www.google.com/, get_html_part_from(email)
  end

  def test_mentor_offer_closed_for_recipient_content
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    group = groups(:mygroup)
    mentee = group.students.first
    mentor = group.mentors.first
    mentor_offer = create_mentor_offer(:mentor => mentor, :student => mentee)
    mentor_offer.group = groups(:mygroup)
    mentor_offer.response = "I am closing your request."
    mentor_offer.closed_by = users(:f_admin)

    ChronusMailer.mentor_offer_closed_for_recipient(mentee, mentor_offer).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal "Test Administrator has closed #{mentor.name}'s mentoring offer", email.subject
    assert_match user_url(mentor, subdomain: program.organization.subdomain, root: program.root), email_content
    assert_match "I am closing your request.", email_content
    assert_match users(:f_admin).name, email_content
    assert_match "/contact_admin", email_content
  end

  def test_mentor_offer_accepted_notification_to_mentor
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    mentee = users(:f_student)
    mentor = users(:f_mentor)
    mentor_offer = create_mentor_offer(:mentor => mentor, :student => mentee)
    mentor_offer.group = groups(:mygroup)
    mentor.save!

    ChronusMailer.mentor_offer_accepted_notification_to_mentor(mentor, mentor_offer, sender: mentee).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert mentee.program.organization.audit_user_communication?
    assert_equal [mentee.email], email.cc
    assert_equal "#{mentor_offer.student.name} via #{mentor_offer.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{mentor_offer.student.name} via #{mentor_offer.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "student example has accepted to be your test student!", email.subject
    assert_equal [mentor.email], email.to
    assert_match /has accepted to be your test student in/, get_html_part_from(email)
    match_str = "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/groups\/1"
    assert_match match_str,get_html_part_from(email)
    assert_match "Visit mentoring connection area", get_html_part_from(email)
    # Sender name is not visible
    mentor_offer.student.expects(:visible_to?).returns(false)
    ChronusMailer.mentor_offer_accepted_notification_to_mentor(mentor, mentor_offer, sender: mentee).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{mentor_offer.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor_offer.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_mentor_offer_rejected_notification_to_mentor
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    mentee = users(:f_student)
    mentor = users(:f_mentor)
    mentor_offer = create_mentor_offer(:mentor => mentor, :student => mentee)

    ChronusMailer.mentor_offer_rejected_notification_to_mentor(mentor, mentor_offer, sender: mentee).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [mentee.email], email.cc
    assert_equal "#{mentor_offer.student.name} via #{mentor_offer.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{mentor_offer.student.name} via #{mentor_offer.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "#{mentee.name} has declined your mentoring offer", email.subject
    assert_equal [mentor.email], email.to
    assert_match /#{mentee.name}.* has declined your mentoring offer in/, get_html_part_from(email)
    assert_match "View all test students", get_html_part_from(email)
    # Sender name is not visible
    mentor_offer.student.expects(:visible_to?).returns(false)
    ChronusMailer.mentor_offer_rejected_notification_to_mentor(mentor, mentor_offer, sender: mentee).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{mentor_offer.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor_offer.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  #####
  def test_notification_email_to_mentor_group_member_links
    group = groups(:mygroup)
    assert group
    allow_one_to_many_mentoring_for_program(group.program)
    program = group.program
    assert_equal program.allow_one_to_many_mentoring, true
    users(:f_mentor).update_attribute(:max_connections_limit, 5)

    students = group.students
    assert_equal_unordered [users(:mkr_student)], students

    ChronusMailer.group_reactivation_notification(users(:f_mentor), group, users(:f_admin)).deliver_now
    email1 = ActionMailer::Base.deliveries.last
    assert_equal "Your mentoring connection has been reactivated", email1.subject
    assert_equal users(:f_mentor).email, email1.to.first
    assert_match /.*#{h group.name}.*/, get_html_part_from(email1)
    assert_match(/This is an automated email/, get_html_part_from(email1))

    group.update_members([users(:f_mentor)], [users(:f_mentor_student), users(:mkr_student)], users(:f_admin))
    students = group.students.reload
    assert_equal_unordered [users(:f_mentor_student), users(:mkr_student)], students

    ChronusMailer.group_reactivation_notification(users(:f_mentor), group, users(:f_admin)).deliver_now
    email2 = ActionMailer::Base.deliveries.last
    assert_equal "Your mentoring connection has been reactivated", email2.subject
    assert_equal users(:f_mentor).email, email2.to.first
    assert_match /.*#{h group.name}.*/, get_html_part_from(email2)
    assert_match(/This is an automated email/, get_html_part_from(email2))
  end

  def test_content_flagged_admin_notification_display_settings
    assert_equal ContentFlaggedAdminNotification.mailer_attributes[:feature], FeatureName::FLAGGING

    program = programs(:albers)

    program.enable_feature(FeatureName::ARTICLES, false)
    program.enable_feature(FeatureName::FORUMS, false)
    program.enable_feature(FeatureName::ANSWERS, false)

    assert_false ContentFlaggedAdminNotification.mailer_attributes[:program_settings].call(program)

    program.enable_feature(FeatureName::ARTICLES, true)

    assert ContentFlaggedAdminNotification.mailer_attributes[:program_settings].call(program)

    program.enable_feature(FeatureName::ARTICLES, false)
    program.enable_feature(FeatureName::FORUMS, true)

    assert ContentFlaggedAdminNotification.mailer_attributes[:program_settings].call(program)

    program.enable_feature(FeatureName::FORUMS, false)
    program.enable_feature(FeatureName::ANSWERS, true)

    assert ContentFlaggedAdminNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_qa_answer_notification
    qa_question = create_qa_question(:summary => %Q[How long do i have to file a civil lawsuit in the state of Texas??],
      :description => %Q[A lady hit me in a car accident], :user => users(:f_admin))
    qa_answer = create_qa_answer(:content => %Q[Texas has a two-year statute of limitations], :qa_question => qa_question)

    ChronusMailer.qa_answer_notification(users(:f_admin), qa_answer).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "#{qa_answer.user.name} via #{users(:f_admin).program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{qa_answer.user.name} via #{users(:f_admin).program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal qa_question.user.email, email.to.first
    assert_equal "New answer to '#{qa_question.summary}'", email.subject
    assert_match qa_question.summary, get_html_part_from(email)
    assert_match qa_question.description, get_html_part_from(email)
    assert_match qa_answer.content, get_html_part_from(email)
    assert_match "Mark Answer Helpful", get_html_part_from(email)
    assert_match "View All Responses", get_html_part_from(email)
    assert_match "?mark_helpful_answer_id=#{qa_answer.id}", get_html_part_from(email)

    # Some other guy (a follower of the question) gets the email
    ChronusMailer.qa_answer_notification(users(:f_student), qa_answer).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "New answer to '#{qa_question.summary}'", email.subject
    assert_match(/.*Click here.* to modify your notification settings.*/, get_html_part_from(email))
    assert_match(edit_member_url(members(:f_student), :section => MembersController::EditSection::SETTINGS, :subdomain => 'primary',:root => 'albers', focus_notification_tab: true, scroll_to: NOTIFICATION_SECTION_HTML_ID).gsub("&", "&amp;"), get_html_part_from(email))
    assert_match(/This is an automated email/, get_html_part_from(email))
    assert_match "Mark Answer Helpful", get_html_part_from(email)
    assert_match "View All Responses", get_html_part_from(email)
    assert_match qa_question_url(qa_question, :subdomain => 'primary'), get_html_part_from(email)

    # Sender name is not visible
    qa_answer.user.expects(:visible_to?).returns(false)
    ChronusMailer.qa_answer_notification(users(:f_admin), qa_answer).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{users(:f_admin).program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{users(:f_admin).program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_content_flagged_admin_notification_mail_content
    flagging_user = users(:f_student)
    admin = users(:f_admin)
    article = articles(:economy)
    flag = create_flag(content: article, user: flagging_user)

    ChronusMailer.content_flagged_admin_notification(admin, flag, sender: flag.user).deliver_now

    mail = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(mail)

    assert_equal [], mail.cc
    assert_false admin.program.organization.audit_user_communication?

    assert_match "#{flagging_user.name} has flagged content as inappropriate", mail.subject
    assert_match "Resolve", mail_content
    assert_match "has flagged the following article as inappropriate because:", mail_content
    assert_match flags_url(tab: Flag::Tabs::UNRESOLVED, subdomain: 'primary', root: 'albers'), mail_content
  end

  def test_content_flagged_admin_notification_mail_content_with_cc
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    flagging_user = users(:f_student)
    admin = users(:f_admin)
    article = articles(:economy)
    flag = create_flag(content: article, user: flagging_user)
    org = flag.user.program.organization

    ChronusMailer.content_flagged_admin_notification(admin, flag, sender: flag.user).deliver_now

    mail = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(mail)

    assert_equal [flag.user.member.email], mail.cc
    assert admin.program.organization.audit_user_communication?

    assert_match "#{flagging_user.name} has flagged content as inappropriate", mail.subject
    assert_match "Resolve", mail_content
    assert_match "has flagged the following article as inappropriate because:", mail_content
    assert_match flags_url(tab: Flag::Tabs::UNRESOLVED, subdomain: 'primary', root: 'albers'), mail_content
  end

  def test_article_comment_notification_mail_content
    programs(:nwen).organization.update_attribute(:audit_user_communication, true)
    publication = create_article_publication(articles(:economy), programs(:nwen))
    comment = Comment.create!(:publication => publication, :user => users(:f_student_nwen_mentor), :body => "Abc")

    ChronusMailer.article_comment_notification(users(:f_mentor_nwen_student), comment, sender: comment.user).deliver_now

    mail = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(mail)

    assert_equal [comment.user.email], mail.cc

    assert_equal "New comment on \"#{comment.article.title}\"!", mail.subject
    assert_match "Read Now!", mail_content
    assert_match "left a new comment on the article", mail_content
    assert_match article_url(comment.article, :anchor => "comment_#{comment.id}", :subdomain => 'primary'), mail_content
  end

  def test_user_activation_notification
    user = users(:f_student)
    user.state_changer = users(:f_admin)
    state_changer = users(:f_admin)

    ChronusMailer.user_activation_notification(user).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal user.email, email.to.first
    assert_match "Your account is now reactivated!", email.subject
    assert_match /Your account in.*#{user.program.name}.*has been reactivated./, get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_user_suspension_notification
    user = users(:f_student)
    user.state_changer = users(:f_admin)
    state_changer = users(:f_admin)
    user.state_change_reason = "Rejected due to spamming"

    ChronusMailer.user_suspension_notification(user).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_equal user.email, email.to.first
    assert_match "Your membership has been deactivated", email.subject
    assert_match "This is to inform you that the program test administrator has deactivated your membership in #{user.program.name}", mail_content
    assert_match user.state_change_reason, mail_content
    assert_match(/This is an automated email/, mail_content)
    assert_match "/p/albers/contact_admin", mail_content
    assert_match user.state_changer.name, mail_content
  end

  def test_demotion_notification
    prog = programs(:albers)
    student = users(:f_student)
    student.promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    demoter = users(:f_admin)

    ChronusMailer.demotion_notification(student, [RoleConstants::ADMIN_NAME], demoter, '').deliver_now
    @email = ActionMailer::Base.deliveries.last
    assert_equal users(:f_student).email, @email.to[0]
    assert_equal "\"#{demoter.name} via #{student.program.name}\" <#{MAILER_ACCOUNT[:email_address]}>", @email['from'].to_s
    assert_equal "\"#{demoter.name} via #{student.program.name}\" <#{MAILER_ACCOUNT[:email_address]}>", @email['sender'].to_s
    assert_match "Your role as a test administrator has been updated", @email.subject
    assert_match prog.name, get_html_part_from(@email)
    assert_match demoter.name(:name_only => true), get_html_part_from(@email)
    assert_match "a test administrator", get_html_part_from(@email)
    assert_no_match(/Test Administrator Message/, get_html_part_from(@email))
    assert_match(/This is an automated email/, get_html_part_from(@email))
    # Sender name is not visible
    demoter.expects(:visible_to?).returns(false)
    ChronusMailer.demotion_notification(student, [RoleConstants::ADMIN_NAME], demoter, '').deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{student.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{student.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_demotion_notification_multiple_roles
    prog = programs(:albers)
    mentor_student = users(:f_mentor_student)
    mentor_student.promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    demoter = users(:f_admin)

    ChronusMailer.demotion_notification(mentor_student, [RoleConstants::ADMIN_NAME, RoleConstants::STUDENT_NAME], demoter, 'some reason').deliver_now
    @email = ActionMailer::Base.deliveries.last
    assert_equal mentor_student.email, @email.to[0]
    assert_match "Your role as a test administrator and test student has been updated", @email.subject
    assert_match prog.name, get_html_part_from(@email)
    assert_match demoter.name(:name_only => true), get_html_part_from(@email)
    match_str =  get_text_part_from(@email).gsub(/\n/, " ")
    assert_match "has removed your role as a test administrator and test student in Albers Mentor Program", match_str
    assert_match "some reason", get_html_part_from(@email)
    assert_match(/This is an automated email/, get_html_part_from(@email))
  end

  def test_promotion_notification
    student = users(:f_student)
    promoter = users(:f_admin)
    student.promote_to_role!(RoleConstants::ADMIN_NAME, promoter)

    student.member.stubs(:can_signin?).returns(false)
    ChronusMailer.promotion_notification(student, [RoleConstants::ADMIN_NAME], promoter).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_equal student.email, email.to[0]
    assert_match "You are now a test administrator!", email.subject
    assert_match student.program.name, mail_content
    assert_match promoter.name(name_only: true), mail_content
    assert_match "test administrator", mail_content
    assert_match "This is an automated email", mail_content
    assert_match "/albers/users/new_user_followup?reset_code=", mail_content
    assert_match "Update Your Profile", mail_content
    assert_match /Please contact the test administrator.* if you have any questions./, mail_content
  end

  def test_promotion_notification_add_student_role_to_mentor
    mentor = users(:f_mentor)
    promoter = users(:f_admin)
    mentor.promote_to_role!([RoleConstants::STUDENT_NAME], promoter)

    ChronusMailer.promotion_notification(mentor, [RoleConstants::STUDENT_NAME], promoter, 'Test Reason').deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal mentor.email, email.to[0]
    assert_match "You are now a test student!", email.subject
    assert_match mentor.program.name, get_html_part_from(email)
    assert_match promoter.name(name_only: true), get_html_part_from(email)
    assert_match "student", get_html_part_from(email)
    assert_match "Test Reason", get_html_part_from(email)
    assert_match "first_visit=true", get_html_part_from(email)
    assert_match "This is an automated email", get_html_part_from(email)
  end

  def test_promotion_notification_add_mentor_and_student_roles_to_admin
    admin = users(:f_admin)
    promoter = users(:ram)
    admin.promote_to_role!([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], promoter)

    ChronusMailer.promotion_notification(admin, [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], promoter).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal admin.email, email.to[0]
    assert_match "You are now a test mentor and test student!", email.subject
    assert_match admin.program.name, get_html_part_from(email)
    assert_match promoter.name(name_only: true), get_html_part_from(email)
    assert_match "test mentor and test student", get_html_part_from(email)
    assert_no_match(/in addition to being a/, get_html_part_from(email))
    assert_match "first_visit=true", get_html_part_from(email)
    assert_match "This is an automated email", get_html_part_from(email)
  end

  def test_posting_in_mentoring_area_failure_due_to_group_closed_by_admin
    group = groups(:mygroup)
    user = users(:f_mentor)
    group.terminate!(users(:f_admin), "Test termination reason", group.program.permitted_closure_reasons.first.id)
    assert !group.auto_terminated?

    ChronusMailer.posting_in_mentoring_area_failure(user, group, "Subject", "Body").deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "Unable to post message: Subject", email.subject
    assert_equal users(:f_mentor).email, email.to.first
    assert_match h(group.name), get_html_part_from(email)
    assert_match group_url(group, :subdomain => 'primary', :root => 'albers'), get_html_part_from(email)
    assert_match "We're sorry, but we could not post your message because your", get_html_part_from(email)
    assert_match "has reached its expiration date on", get_html_part_from(email)
    assert_match /You still have access to the .*mentoring connection.*/, get_html_part_from(email)
    assert_match "you wish to extend or reactivate", get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_posting_in_meeting_area_failure_mail
    meeting = meetings(:f_mentor_mkr_student)
    user = users(:f_mentor)

    ChronusMailer.posting_in_meeting_area_failure(user, meeting, "Subject", "Body").deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "Unable to post message: Subject", email.subject
    assert_equal users(:f_mentor).email, email.to.first
    assert_match "or the user you are trying to contact is not part of the program", get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_mail_content_due_to_group_closed_by_admin
    group = groups(:mygroup)
    user = users(:f_mentor)
    group.terminate!(users(:f_admin), "Test termination reason", group.program.permitted_closure_reasons.first.id)
    assert !group.auto_terminated?

    ChronusMailer.group_termination_notification(user, group.actor, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    connection_term_upper_case = group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
    connection_term_lower_case = group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase
    admin_lower_case = group.program.organization.admin_custom_term.term_downcase
    assert_equal "Your #{connection_term_lower_case}, #{group.name} has come to a close", email.subject
    assert_no_match(/Auto-terminated due to inactivity/, get_html_part_from(email))
    assert_no_match(/#{connection_term_upper_case} has ended/, get_html_part_from(email))
    assert_no_match(/Closed due to #{user.name} leaving the #{connection_term_lower_case}/, get_html_part_from(email))
    assert_match("You will be able to continue to access all the information inside the #{connection_term_lower_case}", get_html_part_from(email))
    assert_match "If you wish to reactivate the #{connection_term_lower_case}, please contact the #{admin_lower_case}", get_html_part_from(email)
  end

  def test_mail_content_due_to_group_closed_by_mentor
    program = programs(:albers)
    user = users(:requestable_mentor)
    program.add_role_permission("mentor", "reactivate_groups")
    group = groups(:group_4)

    ChronusMailer.group_termination_notification(user, group.actor, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    connection_term_lower_case = group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase
    connection_term_upper_case = group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
    assert_equal "Your #{connection_term_lower_case}, #{group.name} has come to a close", email.subject
    assert_match "If you wish to reactivate the #{connection_term_lower_case}, please click below <br/>", get_html_part_from(email)
    assert_match "Reactivate #{connection_term_upper_case}", get_html_part_from(email)
    assert_match "groups/#{group.id}/fetch_reactivate?src=mail", get_html_part_from(email)
  end

  def test_mail_content_due_to_group_closed_because_of_member_leaving
    group = groups(:mygroup)
    program = group.program
    program.update_attributes(:allow_users_to_leave_connection => true)

    member = group.members.first.member
    user = member.users.first
    group.actor = user
    group.termination_reason = "I am done."
    group.terminate!(user, group.termination_reason, group.program.permitted_closure_reasons.first.id, Group::TerminationMode::LEAVING)

    ChronusMailer.group_termination_notification(user, group.actor, group)
    email = ActionMailer::Base.deliveries.last
    connection_term_upper_case = group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
    connection_term_lower_case = group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase
    admin_lower_case = group.program.organization.admin_custom_term.term

    assert_equal "Your #{connection_term_lower_case}, #{group.name} has come to a close", email.subject
    assert_no_match(/Auto-terminated due to inactivity/, get_html_part_from(email))
    assert_no_match(/#{connection_term_upper_case} has ended/, get_html_part_from(email))
    assert_match("Closed due to #{member.name} leaving the #{connection_term_lower_case}", get_html_part_from(email))
    assert_no_match(/has been closed by the program #{admin_lower_case}/, get_html_part_from(email))
  end

  def test_mail_content_due_to_group_closed_because_of_expiry
    group = groups(:mygroup)
    group.terminate!(nil, "The mentoring period has ended", group.program.permitted_closure_reasons.first.id, Group::TerminationMode::EXPIRY)
    assert group.reload.closed_due_to_expiry?
    assert group.auto_terminated?

    member = group.members.first.member
    user = member.users.first

    ChronusMailer.group_termination_notification(user, group.actor, group)
    email = ActionMailer::Base.deliveries.last
    connection_term_upper_case = group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
    connection_term_lower_case = group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase
    admin_lower_case = group.program.organization.admin_custom_term.term

    assert_equal "Your #{connection_term_lower_case}, #{group.name} has come to a close", email.subject
    assert_no_match(/Auto-terminated due to inactivity/, get_html_part_from(email))
    assert_match(/#{connection_term_upper_case} has ended/, get_html_part_from(email))
    assert_no_match(/Closed due to #{member.name} leaving the #{connection_term_lower_case}/, get_html_part_from(email))
    assert_no_match(/has been closed by the program #{admin_lower_case}/, get_html_part_from(email))
  end

  def test_announcement_notification_as_test_mail
    notification_list = "abc@example.com,bcd@example.com,efg@example.com"
    ann = programs(:albers).announcements.new(:title => "All should assemble in hall",
      :body => "blah blah blah\nThis is it", :wants_test_email => true,
      :notification_list_for_test_email => notification_list)

    ChronusMailer.announcement_notification(nil, ann, {:is_test_mail => true, :non_system_email => notification_list}).deliver_now

    @email = ActionMailer::Base.deliveries.last
    assert_equal notification_list.split(","), @email.to
    assert_equal "All should assemble in hall", @email.subject
    assert_match(/This is an automated email/, get_html_part_from(@email))
    assert_match(/Hi &lt;Username&gt;/, get_html_part_from(@email))
    assert_match(/View Announcement/, get_html_part_from(@email))
  end

  def test_announcement_notification_as_test_mail_to_user_in_system
    user = users(:f_student)
    notification_list = user.email
    ann = programs(:albers).announcements.new(:title => "All should assemble in hall",
      :body => "blah blah blah\nThis is it", :wants_test_email => true,
      :notification_list_for_test_email => notification_list)

    ann.program.mailer_template_enable_or_disable(AnnouncementNotification, true)
    ChronusMailer.announcement_notification(user, ann, {:is_test_mail => true}).deliver_now

    @email = ActionMailer::Base.deliveries.last
    assert_equal notification_list.split(","), @email.to
    assert_equal "All should assemble in hall", @email.subject
    assert_match(/This is an automated email/, get_html_part_from(@email))
    assert_match(/View Announcement/, get_html_part_from(@email))
    assert_match "Hi #{user.first_name}", get_html_part_from(@email)
  end

  def test_announcement_notification
    programs(:org_primary).default_program_domain.update_attribute(:domain, "albers.com")
    programs(:org_anna_univ).default_program_domain.update_attribute(:domain, "ceg.com")
    # Email for announcement creation to all
    assert_equal [users(:ceg_admin)], programs(:ceg).reload.admin_users
    ann = create_announcement(title: "All should assemble in hall", body: "blah blah blah\nThis is it",
      email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE , program: programs(:ceg), admin: users(:ceg_admin), recipient_role_names: programs(:albers).roles_without_admin_role.collect(&:name))
    mentor_announcement = create_announcement(
      title: "All test mentors should attend the meeting", body: 'blah blah blah',
      recipient_role_names: [RoleConstants::MENTOR_NAME], email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE ,
      program: programs(:ceg), admin: users(:ceg_admin))

    ann.program.mailer_template_enable_or_disable(AnnouncementNotification, true)
    ChronusMailer.announcement_notification(users(:sarat_mentor_ceg), ann).deliver_now

    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:sarat_mentor_ceg).email], email.to
    assert_equal "#{programs(:ceg).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:ceg).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "All should assemble in hall", email.subject
    assert_match "https://#{ann.program.organization.subdomain}.#{ann.program.organization.domain}/#{SubProgram::PROGRAM_PREFIX}ceg/announcements/#{ann.id}", get_html_part_from(email)
    assert_match "blah blah blah\nThis is it", get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
    assert_match "View Announcement", get_html_part_from(email)
    assert_match announcement_url(ann, :subdomain => 'annauniv'), get_html_part_from(email)

    # Email for announcement creation to mentors
    ChronusMailer.announcement_notification(users(:ceg_mentor), mentor_announcement).deliver_now

    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:ceg_mentor).email], email.to
    assert_equal "#{programs(:ceg).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:ceg).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "All test mentors should attend the meeting", email.subject
    assert_match "https://#{mentor_announcement.program.organization.subdomain}.#{mentor_announcement.program.organization.domain}/#{SubProgram::PROGRAM_PREFIX}ceg/announcements/#{mentor_announcement.id}", get_html_part_from(email)

    # Email for announcement update
    ann.update_attribute(:created_at, 2.days.ago)
    ann.program.mailer_template_enable_or_disable(AnnouncementUpdateNotification, true)
    ChronusMailer.announcement_update_notification(users(:ceg_mentor), ann).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:ceg_mentor).email], email.to
    assert_equal "#{programs(:ceg).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:ceg).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "Update: All should assemble in hall", email.subject
    assert_match(/.*Click here.* to modify your notification settings.*/, get_html_part_from(email))
    assert_match "View Announcement", get_html_part_from(email)
    assert_match announcement_url(ann, :subdomain => 'annauniv'), get_html_part_from(email)
  end

  def test_announcement_notification_with_attachment
    programs(:org_primary).default_program_domain.update_attribute(:domain, "albers.com")
    programs(:org_anna_univ).default_program_domain.update_attribute(:domain, "ceg.com")
    # Email for announcement creation to all
    assert_equal [users(:ceg_admin)], programs(:ceg).reload.admin_users
    ann = create_announcement(
      title: "All should assemble in hall", body: "blah blah blah\nThis is it",
      email_notification: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE , program: programs(:ceg), admin: users(:ceg_admin), recipient_role_names: programs(:albers).roles_without_admin_role.collect(&:name), attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    attachment_content = File.open(File.join('test/fixtures','files', 'some_file.txt')).read
    email = nil

    ann.program.mailer_template_enable_or_disable(AnnouncementNotification, true)
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      ChronusMailer.announcement_notification(users(:sarat_mentor_ceg), ann).deliver_now
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal [users(:sarat_mentor_ceg).email], email.to
    assert_equal "#{programs(:ceg).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:ceg).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "All should assemble in hall", email.subject
    assert_match "https://#{ann.program.organization.subdomain}.#{ann.program.organization.domain}/#{SubProgram::PROGRAM_PREFIX}ceg/announcements/#{ann.id}", get_html_part_from(email)
    assert_match "blah blah blah\nThis is it", get_html_part_from(email)
    assert_equal(1, email.attachments.size)
    assert_match(ann.attachment_file_name, email.attachments.first.filename)
    assert_match(/text\/plain/, email.attachments.first.content_type)
    assert_equal(attachment_content, ann.attachment.content)
  end

  def test_topic_notification
    program = programs(:albers)
    organization = program.organization
    program_domain = organization.default_program_domain
    organization.update_attribute(:audit_user_communication, true)
    program_domain.update_attribute(:domain, "albers.com")
    fetch_role(:albers, RoleConstants::STUDENT_NAME).remove_permission("view_mentors")

    student_user = users(:f_student)
    mentor_user = users(:f_mentor)
    forum = forums(:common_forum)
    topic_1 = create_topic(forum: forum, title: "Topic 1", user: student_user)
    topic_2 = create_topic(forum: forum, title: "Topic 2", user: mentor_user)

    assert_emails 2 do
      ChronusMailer.forum_topic_notification(mentor_user, topic_1, sender: topic_1.user).deliver_now
      ChronusMailer.forum_topic_notification(student_user, topic_2, sender: topic_2.user).deliver_now
    end
    emails = ActionMailer::Base.deliveries.last(2)

    email = emails[0]
    email_content_text = get_text_part_from(email).squish
    email_content_html = get_html_part_from(email).squish
    assert_equal [student_user.email], email.cc
    assert_equal [mentor_user.email], email.to
    assert_equal "#{topic_1.user.name} via #{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email["from"].to_s
    assert_equal "New Conversation in '#{forum.name}'", email.subject
    assert_match "Reply to conversation", email_content_html
    assert_match "#{topic_1.user.name} started a conversation 'Topic 1' in the forum '#{forum.name}'", email_content_text
    assert_match forum_topic_url(forum, topic_1, host: "albers.com", subdomain: 'primary', root: 'albers'), email_content_html
    assert_match(/This is an automated email/, get_html_part_from(email))

    email = emails[1]
    assert_equal [mentor_user.email], email.cc
    assert_equal [student_user.email], email.to
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "New Conversation in '#{forum.name}'", email.subject
  end

  def test_post_notification
    program = programs(:albers)
    organization = program.organization
    program_domain = organization.default_program_domain
    organization.update_attribute(:audit_user_communication, true)
    program_domain.update_attribute(:domain, "albers.com")
    fetch_role(:albers, RoleConstants::STUDENT_NAME).remove_permission("view_mentors")

    student_user = users(:f_student)
    mentor_user = users(:f_mentor)
    topic = create_topic(title: "Topic 1")
    post_1 = create_post(topic: topic, body: "Post 1", user: student_user, attachment: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    post_2 = create_post(topic: topic, body: "Post 2", user: mentor_user, ancestry: post_1.id)

    assert_emails 2 do
      ChronusMailer.forum_notification(mentor_user, post_1, sender: post_1.user).deliver_now
      ChronusMailer.forum_notification(student_user, post_2, sender: post_2.user).deliver_now
    end
    emails = ActionMailer::Base.deliveries.last(2)

    email = emails[0]
    email_content_text = get_text_part_from(email).squish
    email_content_html = get_html_part_from(email).squish
    assert_equal [student_user.email], email.cc
    assert_equal [mentor_user.email], email.to
    assert_equal "#{post_1.user.name} via #{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email["from"].to_s
    assert_equal "New Post in 'Topic 1'", email.subject
    assert_match "Read Post", email_content_html
    assert_match "#{post_1.user.name} posted in the conversation 'Topic 1' in the forum '#{topic.forum.name}'", email_content_text
    assert_no_match("Post 1", email_content_text)
    assert_match forum_topic_url(post_1.forum, topic, host: "albers.com", subdomain: 'primary', root: 'albers'), email_content_html
    assert_match(/This is an automated email/, get_html_part_from(email))

    email = emails[1]
    assert_equal [mentor_user.email], email.cc
    assert_equal [student_user.email], email.to
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "New Post in 'Topic 1'", email.subject
  end

  def test_group_conversation_creation_notification
    program = programs(:albers)
    group = groups(:mygroup)
    student_user = users(:mkr_student)
    mentor_user = users(:f_mentor)
    group.stubs(:active?).returns(true)
    group.stubs(:forum_enabled?).returns(true)

    group.create_group_forum
    topic_1 = create_topic(forum: group.forum, title: "Topic 1", user: student_user)
    topic_2 = create_topic(forum: group.forum, title: "Topic 2", user: mentor_user)

    assert_emails 2 do
      ChronusMailer.group_conversation_creation_notification(mentor_user, topic_1, sender: topic_1.user).deliver_now
      ChronusMailer.group_conversation_creation_notification(student_user, topic_2, sender: topic_2.user).deliver_now
    end
    emails = ActionMailer::Base.deliveries.last(2)

    email = emails[0]
    email_content_text = get_text_part_from(email).squish
    email_content_html = get_html_part_from(email).squish
    assert_equal [mentor_user.email], email.to
    assert_equal "#{topic_1.user.name} via #{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email["from"].to_s
    assert_equal "#{topic_1.user.name} posted in '#{group.name}'- Join the conversation!", email.subject
    assert_match "Reply to conversation", email_content_html
    assert_match "#{topic_1.user.name} ( https://primary.#{DEFAULT_HOST_NAME}/p/albers/users/#{topic_1.user.id} ) started a conversation 'Topic 1' in the mentoring connection", email_content_text
    assert_match(/This is an automated email/, get_html_part_from(email))

    email = emails[1]
    email_content_text = get_text_part_from(email).squish
    email_content_html = get_html_part_from(email).squish
    assert_equal [student_user.email], email.to
    assert_equal "#{topic_2.user.name} via #{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email["from"].to_s
    assert_equal "#{topic_2.user.name} posted in '#{group.name}'- Join the conversation!", email.subject
    assert_equal "#{topic_2.user.name} via #{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email["from"].to_s
    assert_equal "#{topic_2.user.name} posted in '#{group.name}'- Join the conversation!", email.subject
    assert_match "Reply to conversation", email_content_html
    assert_match "#{topic_2.user.name} ( https://primary.#{DEFAULT_HOST_NAME}/p/albers/users/#{topic_2.user.id} ) started a conversation 'Topic 2' in the mentoring connection", email_content_text
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_membership_request_not_accepted
    membership_request = create_membership_request(
      program: programs(:ceg),
      roles: [RoleConstants::MENTOR_NAME],
      status: MembershipRequest::Status::REJECTED
    )
    membership_request.member.update_attributes!(first_name: "A A", last_name: "B B")

    ChronusMailer.membership_request_not_accepted(membership_request).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert email.to[0].include?(membership_request.email)
    assert_equal "#{programs(:ceg).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:ceg).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_match(/Your membership request has been declined/, email.subject)
    assert_match(/Hi A A/, mail_content)
    assert_match(membership_request.program.name, mail_content)
    assert_match(/We are unable to accept your request at this time./, mail_content)
    assert_match(/This is an automated email/, mail_content)
    assert_match "p/ceg/contact_admin", mail_content
    assert_match "- #{membership_request.admin.name}", mail_content
  end

  def test_manager_notification
    user = users(:f_student)
    members(:f_admin).update_attributes!(first_name: "First Name", last_name: "Last Name")
    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME])
    question = programs(:org_primary).profile_questions.manager_questions.first
    manager = create_manager(user, question, first_name: "A A", last_name: "B B", email: "ram@example.com")

    ChronusMailer.manager_notification(manager, membership_request).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert email.to[0].include?(manager.email)
    mail_content = get_html_part_from(email)
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_match(/Information about #{membership_request.name}'s participation in #{programs(:albers).name}/, email.subject)
    assert_match(membership_request.program.name, mail_content)
    assert_match("Hi First Name", mail_content)
    assert_match(/This is to inform you that #{membership_request.name}, one of your direct reports/, mail_content)
    assert_match(/For any questions or concerns about this application, please contact the test administrator/, mail_content)
  end

  def test_notification_for_accepted_membership_request
    user = users(:f_student)
    program = user.program
    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME])
    membership_request.update_attributes(accepted_as: RoleConstants::MENTOR_NAME, status: MembershipRequest::Status::ACCEPTED, admin: users(:f_admin))

    user.member.stubs(:can_signin?).returns(false)
    assert_difference "Password.count" do
      ChronusMailer.membership_request_accepted(user, membership_request).deliver_now
    end
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert email.to.include?(membership_request.email)
    assert_equal "#{membership_request.admin.name(name_only: true)} via #{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{membership_request.admin.name(name_only: true)} via #{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_match "Your membership request has been accepted!", email.subject
    assert_match /Hi #{user.first_name},/, mail_content
    assert_match /#{membership_request.admin.name(name_only: true)} has accepted your request to join #{program.name}/, mail_content
    assert_match "This is an automated email", mail_content
    assert_match new_user_followup_users_url(subdomain: program.organization.subdomain, reset_code: Password.last.reset_code), mail_content
    assert_match "Login", mail_content

    # Sender name is not visible
    membership_request.admin.expects(:visible_to?).returns(false)
    assert_difference "Password.count" do
      ChronusMailer.membership_request_accepted(user, membership_request).deliver_now
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_admin_message_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    # Notification email is sent to the user
    message = messages(:second_admin_message)

    ChronusMailer.admin_message_notification(programs(:albers).admin_users.first, message, sender: message.sender_email).deliver_now

    email = ActionMailer::Base.deliveries.last
    # Verify email contents
    assert email.to[0].include?(users(:f_admin).email)
    assert_equal [message.sender_email], email.cc
    assert_equal "#{message.sender_name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{message.sender_name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal("#{message.subject}", email.subject)
    assert_match(/You have a .*message.* from Test User/, get_html_part_from(email))
    assert_no_match(/in #{programs(:albers).name}/, get_html_part_from(email))
    assert_match(/#{message.content}/, get_html_part_from(email))
    assert_no_match(/This is an automated email/, get_html_part_from(email))
    assert_match(/To respond to/, get_html_part_from(email))
    assert_match(/click reply to this email/, get_html_part_from(email))
    assert_match(/Reply/, get_html_part_from(email))
    assert_match(/is_inbox=true/, get_html_part_from(email))
    assert_match(/reply=true/, get_html_part_from(email))
    assert_no_match(/.*Click here.* to modify your notification settings.*/, get_html_part_from(email))
  end

  def test_admin_message_notification_existing_user
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    # Notification email is sent to the user
    message = messages(:first_admin_message)

    ChronusMailer.admin_message_notification(programs(:albers).admin_users.first, message, sender: message.sender_user).deliver_now

    email = ActionMailer::Base.deliveries.last
    assert_equal [message.sender.email], email.cc
    roles = RoleConstants.human_role_string(message.get_user(message.sender).role_names, :program => programs(:albers), :articleize => true, :no_capitalize => true)
    # Verify email contents
    assert email.to[0].include?(users(:f_admin).email)
    assert_equal "#{message.sender_name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{message.sender_name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal("#{message.subject}", email.subject)
    assert_match(/You have a .*message.* from .*student example/, get_html_part_from(email))
    assert_match(/#{message.content}/, get_html_part_from(email))
    assert_no_match(/This is an automated email/, get_html_part_from(email))
    assert_match(/To respond to/, get_html_part_from(email))
    assert_match(/Reply/, get_html_part_from(email))
    assert_match(/is_inbox=true/, get_html_part_from(email))
    assert_match(/reply=true/, get_html_part_from(email))
  end

  def test_new_admin_message_notification_reply_to_admin_for_auto_email
    p = programs(:albers)
    user = users(:f_mentor)
    admin_user = programs(:albers).admin_users.first
    content_with_newlines = "<p>Getting acquainted over the web can be quite convenient.</p>\n<p>Good luck!</p>"

    f_template = create_mentoring_model_facilitation_template

    message = nil
    assert_difference "AdminMessage.count" do
      message = AdminMessage.create_for_facilitation_message(f_template, user, members(:f_admin), user.groups.first)
    end

    reply_message = message.build_reply(user.member)
    reply_message.receivers = message.receivers
    reply_message.content = content_with_newlines
    reply_message.sender = members(:f_admin)
    reply_message.auto_email = true
    reply_message.group = message.group
    reply_message.save!

    email = ActionMailer::Base.deliveries.last
    assert reply_message.admin_to_registered_user?
    assert reply_message.auto_email?
    assert_match(/#{content_with_newlines}/, get_html_part_from(email))
  end

  def test_new_admin_message_notification_reply_to_admin_for_non_auto_email
    admin_user = programs(:albers).admin_users.first
    message = messages(:first_admin_message)
    content_with_newlines = "<p>Getting acquainted over the web can be quite convenient.</p>\n<p>Good luck!</p>"
    content_with_break = "<p>Getting acquainted over the web can be quite convenient.</p>\n<br><p>Good luck!</p>"
    escaped_content_with_break = "&lt;p&gt;Getting acquainted over the web can be quite convenient.&lt;/p&gt;<br/>&lt;p&gt;Good luck!&lt;/p&gt;"

    reply_message = message.build_reply(members(:f_admin))
    reply_message.content = content_with_newlines
    reply_message.sender = members(:f_admin)

    reply_message.save!

    email = ActionMailer::Base.deliveries.last
    assert reply_message.admin_to_registered_user?
    assert_false reply_message.auto_email?
    assert_no_match(/#{h(content_with_newlines)}/, get_html_part_from(email))
    assert_match(/#{escaped_content_with_break}/, get_html_part_from(email))
  end

  def test_new_message_to_offline_user_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    msg = messages(:second_admin_message)
    msg.sender_id = msg.program.admin_users.first.member_id
    offline_receiver = msg.offline_receiver
    offline_receiver.name = "Name Whatever"
    offline_receiver.email = "email@example.com"
    offline_receiver.save!
    msg.save!

    msg.offline_receiver.reload
    msg.reload

    ChronusMailer.new_message_to_offline_user_notification(msg, sender: msg.sender).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [msg.sender.email], email.cc

    assert email.to[0].include?(msg.offline_receiver.email)
    # Test the email
    assert_equal "#{msg.subject}", email.subject
    assert_equal "\"#{msg.sender.name}\" <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "\"#{msg.sender.name}\" <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_match /You have a message from Freakin Admin/, get_html_part_from(email)
    assert_match msg.content, get_html_part_from(email)
    assert_match contact_admin_url(:subdomain => msg.program.organization.subdomain, :root => msg.program.root), get_html_part_from(email)
    assert_match(/Hi Name/, get_html_part_from(email))
    assert_no_match(/This is an automated email/, get_html_part_from(email))
    assert_no_match(/To get your updates only once a day or a week,.*change your notification settings*/, get_html_part_from(email))
    assert_no_match(/.*Click here.* to modify your notification settings.*/, get_html_part_from(email))
    assert_match(/Reply/, get_html_part_from(email))
  end

  def test_new_message_to_offline_user_notification_while_replying_from_org_level
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    msg = messages(:second_admin_message)
    msg.program = programs(:org_primary)
    msg.sender_name = "Name Whatever"
    offline_receiver = msg.offline_receiver
    offline_receiver.name = "Name Whatever"
    offline_receiver.email = "email@example.com"
    offline_receiver.save!
    msg.save!

    assert_false msg.program.is_a?(Program)
    msg.offline_receiver.reload
    msg.reload

    ChronusMailer.new_message_to_offline_user_notification(msg, sender: msg.sender).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [], email.cc
    assert email.to[0].include?(msg.offline_receiver.email)
    # Test the email
    assert_equal "#{msg.subject}", email.subject
    assert_equal "#{msg.sender_name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{msg.sender_name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_match /You have a message from Name Whatever/, get_html_part_from(email)
    assert_match msg.content, get_html_part_from(email)
    assert_match contact_admin_url(:subdomain => msg.program.subdomain), get_html_part_from(email)
    assert_match(/Hi Name/, get_html_part_from(email))
    assert_no_match(/This is an automated email/, get_html_part_from(email))
    assert_no_match(/To get your updates only once a day or a week,.*change your notification settings*/, get_html_part_from(email))
    assert_no_match(/.*Click here.* to modify your notification settings.*/, get_html_part_from(email))
    assert_match(/Reply/, get_html_part_from(email))
  end

  def test_admin_message_reply_notification_to_user
    message = messages(:first_admin_message).build_reply(members(:ram))
    message.sender = members(:ram)
    message.subject = "hello"
    message.content = "Great"
    message.attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    attachment_content = File.open(File.join('test/fixtures','files', 'some_file.txt')).read
    message.save!

    to_user = message.get_user(message.reload.receivers[0])
    program = message.program
    program.organization.update_attribute(:audit_user_communication, true)

    # Create the notification email
    ChronusMailer.admin_message_notification(to_user, message, sender: message.sender_user).deliver_now
    email = ActionMailer::Base.deliveries.last
    # Test the email
    assert_equal [message.sender.email], email.cc
    assert_equal "#{message.subject}", email.subject
    assert_equal "#{message.sender_name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{message.sender_name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_match /You have a .*message.* from/, get_html_part_from(email)
    assert_match message.content, get_html_part_from(email)
    assert_no_match(/This is an automated email/, get_html_part_from(email))
    assert_match(/To respond to/, get_html_part_from(email))
    assert_equal(1, email.attachments.size)
    assert_match(message.attachment_file_name, email.attachments.first.filename)
    assert_match(/text\/plain/, email.attachments.first.content_type)
    assert_equal(attachment_content, message.attachment.content)
  end

  def test_signup_notification_for_admin
    program = programs(:albers)
    program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attribute :term, 'book'
    program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.update_attribute :term, 'car'
    ChronusMailer.welcome_message_to_admin(users(:f_admin)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal([users(:f_admin).email], mail.to)
    assert_equal("#{users(:f_admin).first_name}, welcome to #{program.name}!", mail.subject)
    assert_no_match(/Congratulations on creating .*#{users(:f_admin).program.name}/, get_html_part_from(mail))
    assert_match(/Congratulations! You are now a test administrator in Albers Mentor Program/, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_match(/Why custom user views are helpful/, get_html_part_from(mail))
    assert_match(/Measuring the health of your program/, get_html_part_from(mail))
    # assert_select_email do
    #   assert_select("font") do
    #     assert_select('a[href=?]', 'http://primary.test.host/p/albers/', :text => program.name)
    #   end

    #   # Invite mentors
    #   assert_select 'div' do
    #     assert_select 'img[src=?][height=?]',  "http://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/mentor.png", UserMailerHelper::SignupNotificationConstants::PICTURE_SIZE_HEIGHT
    #     assert_select 'a[href=?]', invite_users_url(:role => :mentors, :from => [RoleConstants::ADMIN_NAME], :subdomain => 'primary', :root => :albers), :text => "Invite books"
    #     assert_select 'a[href=?]', new_user_url(:role => RoleConstants::MENTOR_NAME, :subdomain => 'primary', :root => 'albers'), :text => "Directly add book profiles"
    #   end

    #   # Invite students
    #   assert_select 'div' do
    #     assert_select 'img[src=?][height=?]',  "http://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/mentee.png", UserMailerHelper::SignupNotificationConstants::PICTURE_SIZE_HEIGHT
    #     assert_select 'a[href=?]',  invite_users_url(:role => :students, :subdomain => 'primary', :root => :albers, :from => [RoleConstants::ADMIN_NAME]), :text => "Invite cars"
    #   end

    #   # Customize Profile forms of mentor and student
    #   assert_select 'div' do
    #     assert_select 'img[src=?][height=?]',  "http://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/program-settings.png", UserMailerHelper::SignupNotificationConstants::PICTURE_SIZE_HEIGHT
    #     assert_select 'a[href=?]', role_questions_url(:subdomain => 'primary', :root => :albers), :text => "profile form"
    #   end

    #   # Customize the program settings
    #   assert_select 'div' do
    #     assert_select 'img[src=?][height=?]',  "http://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/program.png", UserMailerHelper::SignupNotificationConstants::PICTURE_SIZE_HEIGHT
    #     assert_select 'a[href=?]',edit_program_url(:subdomain => 'primary', :root => :albers), :text => "Customize program"
    #   end
    # end
  end

  def test_promotion_notification_mail
    email_template = programs(:albers).mailer_templates.create!(:uid => PromotionNotification.mailer_attributes[:uid])

    custom_template = %Q[{{promoted_role}} welcome to the world of mentoring!!]
    email_template.update_attributes(:source => custom_template, :content_changer_member_id => 1, :content_updated_at => Time.now)

    user = users(:f_student)
    promoted_roles = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    promoted_by = users(:f_admin)

    ChronusMailer.promotion_notification(user, promoted_roles, promoted_by, '').deliver_now

    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal([users(:f_student).email], mail.to)
    assert_match(/test mentor and test student welcome to the world of mentoring!!/, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_signup_notification_for_admin_with_custom_erb
    email_template = programs(:org_primary).mailer_templates.create!(:uid => WelcomeMessageToAdmin.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)

    custom_template = %Q[{{customized_subprogram_term}} welcomes you to the world of mentoring!!]
    email_template.update_attributes(:source => custom_template)

    ChronusMailer.welcome_message_to_admin(users(:f_admin)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal([users(:f_admin).email], mail.to)
    assert_match("#{users(:f_admin).first_name}, welcome to Albers Mentor Program!", mail.subject)
    assert_match(/welcomes you to the world of mentoring!/, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_signup_notification_for_admin_with_custom_erb_at_subprogram
    email_template = programs(:org_primary).mailer_templates.create!(:uid => WelcomeMessageToAdmin.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    custom_template = %Q[{{customized_subprogram_term}} welcomes you to the universe]
    email_template.update_attributes(:source => custom_template)

    semail_template = programs(:albers).mailer_templates.create!(:uid => WelcomeMessageToAdmin.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    scustom_template = %Q[{{customized_subprogram_term}} welcomes you to the subprogram world]
    semail_template.update_attributes(:source => scustom_template)


    ChronusMailer.welcome_message_to_admin(users(:f_admin)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal([users(:f_admin).email], mail.to)
    assert_match("#{users(:f_admin).first_name}, welcome to Albers Mentor Program!", mail.subject)
    assert_match(/welcomes you to the subprogram world/, get_html_part_from(mail))
    assert_no_match(/universe/, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))

    ChronusMailer.welcome_message_to_admin(users(:moderated_admin)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:moderated_program).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{programs(:moderated_program).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal([users(:moderated_admin).email], mail.to)
    assert_match("Moderated, welcome to Moderated Program!", mail.subject)
    assert_match(/welcomes you to the universe/, get_html_part_from(mail))
    assert_no_match(/subprogram world/, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  # To test the content of the first email sent to student when groups moderated is true for the program
  def test_signup_notification_for_student_matching_done_by_mentee_and_admin
    ChronusMailer.welcome_message_to_mentee(users(:moderated_student)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal([users(:moderated_student).email], mail.to)
    assert_equal "#{programs(:moderated_program).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{programs(:moderated_program).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_match("#{users(:moderated_student).first_name}, welcome to #{programs(:moderated_program).name}", mail.subject)
    assert_match(/Welcome to Moderated Program! You are now a student./, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_match(/Login to Moderated Program/, get_html_part_from(mail))
    assert_match contact_admin_url(:subdomain => programs(:moderated_program).organization.subdomain, :root => programs(:moderated_program).root), get_html_part_from(mail)
  end

  def test_signup_notification_for_mentor_matching_done_by_mentee_and_admin
    ChronusMailer.welcome_message_to_mentor(users(:moderated_student)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal([users(:moderated_student).email], mail.to)
    assert_equal "#{programs(:moderated_program).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{programs(:moderated_program).name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_match("#{users(:moderated_student).first_name}, welcome to #{programs(:moderated_program).name}", mail.subject)
    assert_match(/Welcome to Moderated Program! You are now a mentor./, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_match(/Login to Moderated Program/, get_html_part_from(mail))
    assert_match contact_admin_url(:subdomain => programs(:moderated_program).organization.subdomain, :root => programs(:moderated_program).root), get_html_part_from(mail)
  end

  def test_mentor_added_notification
    user = users(:f_mentor)
    admin = users(:f_admin)
    program = user.program
    member = user.member
    reset_password = Password.create!(member: member)

    member.stubs(:can_signin?).returns(false)
    ChronusMailer.mentor_added_notification(user, admin, reset_password).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "\"#{admin.name} via #{program.name}\" <#{MAILER_ACCOUNT[:email_address]}>", mail["from"].to_s
    assert_equal "\"#{admin.name} via #{program.name}\" <#{MAILER_ACCOUNT[:email_address]}>", mail["sender"].to_s
    assert_equal "#{user.first_name}, #{admin.name(name_only: true)} (Test Administrator) invites you to join as a test mentor!", mail.subject
    assert_match admin.name(name_only: true), get_html_part_from(mail)
    assert_match program.name, get_html_part_from(mail)
    assert_match "https://primary.#{DEFAULT_HOST_NAME}", get_html_part_from(mail)
    assert_match "This is an automated email", get_html_part_from(mail)
    assert_match /<a.*href=\"https:\/\/primary.#{DEFAULT_HOST_NAME}\/p\/#{program.root}\/users\/new_user_followup\?reset_code=#{reset_password.reset_code}/, get_html_part_from(mail)

    # Sender name is not visible
    admin.expects(:visible_to?).returns(false)
    member.stubs(:can_signin?).returns(true)
    ChronusMailer.mentor_added_notification(user, admin, reset_password).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail["from"].to_s
    assert_match "/#{program.root}/members/#{member.id}/edit", get_html_part_from(mail)
  end

  def test_admin_added_directly_notification
    user = users(:f_admin)
    program = user.program
    member = user.member

    member.stubs(:can_signin?).returns(false)
    reset_password = Password.create!(member: member)
    ChronusMailer.admin_added_directly_notification(user, user, reset_password).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "\"#{user.name} via #{program.name}\" <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "\"#{user.name} via #{program.name}\" <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_match "#{user.name} invites you to be a test administrator!", mail.subject
    assert_match user.name(name_only: true), get_html_part_from(mail)
    assert_match program.name, get_html_part_from(mail)
    assert_match "https://primary." + DEFAULT_HOST_NAME, get_html_part_from(mail)
    assert_match "This is an automated email", get_html_part_from(mail)
    assert_match "#{user.name} has invited you to join #{program.name} as a test administrator", get_html_part_from(mail)
    assert_match "Accept and sign up", get_html_part_from(mail)
    assert_select_helper_function "a[href=\"https://primary.#{DEFAULT_HOST_NAME}/p/#{program.root}/users/new_user_followup?reset_code=#{reset_password.reset_code}\"]", get_html_part_from(mail)

    # Sender name is not visible
    user.expects(:visible_to?).returns(false)
    member.stubs(:can_signin?).returns(true)
    ChronusMailer.admin_added_directly_notification(user, user, reset_password).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_match "/#{program.root}/members/#{member.id}/edit", get_html_part_from(mail)
  end

  def test_mentee_added_notification
    user = users(:f_student)
    admin = users(:f_admin)
    program = user.program
    member = user.member
    reset_password = Password.create!(member: member)

    member.stubs(:can_signin?).returns(false)
    ChronusMailer.mentee_added_notification(user, admin, reset_password).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "\"#{admin.name} via #{program.name}\" <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "\"#{admin.name} via #{program.name}\" <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal "#{user.first_name}, #{admin.name} invites you to join as a test student!", mail.subject
    assert_match admin.name, get_html_part_from(mail)
    assert_match program.name, get_html_part_from(mail)
    assert_match program_root_path(root: program.root, subdomain: 'primary'), get_html_part_from(mail)
    assert_match "This is an automated email", get_html_part_from(mail)
    assert_match "Accept and sign up", get_html_part_from(mail)
    assert_match "/contact_admin", get_html_part_from(mail)
    assert_match "It is important that you review and complete your profile. A detailed profile helps find better matches in the program.", get_html_part_from(mail)
    assert_match /<a.*href=\"https:\/\/primary.#{DEFAULT_HOST_NAME}\/p\/#{program.root}\/users\/new_user_followup\?reset_code=#{reset_password.reset_code}/, get_html_part_from(mail)

    # signed up user
    member.stubs(:can_signin?).returns(true)
    ChronusMailer.mentee_added_notification(user, admin, reset_password).deliver_now
    assert_match "/#{program.root}/members/#{member.id}/edit", get_html_part_from(ActionMailer::Base.deliveries.last)
  end

  def test_mentor_request_accepted
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.mark_accepted!
    mentor_request.program.organization.update_attribute(:audit_user_communication, true)

    ChronusMailer.mentor_request_accepted(student, mentor_request, {sender: mentor_request.mentor}).deliver_now
    mail = ActionMailer::Base.deliveries.last

    assert_equal [mentor_request.mentor.email], mail.cc
    assert_equal([student.email], mail.to)
    assert_equal "#{mentor.name} via #{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.name} via #{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal("#{mentor.name} has accepted to be your test mentor!", mail.subject)
    assert_match(/#{mentor.name}.* has accepted your mentoring request in .*#{mentor.program.name}/, get_html_part_from(mail))
    assert_match(/Contacting.*#{mentor.name}.*directly and introducing yourself to them/, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_match(/This mentoring connection, #{h mentor_request.group.name}, will end on #{formatted_time_in_words(mentor_request.group.expiry_time, :no_ago => true, :no_time => true)}/, get_html_part_from(mail))

    # Sender name is not visible
    mentor.expects(:visible_to?).returns(false)
    ChronusMailer.mentor_request_accepted(student, mentor_request, {sender: mentor_request.mentor}).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [mentor_request.mentor.email], mail.cc
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_mentor_request_rejected
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.program.organization.update_attribute(:audit_user_communication, true)

    mentor_request.update_attribute(:status, AbstractRequest::Status::REJECTED)
    selected_mentors = [{:member=>members(:f_mentor_student), :user=>users(:f_mentor_student), :slots_availabile_for_mentoring=>3, :max_score=>50, :recommendation_score=>50, :recommended_for=>"ongoing"},
                        {:member=>members(:ram), :user=>users(:ram), :slots_availabile_for_mentoring=>nil, :max_score=>60, :recommendation_score=>50, :recommended_for=>"ongoing"}]
    MentorRecommendationsService.any_instance.stubs(:get_recommendations_for_mail).returns(selected_mentors)
    MentorRecommendationsService.any_instance.stubs(:get_match_info_for).with(selected_mentors).returns([["Accounting Management"], ["Female"]])
    MentorRecommendationsService.any_instance.stubs(:show_view_favorites_button?).returns(false)
    ChronusMailer.mentor_request_rejected(student, mentor_request, {sender: mentor}).deliver_now
    mail = ActionMailer::Base.deliveries.last

    assert_equal([mentor.email], mail.cc)
    assert_equal([student.email], mail.to)
    assert_equal "#{mentor.name} via #{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.name} via #{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal("Request a new test mentor - #{mentor.name} is unavailable at this time", mail.subject)
    assert_match(/#{mentor.name}.* was unable to accept your request for mentoring./, get_html_part_from(mail))
    assert_match(/That's ok! There are still plenty of great test mentors who are eager to help. Connect now to find a new test mentor./, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_match(/Recommendations based on your profile/,  get_html_part_from(mail))
    assert_match(/Connect/,  get_html_part_from(mail))
    assert_match(/View more Test Mentors &rarr;/,  get_html_part_from(mail))
    assert_match(/Mentor Studenter/,  get_html_part_from(mail))
    assert_match(/Kal Raman/,  get_html_part_from(mail))
    assert_match(/Your compatibility/,  get_html_part_from(mail))
    assert_match(/Accounting Management/,  get_html_part_from(mail))
    assert_match(/Female/,  get_html_part_from(mail))
    assert_match(/50% match/,  get_html_part_from(mail))
    assert_match(/60% match/,  get_html_part_from(mail))
    assert_no_match(/star.png/,  get_html_part_from(mail))
    assert_no_match(/View Favorites/,  get_html_part_from(mail))

    # Sender name is not visible
    mentor_request.mentor.expects(:visible_to?).returns(false)
    ChronusMailer.mentor_request_rejected(student, mentor_request, {sender: mentor}).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal([mentor.email], mail.cc)
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_mentor_request_rejected_no_recommendations
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.program.organization.update_attribute(:audit_user_communication, true)

    mentor_request.update_attribute(:status, AbstractRequest::Status::REJECTED)

    User.any_instance.stubs(:can_view_mentors?).returns(false)
    selected_mentors = []
    MentorRecommendationsService.any_instance.stubs(:get_recommendations).returns(selected_mentors)
    ChronusMailer.mentor_request_rejected(student, mentor_request, {sender: mentor}).deliver_now

    mail = ActionMailer::Base.deliveries.last
    assert_equal([mentor.email], mail.cc)
    assert_equal([student.email], mail.to)
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal("Request a new test mentor - #{mentor.name} is unavailable at this time", mail.subject)
    assert_match(/#{mentor.name}.* was unable to accept your request for mentoring./, get_html_part_from(mail))
    assert_match(/That's ok! There are still plenty of great test mentors who are eager to help. Connect now to find a new test mentor./, get_html_part_from(mail))
    assert_match contact_admin_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_no_match(/Recommendations based on your profile/,  get_html_part_from(mail))
    assert_no_match(/View more Test Mentors →/,  get_html_part_from(mail))
    assert_no_match(/Mentor Studenter/,  get_html_part_from(mail))
    assert_no_match(/Kal Raman/,  get_html_part_from(mail))
    assert_no_match(/Your compatibility/,  get_html_part_from(mail))
  end

  def test_mentor_request_rejected_no_recommendations_cant_view_mentors
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.program.organization.update_attribute(:audit_user_communication, true)

    mentor_request.update_attribute(:status, AbstractRequest::Status::REJECTED)

    User.any_instance.stubs(:can_view_mentors?).returns(false)
    ChronusMailer.mentor_request_rejected(student, mentor_request, {sender: mentor}).deliver_now

    mail = ActionMailer::Base.deliveries.last
    assert_equal([mentor.email], mail.cc)
    assert_equal([student.email], mail.to)
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_match(/That's ok! There are still plenty of great test mentors who are eager to help. Connect now to find a new test mentor./, get_html_part_from(mail))
    assert_equal("Request a new test mentor - #{mentor.name} is unavailable at this time", mail.subject)
    assert_match(/#{mentor.name}.* was unable to accept your request for mentoring./, get_html_part_from(mail))
    assert_match contact_admin_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_no_match(/Recommendations based on your profile/,  get_html_part_from(mail))
    assert_no_match(/View more Test Mentors &rarr;/,  get_html_part_from(mail))
    assert_no_match(/Mentor Studenter/,  get_html_part_from(mail))
    assert_no_match(/Kal Raman/,  get_html_part_from(mail))
    assert_no_match(/You match on/,  get_html_part_from(mail))
  end

  def test_mentor_request_rejected_admin_recommendations
    mentor = users(:f_mentor)
    mentor_request = create_mentor_request(:program => programs(:albers), :student => users(:rahim), :mentor => mentor)
    student = mentor_request.student
    mentor_request.program.organization.update_attribute(:audit_user_communication, true)

    mentor_request.update_attribute(:status, AbstractRequest::Status::REJECTED)

    User.any_instance.stubs(:can_view_mentors?).returns(false)
    Program.any_instance.stubs(:mentor_recommendation_enabled?).returns(true)
    ChronusMailer.mentor_request_rejected(student, mentor_request, {sender: mentor}).deliver_now

    mail = ActionMailer::Base.deliveries.last
    assert_equal([mentor.email], mail.cc)
    assert_equal([student.email], mail.to)
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_match(/That's ok! There are still plenty of great test mentors who are eager to help. Connect now to find a new test mentor./, get_html_part_from(mail))
    assert_equal("Request a new test mentor - #{mentor.name} is unavailable at this time", mail.subject)
    assert_match(/#{mentor.name}.* was unable to accept your request for mentoring./, get_html_part_from(mail))
    assert_match contact_admin_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_match(/Recommendations based on your profile/,  get_html_part_from(mail))
    assert_no_match(/View more Test Mentors &rarr;/,  get_html_part_from(mail))
    assert_no_match(/robert user/,  get_html_part_from(mail))
    assert_match(/Kal Raman/,  get_html_part_from(mail))
  end

  def test_mentor_request_withdrawn
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.status = AbstractRequest::Status::WITHDRAWN
    mentor_request.response_text = "Test withdraw"
    mentor_request.save!
    mentor_request.program.organization.update_attribute(:audit_user_communication, true)

    ChronusMailer.mentor_request_withdrawn(mentor, mentor_request, {sender: mentor_request.student}).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [mentor.email], mail.to
    assert_equal [student.email], mail.cc
    assert_equal "#{student.name} via #{student.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{student.name} via #{student.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal "#{student.name} has withdrawn their mentoring request", mail.subject
    assert_match /#{student.name} has withdrawn their request for mentoring sent to you in .*#{mentor.program.name}.*/, get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))

    # Sender name is not visible
    mentor_request.student.expects(:visible_to?).returns(false)
    ChronusMailer.mentor_request_withdrawn(mentor, mentor_request, {}).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [], mail.cc
    assert_equal "#{student.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{student.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_mentor_request_closed_for_sender
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.status = AbstractRequest::Status::CLOSED
    mentor_request.closed_at = Time.now
    mentor_request.closed_by = mentor.program.admin_users.first
    mentor_request.response_text = "Test close"
    mentor_request.save!

    ChronusMailer.mentor_request_closed_for_sender(student, mentor_request).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [student.email], mail.to
    assert_equal "#{mentor_request.closed_by.name(:name_only => true)} via #{student.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor_request.closed_by.name(:name_only => true)} via #{student.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal "Test Administrator has closed your mentoring request", mail.subject
    assert_match /Your request for mentoring sent to .*#{mentor.name}.* in .*#{mentor.program.name}.* has been closed by the test administrator/, get_html_part_from(mail)
    assert_match(/Test close/, get_html_part_from(mail))
    assert_match users_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match("We have many other great test mentors available (who align with some of your intended goals and objectives) for you to choose from", get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_mentor_request_closed_for_sender_with_no_reason
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.status = AbstractRequest::Status::CLOSED
    mentor_request.closed_at = Time.now
    mentor_request.closed_by = mentor.program.admin_users.first
    mentor_request.save!

    ChronusMailer.mentor_request_closed_for_sender(student, mentor_request).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [student.email], mail.to
    assert_equal "#{users(:f_admin).name(:name_only => true)} via #{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{users(:f_admin).name(:name_only => true)} via #{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_no_match(/Test close/, get_html_part_from(mail))
    assert_equal "#{mentor_request.closed_by.name(:name_only => true)} via #{student.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor_request.closed_by.name(:name_only => true)} via #{student.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal "Test Administrator has closed your mentoring request", mail.subject
    assert_match /Your request for mentoring sent to .*#{mentor.name}.* in .*#{mentor.program.name}.* has been closed by the test administrator/, get_html_part_from(mail)
    assert_match users_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match("We have many other great test mentors available (who align with some of your intended goals and objectives) for you to choose from", get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_mentor_request_closed_for_recipient
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.status = AbstractRequest::Status::CLOSED
    mentor_request.response_text = "Test close"
    mentor_request.closed_at = Time.now
    mentor_request.closed_by = users(:f_admin)
    mentor_request.save!

    ChronusMailer.mentor_request_closed_for_recipient(mentor, mentor_request).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [mentor.email], mail.to
    assert_equal "#{users(:f_admin).name(:name_only => true)} via #{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{users(:f_admin).name(:name_only => true)} via #{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal "The mentoring request from #{student.name} is now closed", mail.subject
    assert_match "Test close", get_html_part_from(mail)
    assert_match(/We have closed .*#{student.name}.*'s request for mentoring in .*#{student.program.name}/, get_html_part_from(mail))
    assert_match contact_admin_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match /If this is an error and you intended to accept student example's request, please.*contact.*the test administrator immediately/, get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))

    # Sender name is not visible
    mentor_request.closed_by.expects(:visible_to?).returns(false)
    ChronusMailer.mentor_request_closed_for_recipient(mentor, mentor_request).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end


  def test_mentor_request_closed_for_recipient_with_no_reason
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.status = AbstractRequest::Status::CLOSED
    mentor_request.closed_at = Time.now
    mentor_request.closed_by = users(:f_admin)
    mentor_request.save!

    ChronusMailer.mentor_request_closed_for_recipient(mentor, mentor_request).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [mentor.email], mail.to
    assert_equal "#{users(:f_admin).name(:name_only => true)} via #{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{users(:f_admin).name(:name_only => true)} via #{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal "The mentoring request from #{student.name} is now closed", mail.subject
    assert_match(/We have closed .*#{student.name}.*'s request for mentoring in .*#{student.program.name}/, get_html_part_from(mail))
    assert_no_match(/Test close/, get_html_part_from(mail))
    assert_match contact_admin_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match /If this is an error and you intended to accept #{student.name}'s request, please.*contact.*the test administrator immediately./, get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_mentor_request_expired_to_sender
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.status = AbstractRequest::Status::CLOSED
    mentor_request.response_text = 'feature.mentor_request.tasks.expired_message_v1'.translate(mentor: _mentor, expiration_days: 10)
    mentor_request.closed_at = Time.now
    mentor_request.closed_by = mentor.program.admin_users.first
    mentor_request.save!

    program = mentor.program
    program.mentor_request_expiration_days = 10
    program.save!
    mentor_request.reload

    selected_mentors = [{:member=>members(:f_mentor_student), :user=>users(:f_mentor_student), :slots_availabile_for_mentoring=>3, :max_score=>50, :recommendation_score=>50, :recommended_for=>"ongoing", is_favorite: true},
                        {:member=>members(:ram), :user=>users(:ram), :slots_availabile_for_mentoring=>nil, :max_score=>60, :recommendation_score=>50, :recommended_for=>"ongoing"}]
    MentorRecommendationsService.any_instance.stubs(:get_recommendations_for_mail).returns(selected_mentors)
    MentorRecommendationsService.any_instance.stubs(:get_match_info_for).with(selected_mentors).returns([["Accounting Management"], ["Female"]])
    MentorRecommendationsService.any_instance.stubs(:show_view_favorites_button?).returns(true)

    ChronusMailer.mentor_request_expired_to_sender(mentor_request.student, mentor_request).deliver_now

    mail = ActionMailer::Base.deliveries.last
    assert_equal [student.email], mail.to
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal "Request a new test mentor - #{mentor.name} is unavailable at this time", mail.subject
    assert_match(/Your request for mentoring sent to .*#{mentor.name}.* in #{mentor.program.name} has been closed/, get_html_part_from(mail))
    assert_match contact_admin_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match users_url(:subdomain => 'primary'), get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_match(/has been closed because it was not accepted within 10 days/, get_html_part_from(mail))
    assert_match(/Recommendations based on your profile/,  get_html_part_from(mail))
    assert_match(/Connect/,  get_html_part_from(mail))
    assert_match(/View more Test Mentors &rarr;/,  get_html_part_from(mail))
    assert_match(/Mentor Studenter/,  get_html_part_from(mail))
    assert_match(/Kal Raman/,  get_html_part_from(mail))
    assert_match(/Your compatibility/,  get_html_part_from(mail))
    assert_match(/Accounting Management/,  get_html_part_from(mail))
    assert_match(/Female/,  get_html_part_from(mail))
    assert_match(/50% match/,  get_html_part_from(mail))
    assert_match(/60% match/,  get_html_part_from(mail))
    assert_match(/star.png/,  get_html_part_from(mail))
    assert_match(/View Favorites/,  get_html_part_from(mail))
  end

  def test_mentor_request_expired_to_sender_no_recommendations
    mentor_request = create_mentor_request
    student = mentor_request.student
    mentor = mentor_request.mentor
    mentor_request.status = AbstractRequest::Status::CLOSED
    mentor_request.response_text = 'feature.mentor_request.tasks.expired_message_v1'.translate(mentor: _mentor, expiration_days: 10)
    mentor_request.closed_at = Time.now
    mentor_request.closed_by = mentor.program.admin_users.first
    mentor_request.save!

    program = mentor.program
    program.mentor_request_expiration_days = 10
    program.save!
    mentor_request.reload

    User.any_instance.stubs(:can_view_mentors?).returns(false)
    selected_mentors = []
    MentorRecommendationsService.any_instance.stubs(:get_recommendations).returns(selected_mentors)
    ChronusMailer.mentor_request_expired_to_sender(mentor_request.student, mentor_request).deliver_now

    mail = ActionMailer::Base.deliveries.last
    assert_equal [student.email], mail.to
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal "Request a new test mentor - #{mentor.name} is unavailable at this time", mail.subject
    assert_match(/Your request for mentoring sent to .*#{mentor.name}.* in #{mentor.program.name} has been closed/, get_html_part_from(mail))
    assert_match contact_admin_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match users_url(:subdomain => 'primary'), get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_match(/has been closed because it was not accepted within 10 days/, get_html_part_from(mail))
    assert_no_match(/Recommendations based on your profile/,  get_html_part_from(mail))
    assert_no_match(/View more Test Mentors →/,  get_html_part_from(mail))
    assert_no_match(/Mentor Studenter/,  get_html_part_from(mail))
    assert_no_match(/Kal Raman/,  get_html_part_from(mail))
    assert_no_match(/Your compatibility/,  get_html_part_from(mail))
  end

  def test_mentor_request_rejected_matching_done_by_mentee_and_admin
    mentor_request = create_mentor_request(:program => programs(:moderated_program), :student => users(:moderated_student))
    mentor_request.program.organization.update_attribute(:audit_user_communication, true)
    student = mentor_request.student

    mentor_request.rejector = users(:moderated_admin)
    mentor_request.status = AbstractRequest::Status::REJECTED
    mentor_request.response_text = "Test text"
    mentor_request.save!

    ChronusMailer.mentor_request_rejected(student, mentor_request, {:rejector => mentor_request.rejector, sender: mentor_request.rejector}).deliver_now
    mail = ActionMailer::Base.deliveries.last

    assert_equal([mentor_request.rejector.email], mail.cc)
    assert_equal([student.email], mail.to)
    assert_equal "\"#{mentor_request.rejector.name} via #{programs(:moderated_program).name}\" <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "\"#{mentor_request.rejector.name} via #{programs(:moderated_program).name}\" <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal("Request a new mentor - #{mentor_request.rejector.name} is unavailable at this time", mail.subject)
    assert_match(/was unable to accept your request for mentoring./, get_html_part_from(mail))
    assert_match(/Test text/, get_html_part_from(mail))
    assert_match(/.*Click here.* to modify your notification settings.*/, get_html_part_from(mail))
    assert_match(/Recommendations based on your profile/, get_html_part_from(mail))
    assert_match(/Connect/, get_html_part_from(mail))
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_mentor_request_withdrawn_matching_done_by_mentee_and_admin
    program = programs(:moderated_program)
    program.organization.update_attribute(:audit_user_communication, true)
    student = users(:moderated_student)
    mentor_request = create_mentor_request(:program => program , :student => student)
    mentor_request.status = AbstractRequest::Status::WITHDRAWN
    mentor_request.response_text = "Test withdrawn"
    mentor_request.save!

    ChronusMailer.mentor_request_withdrawn_to_admin(mentor_request.receivers.first, mentor_request, {sender: mentor_request.student}).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal [users(:moderated_admin).email], mail.to
    assert_equal [mentor_request.student.email], mail.cc
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_match /#{student.name} has withdrawn their request to get a mentor assigned/, get_html_part_from(mail)
  end

  # This for the groups moderated scenario
  def test_new_mentor_request_matching_done_by_mentee_and_admin
    make_member_of(:moderated_program, :f_student)
    mentor_request = create_mentor_request(:student => users(:f_student), :program => programs(:moderated_program))
    programs(:moderated_program).organization.update_attribute(:audit_user_communication, true)

    ChronusMailer.new_mentor_request_to_admin(mentor_request.receivers.first, mentor_request, {sender: mentor_request.student}).deliver_now

    mail = ActionMailer::Base.deliveries.last
    assert_equal([users(:moderated_admin).email], mail.to)
    assert_equal([mentor_request.student.email], mail.cc)
    assert_equal "#{users(:f_student).name} via #{users(:f_student).program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{users(:f_student).name} via #{users(:f_student).program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_match(/#{users(:f_student).name} requested that you assign them a mentor in .*#{programs(:moderated_program).name}.*/, get_html_part_from(mail))

    # Sender name is not visible
    users(:f_student).expects(:visible_to?).returns(false)
    ChronusMailer.new_mentor_request_to_admin(mentor_request.receivers.first, mentor_request, {sender: mentor_request.student}).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal([mentor_request.student.email], mail.cc)
    assert_equal "#{users(:f_student).program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{users(:f_student).program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_new_article_notification
    a = create_article

    ChronusMailer.new_article_notification(users(:f_admin), a).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{a.author.name} via #{users(:f_admin).program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal([users(:f_admin).email], mail.to)
    assert_equal("New #{_article} posted by Good unique name!", mail.subject)
    assert_match(article_url(a, :subdomain => 'primary', :root => 'albers'), get_html_part_from(mail))
    assert_match /has published a new article titled/, get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))

    # Sender name is not visible
    User.any_instance.expects(:visible_to?).returns(false)
    ChronusMailer.new_article_notification(users(:f_admin), a).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{users(:f_admin).program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{users(:f_admin).program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_new_article_notification_with_custom_erb
    a = articles(:economy)
    example_text = NewArticleNotification.mailer_attributes[:tags][:specific_tags][:view_article_button][:example].call(programs(:albers))
    assert_equal "Read article →", ActionController::Base.helpers.strip_tags(example_text)
    email_template = programs(:albers).mailer_templates.where(:uid => NewArticleNotification.mailer_attributes[:uid]).first
    email_template.source = %Q[<a href="{{url_author_profile}}">{{author_name}}</a> wrote an exam! <br /> <a href="{{url_article}}">View {{customized_article_term}} &raquo;</a>]
    email_template.content_changer_member_id = 1
    email_template.content_updated_at = Time.now
    email_template.save!

    ChronusMailer.new_article_notification(users(:f_admin), a).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal([users(:f_admin).email], mail.to)
    assert_equal("New #{_article} posted by #{users(:f_admin).name}!", mail.subject)
    assert_match(article_url(a, :subdomain => 'primary', :root => 'albers'), get_html_part_from(mail))
    assert_match /wrote an exam/, get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
  end

  def test_article_comment_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    article = create_article(:subdomain => programs(:org_primary).subdomain, :root => programs(:albers).root)

    # Watchers at this point. The new commenter should not be included and hence
    # we are freezing the collection.
    publication = article.publications.first
    watchers = publication.watchers.dup.freeze
    assert_difference("Comment.count", 1) do
      # All watchers should get email.
      assert_difference "ActionMailer::Base.deliveries.size", watchers.size do
        Comment.create(:publication => publication, :user => users(:f_student), :body => "Abc")
      end
    end

    mails = ActionMailer::Base.deliveries.last(watchers.size)
    assert_equal [Comment.last.user.email], mails.collect(&:cc).flatten.uniq
    assert_equal_unordered watchers.collect(&:email), mails.collect(&:to).flatten
    assert_match(/New comment on \"Test title\"!/, mails[0].subject)
    assert_match(/on the #{_article}/, get_html_part_from(mails[0]))
    assert_match(/This is an automated email/, get_html_part_from(mails[0]))
  end

 def test_membership_requests_export
    admin = programs(:albers).admin_users.first
    csv_file_name = "report.csv"

    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      ChronusMailer.membership_requests_export(admin, csv_file_name, "test123").deliver_now
    end
    email = ActionMailer::Base.deliveries.last

    assert_equal([admin.email], email.to)
    assert_equal("Membership requests report", email.subject)
    assert_equal(1, email.attachments.size)
    assert_match(csv_file_name, email.attachments.first.filename)
    assert_match(/text\/csv/, email.attachments.first.content_type)
    assert_match(/Please find attached the membership requests report you requested./, get_html_part_from(email))

    pdf_file_name = "report.pdf"
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      ChronusMailer.membership_requests_export(admin, pdf_file_name, "test123").deliver_now
    end
    email = ActionMailer::Base.deliveries.last

    assert_equal([admin.email], email.to)
    assert_equal("Membership requests report", email.subject)
    assert_equal(1, email.attachments.size)
    assert_match(pdf_file_name, email.attachments.first.filename)
    assert_match(/application\/pdf/, email.attachments.first.content_type)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_mentor_requests_export
    admin = programs(:albers).admin_users.first
    csv_file_name = "report.csv"

    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      ChronusMailer.mentor_requests_export(admin, csv_file_name, "test123").deliver_now
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal([admin.email], email.to)
    assert_equal("Your mentoring requests report is here!", email.subject)
    assert_equal(1, email.attachments.size)
    assert_match(csv_file_name, email.attachments.first.filename)
    assert_match(/text\/csv/, email.attachments.first.content_type)
    assert_match(/The mentoring requests report is attached to this email./, get_text_part_from(email))

    pdf_file_name = "report.pdf"
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      ChronusMailer.mentor_requests_export(admin, pdf_file_name, "test123").deliver_now
    end
    email = ActionMailer::Base.deliveries.last

    assert_equal([admin.email], email.to)
    assert_equal("Your mentoring requests report is here!", email.subject)
    assert_equal(1, email.attachments.size)
    assert_match(pdf_file_name, email.attachments.first.filename)
    assert_match(/application\/pdf/, email.attachments.first.content_type)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_mentoring_area_export_pdf
    mentor = groups(:mygroup).mentors.first
    pdf_file_name = "report.pdf"

    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      ChronusMailer.mentoring_area_export(mentor, groups(:mygroup), pdf_file_name, "test123").deliver_now
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal([mentor.email], email.to)
    assert_equal("Exported PDF file for name & madankumarrajan", email.subject)
    assert_equal(1, email.attachments.size)
    assert_match(pdf_file_name, email.attachments.first.filename)
    assert_match(/application\/pdf/, email.attachments.first.content_type)
    assert_match(/The name &amp; madankumarrajan mentoring connection information you exported is attached to this email as a PDF./, get_html_part_from(email))
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_mentoring_area_export_zip
    mentor = groups(:mygroup).mentors.first
    zip_file_name = "report.zip"

    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      ChronusMailer.mentoring_area_export(mentor, groups(:mygroup), zip_file_name, "test123").deliver_now
    end
    email = ActionMailer::Base.deliveries.last

    assert_equal([mentor.email], email.to)
    assert_equal("Exported PDF file for name & madankumarrajan", email.subject)
    assert_equal(1, email.attachments.size)
    assert_match(zip_file_name, email.attachments.first.filename)
    assert_match(/application\/zip/, email.attachments.first.content_type)
    assert_match(/The name &amp; madankumarrajan mentoring connection information you exported is attached to this email as a PDF./, get_html_part_from(email))
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_group_inactivity_notification_with_auto_terminate
    student = groups(:mygroup).students.first
    group = groups(:mygroup)

    ChronusMailer.group_inactivity_notification_with_auto_terminate(student, group).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_equal email.to.first, student.member.email
    assert_equal "Inactivity reminder: We've missed hearing from you!", email.subject
    assert_match /#{group.name}/, get_text_part_from(email)
    assert_match "Visit your mentoring connection area", get_html_part_from(email)
    assert_match "Did you know that you've been inactive for more than", get_html_part_from(email)
    assert_match "/contact_admin", get_html_part_from(email)
    match_str = "https:\/\/primary\." + DEFAULT_HOST_NAME + "\/p\/albers\/groups\/#{group.id}\?activation=1&amp;src=mail"
    assert_match match_str, get_html_part_from(email)
  end

  # We have overridden Mustache not to escape html even though if the tag is not enclosed within triple brackets. Look for mustache_overrides.rb
  def test_mustache_should_not_escape_html
    html_content = '<html></html>'.html_safe
    rendered_templated_content = Mustache.render('{{tag}}', :tag => html_content)
    assert_equal html_content, rendered_templated_content
  end

  def test_preview_email
    uid = AdminAddedNotification.mailer_attributes[:uid]
    mailer_template = Mailer::Template.new(:uid => uid, :source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}")

    AdminAddedNotification.preview(users(:f_admin), members(:f_admin), programs(:albers), programs(:org_primary), mailer_template_obj: mailer_template).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_equal email.to.first, users(:f_admin).email
    assert_equal "Subject #{programs(:org_primary).name}", email.subject
    assert_match /#{programs(:org_primary).name}/, get_text_part_from(email)
    assert_match /Yours sincerely/, get_text_part_from(email)
  end

  def test_reactivate_account
    organization = programs(:org_primary)
    member = members(:f_admin)
    password = Password.create!(:member => member)

    ChronusMailer.reactivate_account(password, organization).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)

    assert_equal([member.email], email.to)
    assert_equal("Reactivate Your Account", email.subject)
    assert_match html_escape(change_password_url(:subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain, :reactivate_account => true, :reset_code => password.reset_code)), mail_content
    assert_match(/This is an automated email/, mail_content)
    assert_match "Reactivate Account", mail_content
    assert_match "/contact_admin", mail_content
  end

  def test_new_program_event_notification
    ChronusMailer.new_program_event_notification(users(:ram), program_events(:birthday_party)).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_match("Invitation: Birthday Party on", email.subject)
    assert_match program_event_url(program_events(:birthday_party), :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain), get_html_part_from(email)
    assert_match html_escape(update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::YES, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)), get_html_part_from(email)
    assert_match html_escape(update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::NO, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)), get_html_part_from(email)
    assert_match html_escape(update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::MAYBE, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)), get_html_part_from(email)

    assert_match(/You've been invited/, get_html_part_from(email))
    assert_match(/invites you to attend #{program_events(:birthday_party).title}/, get_html_part_from(email))
    assert_match(/Yes, I will attend/, get_html_part_from(email))
    assert_match(/No, I will not attend/, get_html_part_from(email))
    assert_match(/Maybe, I might attend/, get_html_part_from(email))
  end

  def test_new_program_event_notification_program_display_settings
    assert_equal NewProgramEventNotification.mailer_attributes[:feature], FeatureName::PROGRAM_EVENTS
  end

  def test_program_event_delete_notification_display_settings
    assert_equal ProgramEventDeleteNotification.mailer_attributes[:feature], FeatureName::PROGRAM_EVENTS
  end

  def test_program_event_reminder_notification_display_settings
    assert_equal ProgramEventReminderNotification.mailer_attributes[:feature], FeatureName::PROGRAM_EVENTS
  end

  def test_program_event_update_notification_display_settings
    assert_equal ProgramEventUpdateNotification.mailer_attributes[:feature], FeatureName::PROGRAM_EVENTS
  end

  def test_program_event_update_notification
    ChronusMailer.program_event_update_notification(users(:ram), program_events(:birthday_party)).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_match("Update: Birthday Party", email.subject)
    assert_match program_event_url(program_events(:birthday_party), :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain), get_html_part_from(email)
    assert_match html_escape(update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::YES, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)), get_html_part_from(email)
    assert_match html_escape(update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::NO, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)), get_html_part_from(email)
    assert_match html_escape(update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::MAYBE, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)), get_html_part_from(email)

    assert_match(/has updated some of the following program event details/, get_html_part_from(email))
    assert_match(/Yes, I will attend/, get_html_part_from(email))
    assert_match(/No, I will not attend/, get_html_part_from(email))
    assert_match(/Maybe, I might attend/, get_html_part_from(email))
    assert_match(/This is an automated email/, get_html_part_from(email))
    assert_match(/View Event Details/, get_html_part_from(email))
  end

  def test_email_report_mailer_template_description
    program = programs(:albers)
    assert_match("This email is sent when a test administrator shares a survey report with users both internal and external to the program", EmailReport.mailer_attributes[:description].call(program))
  end

  def test_program_event_delete_notification
    program_events(:birthday_party).destroy
    email = ActionMailer::Base.deliveries.last
    assert_no_match /program_event_url(program_events(:birthday_party), :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)/, get_html_part_from(email)

    assert_match("Cancelled Invitation: Birthday Party", email.subject)
    assert_match(/The event, Birthday Party/, get_html_part_from(email))
    assert_match(/#{DateTime.localize(program_events(:birthday_party).start_time.in_time_zone(members(:ram).get_valid_time_zone), format: "full_display_no_time_with_day".to_sym)}/, get_html_part_from(email))
    assert_match(/#{program_events(:birthday_party).location}/, get_html_part_from(email))
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_program_event_reminder_notification
    ChronusMailer.program_event_reminder_notification(users(:ram), program_events(:birthday_party)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_match program_event_url(program_events(:birthday_party), :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain), get_html_part_from(email)

    assert_match(/Reminder: #{program_events(:birthday_party).title} on/, email.subject)
    assert_match("This is to remind you of the upcoming event, #{program_events(:birthday_party).title}", get_html_part_from(email))
    assert_match(/IST/, get_html_part_from(email))
    assert_match(/This is an automated email/, get_html_part_from(email))
    assert_match(/View Event Details/, get_html_part_from(email))
  end

  def test_program_event_reminder_notification_with_time_zone_validation
    event = program_events(:birthday_party)
    user = users(:ram)
    member = user.member
    member.time_zone = ""
    member.save!
    event.time_zone = ""
    event.save!

    ChronusMailer.program_event_reminder_notification(user, event).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_match program_event_url(program_events(:birthday_party), :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain), get_html_part_from(email)
    assert_match(/UTC/, get_html_part_from(email))

    event.time_zone = "Asia/Kolkata"
    event.save!

    ChronusMailer.program_event_reminder_notification(user, event).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_match program_event_url(program_events(:birthday_party), :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain), get_html_part_from(email)
    assert_match(/IST/, get_html_part_from(email))

    member.time_zone ="Asia/Tokyo"
    member.save!

    ChronusMailer.program_event_reminder_notification(user, event).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_match program_event_url(program_events(:birthday_party), :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain), get_html_part_from(email)
    assert_match(/JST/, get_html_part_from(email))
  end

  def test_new_program_event_notification_as_test_mail
    event = program_events(:birthday_party)
    event.notification_list_for_test_email = "test1@test.com"
    ChronusMailer.new_program_event_notification(nil, event, {:test_mail => true, :email => "test1@test.com"}).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_equal ["test1@test.com"], email.to
    assert_match("Invitation: Birthday Party on", email.subject)
    assert_no_match /program_event_url(program_events(:birthday_party), :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)/, get_html_part_from(email)
    assert_no_match /update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::YES, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)/, get_html_part_from(email)
    assert_no_match /update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::NO, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)/, get_html_part_from(email)
    assert_no_match /update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::MAYBE, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)/, get_html_part_from(email)

    assert_match(/#{event.user.name(:name_only => true)}.* invites you to attend #{event.title}/, get_html_part_from(email))
    assert_match(//, get_html_part_from(email))
    assert_match(/IST/, get_html_part_from(email))
    assert_match(/Let us know that you're attending!/, get_html_part_from(email))
    assert_match(/Hi &lt;Username&gt;/, get_html_part_from(email))
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_program_event_update_notification_as_test_mail
    event = program_events(:birthday_party)
    ChronusMailer.program_event_update_notification(nil, event, {:test_mail => true, :email => "test1@test.com"}).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_equal ["test1@test.com"], email.to
    assert_match("Update: Birthday Party", email.subject)
    assert_no_match /program_event_url(event, :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)/, get_html_part_from(email)
    assert_no_match /update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::YES, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)/, get_html_part_from(email)
    assert_no_match /update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::NO, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)/, get_html_part_from(email)
    assert_no_match /update_invite_program_event_url(program_events(:birthday_party), :status => EventInvite::Status::MAYBE, :src => "email", :subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain)/, get_html_part_from(email)

    assert_match(/#{event.user.name(:name_only => true)}.* has updated some of the following program event details:/, get_html_part_from(email))
    assert_match(/IST/, get_html_part_from(email))
    assert_match(/Let us know that you're still attending!/, get_html_part_from(email))
    assert_match(/This is an automated email/, get_html_part_from(email))
    assert_match(/Hi &lt;Username&gt;/, get_html_part_from(email))
  end

  def test_email_campaigns
    assert CampaignConstants::COMMUNITY_MAIL_ID, 'community_mail'
    assert CampaignConstants::USER_SETTINGS_ROLES_MAIL_ID, 'user_settings_role_mail'

    group = groups(:mygroup)
    sent_mail = ChronusMailer.group_creation_notification_to_mentor(users(:f_mentor), group).deliver_now
    assert_equal sent_mail.header['X-Mailgun-Tag'][0].to_s, CampaignConstants::MENTORING_CONNECTION_MAIL_ID
    assert_equal sent_mail.header['X-Mailgun-Tag'][1].to_s, CampaignConstants::GROUP_CREATION_NOTIFICATION_TO_MENTOR_MAIL_ID
  end

  def test_reset_password_post_expiry
    organization = programs(:org_primary)
    member = members(:f_admin)
    password = Password.create!(:member => member)

    ChronusMailer.password_expiry_notification(password, organization).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)

    assert_equal([member.email], email.to)
    assert_equal("It's time to reset your password", email.subject)
    assert_match  /Your password has expired/, mail_content
    assert_match html_escape(change_password_url(:subdomain => programs(:org_primary).subdomain, :host => programs(:org_primary).domain, :password_expiry => true, :reset_code => password.reset_code)), mail_content
    assert_match(/This is an automated email/, mail_content)
    assert_match "Reset Password", mail_content
  end

  def test_membership_sent_notification
    membership_request = create_membership_request
    membership_request.member.update_attributes!(first_name: "A A", last_name: "B B")
    ChronusMailer.membership_request_sent_notification(membership_request).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_equal "Your membership request has been received.", email.subject
    assert_equal "robert@example.com", email.to.first
    assert_match "Hi A A", get_html_part_from(email)
    assert_match /The test administrators will review your application and you will receive an e-mail once the review is complete/, get_html_part_from(email)
    assert_match /This is an automated email/, get_html_part_from(email)
    assert_match /has been successfully received by the program test administrators./, get_html_part_from(email)
  end

  def test_resend_signup_instructions
    user = users(:f_mentor)
    reset_password = Password.create!(member: user.member)
    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.resend_signup_instructions(user, reset_password).deliver_now
    end
    email = ActionMailer::Base.deliveries.last

    assert_equal "Sign-up for #{user.program.name}", email.subject
    assert_equal "robert@example.com", email.to.first
    assert_match /This is an automated email/, get_html_part_from(email)
    assert_match /Welcome to #{user.program.name}! We look forward to your participation/, get_html_part_from(email)
    assert_match /<a.*href=\"https:\/\/primary.#{DEFAULT_HOST_NAME}\/p\/albers\/users\/new_user_followup\?reset_code=#{reset_password.reset_code}/, get_html_part_from(email)
  end

  def test_essential_mailer_resend_signup_instructions
    user = users(:f_mentor)
    reset_password = Password.create!(member: user.member)
    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.resend_signup_instructions(users(:f_mentor), reset_password).deliver_now
    end
  end

  def test_meeting_request_closed_for_sender_content
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    student = meeting_request.student

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_closed_for_sender(student, meeting_request).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)

    assert_equal "Your meeting request with Good unique name is closed", email.subject
    assert_match "If you have any questions, please", email_content
    assert_match "contact the test administrator", email_content
    assert_match "/contact_admin", email_content
  end

  def test_meeting_requested_created_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    student = meeting_request.student
    ics_attachment = meeting.generate_ics_calendar(Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_created_notification(users(:f_mentor), meeting_request, ics_attachment, sender: meeting_request.student).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert meeting.program.organization.audit_user_communication?
    assert_equal [meeting_request.student.email], email.cc
    email_content = get_html_part_from(email)
    assert_equal "#{student.name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{student.name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, users(:f_mentor).email
    assert_equal "#{meeting.topic}: You received a request for a meeting from #{student.name}", email.subject
    assert_match /#{meeting.topic}/, email_content
    assert_match(/This is an automated email/, email_content)
    assert_equal(0, email.attachments.size)
    assert_match /<a style=\"line-height: 18px\; text-decoration: none\; -webkit-text-size-adjust: 100%\; -ms-text-size-adjust: 100%\; color: #00ADBC\;\" href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\">Download ICS<\/a>/, email_content

    # Sender name is not visible
    student.expects(:visible_to?).returns(false)
    ChronusMailer.meeting_request_created_notification(users(:f_mentor), meeting_request, ics_attachment, sender: meeting_request.student).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_meeting_request_reminder_notification
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_reminder_notification(users(:f_mentor), meeting_request).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal email.to.first, users(:f_mentor).email
    assert_equal "Reminder: You have a pending request from #{members(:mkr_student).name}", email.subject
    assert_match /#{meeting.description}/, email_content
    assert_match /View Request/, email_content
    assert_match /#{members(:mkr_student).name(:name_only => true)}/, email_content
    mentor_secret = members(:f_mentor).calendar_api_key
    date_time = DateTime.localize(meeting_request.created_at.in_time_zone(members(:f_mentor).get_valid_time_zone), format: :abbr_short_with_time)
    assert_match /#{members(:mkr_student).name(:name_only => true)} sent you a meeting request on #{date_time} and is waiting for your response/, email_content
    assert_match(/This is an automated email/, email_content)
    assert_match date_time, email_content
    assert_equal(0, email.attachments.size)
    meeting.meeting_request.update_attributes(:status => 1)
    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_reminder_notification(users(:f_mentor), meeting_request).deliver_now
    end
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_no_match(/https:\/\/primary\.test\.host\/p\/albers\/meeting_requests.* request pending for your approval/, email_content)
  end

  def test_meeting_requested_created_notification_for_non_calendar
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting_request.mentor.member.time_zone = TimezoneConstants::DEFAULT_TIMEZONE
    slot_1 = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
    meeting_request.reload
    student = meeting_request.student
    meeting_request.program.organization.update_attribute(:audit_user_communication, true)

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_created_notification_non_calendar(users(:f_mentor), meeting_request, sender: meeting_request.student).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)

    assert_equal [meeting_request.student.email], email.cc
    assert_equal "#{student.name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal email.to.first, users(:f_mentor).email
    assert_equal "You received a request for a meeting from #{members(:mkr_student).name}", email.subject
    assert_match /#{meeting.description}/, email_content
    assert_match "If you must decline, please do so in a timely manner.", email_content
    assert_match "Proposed Times (UTC)<", email_content
    assert_match "#{meeting_request.student.name(name_only: true)}", email_content
    assert_match "Test location", email_content
    assert_match "Download ICS", email_content
    assert_match /#{DateTime.localize(slot_1.start_time, format: :full_display_with_zone_without_month)} \(20 minutes\)/, email_content.gsub("\n", '').gsub(/\s+/, ' ')
    assert_match "Accept this Time", email_content
    assert_match "Decline", email_content
    assert_match "Accept and Propose Time", email_content
    assert_match(/This is an automated email/, email_content)
    assert_equal(0, email.attachments.size)

    # Sender name is not visible
    student.expects(:visible_to?).returns(false)
    ChronusMailer.meeting_request_created_notification_non_calendar(users(:f_mentor), meeting_request, sender: meeting_request.student).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal [meeting_request.student.email], mail.cc
  end

  def test_meeting_request_sent_notification
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    student = meeting_request.student
    ics_attachment = meeting.generate_ics_calendar(Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_sent_notification(users(:mkr_student), meeting_request, ics_attachment).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal "#{student.name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{student.name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Your invitation for '#{meeting.topic}' has been sent", email.subject
    assert_match /#{meeting.topic}/, email_content
    assert_match /This is a confirmation email. Your invitation to Good unique name to attend a meeting in Albers Mentor Program has been successfully sent/, email_content

    assert_match(/This is an automated email/, email_content)
    assert_equal(0, email.attachments.size)
    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ ,email_content

    # Sender name is not visible
    student.expects(:visible_to?).returns(false)
    ChronusMailer.meeting_request_sent_notification(users(:mkr_student), meeting_request, ics_attachment).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
  end

  def test_meeting_request_status_updated_notification_accepted
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED, acceptance_message: "Acceptance Message")
    ics_attachment = meeting.generate_ics_calendar(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: users(:mkr_student))

    MeetingRequest.any_instance.stubs(:receiver_updated_time?).returns(true)

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_status_accepted_notification(users(:mkr_student), meeting_request, ics_attachment, sender: users(:f_mentor)).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal "#{users(:f_mentor).name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{users(:f_mentor).name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Accepted: #{meeting.topic}", email.subject
    assert_match /#{meeting.topic}/, email_content

    assert_equal(0, email.attachments.size)
    assert_match /<a style=\"line-height: 18px\; text-decoration: none\; -webkit-text-size-adjust: 100%\; -ms-text-size-adjust: 100%\; color: #00ADBC\;\" href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\">Download ICS<\/a>/ ,email_content
    assert_match /also updated the meeting with a new time that works and has a message for you,/, email_content

    #test for calendar event content

    calendar_event_content = get_calendar_event_part_from(email).gsub("\n ", "")
    assert_match /SUMMARY:#{meeting.topic}/, calendar_event_content
    assert_match /Message description.*This is a description of the meeting/, calendar_event_content
    assert_match /Attendees.*Good unique name.*mkr_student madankumarrajan/, calendar_event_content
    assert_match /ORGANIZER.*Apollo Services/, calendar_event_content
    assert_match /To go to the meeting area/, calendar_event_content
    assert_match /p\/albers\/meetings\/#{meeting.id}/, calendar_event_content

    # assert_match /Attendees.*mkr_student madankumarrajan/, calendar_event_content

    # Sender name is not visible

    meeting_request.update_attribute(:acceptance_message, nil)

    users(:f_mentor).expects(:visible_to?).returns(false)
    ics_attachment = meeting.generate_ics_calendar(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: users(:mkr_student))
    ChronusMailer.meeting_request_status_accepted_notification(users(:mkr_student), meeting_request, ics_attachment, sender: users(:f_mentor)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(mail)
    assert_equal "#{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_match /also updated the meeting with a new time that works./, email_content
  end

  def test_meeting_request_status_updated_notification_accepted_non_calendar
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED, acceptance_message: "Acceptance Message")

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_status_accepted_notification_non_calendar(users(:mkr_student), meeting_request, sender: users(:f_mentor)).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal "#{users(:f_mentor).name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{users(:f_mentor).name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "#{users(:f_mentor).name} has accepted your request for a meeting!", email.subject
    assert_match /#{meeting.topic}/, email_content
    assert_match /Acceptance Message/, email_content

    assert_equal(0, email.attachments.size)
    assert_match /Not Set/, email_content

    # Sender name is not visible
    users(:f_mentor).expects(:visible_to?).returns(false)
    ChronusMailer.meeting_request_status_accepted_notification_non_calendar(users(:mkr_student), meeting_request, sender: users(:f_mentor)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
  end

  def test_meeting_request_status_declined_notification_content
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::REJECTED)
    ics_attachment = meeting.generate_ics_calendar(Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)

    selected_mentors = [{:member=>members(:f_mentor_student), :user=>users(:f_mentor_student), :availability=>nil, :max_score=>50, :recommendation_score=>50, :recommended_for=>"flash"}, {:member=>members(:ram), :user=>users(:ram), :availability=>nil, :max_score=>60, :recommendation_score=>50, :recommended_for=>"flash"}]
    MentorRecommendationsService.any_instance.stubs(:get_recommendations_for_mail).returns(selected_mentors)
    MentorRecommendationsService.any_instance.stubs(:get_match_info_for).with(selected_mentors).returns([["Accounting Management"], ["Female"]])

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_status_declined_notification(users(:mkr_student),  meeting_request, ics_attachment, sender: users(:f_mentor)).deliver_now
    end
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal [users(:f_mentor).member.email], email.cc
    assert_equal("Request a new test mentor - #{meeting_request.mentor.name} is unavailable at this time", email.subject)
    assert_match(/was unable to accept your request for a meeting./, email_content)
    assert_match(/This is an automated email/, email_content)
    assert_match users_url(:subdomain => 'primary', :root => 'albers'), email_content
    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ ,email_content
    assert_match(/Recommendations based on your profile/,  get_html_part_from(email))
    assert_match(/Connect/,  get_html_part_from(email))
    assert_match(/View more Test Mentors &rarr;/,  get_html_part_from(email))
    assert_match(/Mentor Studenter/,  get_html_part_from(email))
    assert_match(/Kal Raman/,  get_html_part_from(email))
    assert_match(/Your compatibility/,  get_html_part_from(email))
    assert_match(/Accounting Management/,  get_html_part_from(email))
    assert_match(/Female/,  get_html_part_from(email))
    assert_match(/50% match/,  get_html_part_from(email))
    assert_match(/60% match/,  get_html_part_from(email))
  end

  def test_meeting_request_status_declined_notification_content_no_recommendations
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::REJECTED)
    ics_attachment = meeting.generate_ics_calendar(Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    User.any_instance.stubs(:can_view_mentors?).returns(false)
    selected_mentors = []
    MentorRecommendationsService.any_instance.stubs(:get_recommendations).returns(selected_mentors)
    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_status_declined_notification(users(:mkr_student),  meeting_request, ics_attachment, sender: users(:f_mentor)).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)

    assert_equal [users(:f_mentor).email], email.cc
    assert_equal("Request a new test mentor - #{meeting_request.mentor.name} is unavailable at this time", email.subject)
    assert_match(/This is an automated email/, email_content)
    assert_match(/was unable to accept your request for a meeting./, email_content)
    assert_match users_url(:subdomain => 'primary', :root => 'albers'), email_content
    assert_no_match(/Recommendations based on your profile/,  email_content)
    assert_no_match(/View more Test Mentors →/,  email_content)
    assert_no_match(/Mentor Studenter/,  email_content)
    assert_no_match(/Kal Raman/,  email_content)
    assert_no_match(/Your compatibility/,  email_content)
    assert_no_match(/Accounting Management/,  email_content)
    assert_no_match(/Female/,  email_content)
  end

  def test_meeting_request_status_updated_notification_accepted_to_self
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED)
    ics_attachment = meeting.generate_ics_calendar(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: users(:mkr_student))

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_status_accepted_notification_to_self(users(:mkr_student), users(:f_mentor), meeting_request, ics_attachment).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)

    assert_equal "#{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Confirmation: #{meeting.topic}", email.subject
    assert_match /You just accepted #{users(:mkr_student).name(:name_only => true)}'s meeting request sent to you./, email_content
    assert_match /#{meeting.topic}/, email_content
    assert_equal(0, email.attachments.size)
    assert_match(/This is an automated email/, email_content)
    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ , email_content
    
    #test for calendar event content

    calendar_event_content = get_calendar_event_part_from(email).gsub("\n ", "")
    assert_match /SUMMARY:#{meeting.topic}/, calendar_event_content
    assert_match /Message description.*This is a description of the meeting/, calendar_event_content
    assert_match /Attendees.*Good unique name.*mkr_student madankumarrajan/, calendar_event_content
    assert_match /ORGANIZER.*Apollo Services/, calendar_event_content
    assert_match /To go to the meeting area/, calendar_event_content
    assert_match /primary.#{DEFAULT_HOST_NAME}\/p\/albers\/meetings\/#{meeting.id}/, calendar_event_content.gsub(" ", "")
    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ ,email_content
  end

  def test_meeting_request_status_declined_notification_non_calendar_content
    users(:f_mentor).program.organization.update_attribute(:audit_user_communication, true)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::REJECTED)
    example_text = MeetingRequestStatusDeclinedNotificationNonCalendar.mailer_attributes[:tags][:specific_tags][:view_all_mentors_button][:example].call(programs(:albers))
    assert_equal "View all test mentors →", ActionController::Base.helpers.strip_tags(example_text)
    selected_mentors = [{:member=>members(:f_mentor_student), :user=>users(:f_mentor_student), :slots_availabile_for_mentoring=>3, :max_score=>50, :recommendation_score=>50, :recommended_for=>"flash"}, {:member=>members(:ram), :user=>users(:ram), :slots_availabile_for_mentoring=>nil, :max_score=>60, :recommendation_score=>50, :recommended_for=>"flash"}]
    MentorRecommendationsService.any_instance.stubs(:get_recommendations_for_mail).returns(selected_mentors)
    MentorRecommendationsService.any_instance.stubs(:get_match_info_for).with(selected_mentors).returns([["Accounting Management"], ["Female"]])
    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_status_declined_notification_non_calendar(users(:mkr_student), meeting_request, sender: users(:f_mentor)).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)

    assert_equal [users(:f_mentor).email], email.cc
    assert_equal("Request a new test mentor - #{meeting_request.mentor.name} is unavailable at this time", email.subject)
    assert_match(/This is an automated email/, email_content)
    assert_match(/was unable to accept your request for a meeting./, email_content)
    assert_match users_url(:subdomain => 'primary', :root => 'albers'), email_content
    assert_match(/Recommendations based on your profile/,  email_content)
    assert_match(/Connect/,  email_content)
    assert_match(/View more Test Mentors &rarr;/,  email_content)
    assert_match(/Mentor Studenter/,  email_content)
    assert_match(/Kal Raman/,  email_content)
    assert_match(/Your compatibility/,  email_content)
    assert_match(/Accounting Management/,  email_content)
    assert_match(/Female/,  email_content)
    assert_match(/50% match/,  get_html_part_from(email))
    assert_match(/60% match/,  get_html_part_from(email))
  end

  def test_meeting_request_status_declined_notification_non_calendar_content_no_recommendations
    users(:f_mentor).program.organization.update_attribute(:audit_user_communication, true)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::REJECTED)
    example_text = MeetingRequestStatusDeclinedNotificationNonCalendar.mailer_attributes[:tags][:specific_tags][:view_all_mentors_button][:example].call(programs(:albers))
    assert_equal "View all test mentors →", ActionController::Base.helpers.strip_tags(example_text)
    User.any_instance.stubs(:can_view_mentors?).returns(false)
    selected_mentors = []
    MentorRecommendationsService.any_instance.stubs(:get_recommendations).returns(selected_mentors)
    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_status_declined_notification_non_calendar(users(:mkr_student), meeting_request, sender: users(:f_mentor)).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)

    assert_equal [users(:f_mentor).email], email.cc
    assert_equal("Request a new test mentor - #{meeting_request.mentor.name} is unavailable at this time", email.subject)
    assert_match(/This is an automated email/, email_content)
    assert_match(/was unable to accept your request for a meeting./, email_content)
    assert_match users_url(:subdomain => 'primary', :root => 'albers'), email_content
    assert_no_match(/Recommendations based on your profile/,  email_content)
    assert_no_match(/View more Test Mentors →/,  email_content)
    assert_no_match(/Mentor Studenter/,  email_content)
    assert_no_match(/Kal Raman/,  email_content)
    assert_no_match(/Your compatibility/,  email_content)
    assert_no_match(/Accounting Management/,  email_content)
    assert_no_match(/Female/,  email_content)
  end

  def test_meeting_request_status_updated_notification_withdrawn
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting_request.update_status!(users(:mkr_student), AbstractRequest::Status::WITHDRAWN)
    ics_attachment = meeting.generate_ics_calendar(Meeting::IcsCalendarScenario::CANCEL_EVENT)

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_status_withdrawn_notification(users(:f_mentor), meeting_request, ics_attachment, sender: users(:mkr_student)).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:mkr_student).member.email], email.cc
    assert meeting_request.meeting.program.organization.audit_user_communication?
    email_content = get_html_part_from(email)
    assert_equal "#{users(:mkr_student).name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{users(:mkr_student).name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, users(:f_mentor).email
    assert_equal "#{users(:mkr_student).name} has withdrawn their request for a meeting", email.subject
    assert_match /#{meeting.topic}/, email_content

    assert_match(/This is an automated email/, email_content)
    assert_equal(0, email.attachments.size)
    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ ,email_content

    # Sender name is not visible
    users(:mkr_student).expects(:visible_to?).returns(false)
    ChronusMailer.meeting_request_status_withdrawn_notification(users(:f_mentor),  meeting_request, ics_attachment, sender: users(:mkr_student)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
  end

  def test_meeting_request_status_updated_notification_withdrawn_non_calendar
    users(:mkr_student).program.organization.update_attribute(:audit_user_communication, true)
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting_request.update_status!(users(:mkr_student), AbstractRequest::Status::WITHDRAWN)

    assert_difference "ActionMailer::Base.deliveries.size" do
      ChronusMailer.meeting_request_status_withdrawn_notification_non_calendar(users(:f_mentor), meeting_request, sender: users(:mkr_student)).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:mkr_student).email], email.cc
    email_content = get_html_part_from(email)
    assert_equal "#{users(:mkr_student).name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{users(:mkr_student).name} via #{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, users(:f_mentor).email
    assert_equal "#{users(:mkr_student).name} has withdrawn their request for a meeting", email.subject
    assert_match /#{meeting.description}/, email_content
    assert_no_match /Accept/, email_content
    assert_no_match /Decline/, email_content
    assert_match "/contact_admin", email_content
    assert_match "For any questions, you can reach out to the test administrator", email_content
    assert_match DateTime.localize(meeting_request.created_at.in_time_zone(users(:f_mentor).member.get_valid_time_zone), format: :full_display_no_time), email_content

    # Sender name is not visible
    users(:mkr_student).expects(:visible_to?).returns(false)
    ChronusMailer.meeting_request_status_withdrawn_notification_non_calendar(users(:f_mentor), meeting_request, sender: users(:mkr_student)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{meeting_request.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
  end

  def test_meeting_request_expired_notification_to_sender
    programs(:albers).update_attribute(:meeting_request_auto_expiration_days, 7)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    meeting_request = create_meeting_request
    student = meeting_request.student
    mentor = meeting_request.mentor

    meeting_request.close_request!
    selected_mentors = [{:member=>members(:f_mentor_student), :user=>users(:f_mentor_student), :availability=>nil, :max_score=>50, :recommendation_score=>50, :recommended_for=>"flash"}, {:member=>members(:ram), :user=>users(:ram), :availability=>nil, :max_score=>60, :recommendation_score=>50, :recommended_for=>"flash"}]
    MentorRecommendationsService.any_instance.stubs(:get_recommendations_for_mail).returns(selected_mentors)
    MentorRecommendationsService.any_instance.stubs(:get_match_info_for).with(selected_mentors).returns([["Accounting Management"], ["Female"]])
    ChronusMailer.meeting_request_expired_notification_to_sender(student, meeting_request).deliver_now

    mail = ActionMailer::Base.deliveries.last
    assert_equal [student.email], mail.to
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
    assert_equal "Request a new test mentor - #{mentor.name} is unavailable at this time", mail.subject
    assert_match(/has been closed because it was not accepted within #{programs(:albers).meeting_request_auto_expiration_days.to_s}/, get_html_part_from(mail))
    assert_match users_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match contact_admin_url(:subdomain => 'primary', :root => 'albers'), get_html_part_from(mail)
    assert_match(/This is an automated email/, get_html_part_from(mail))
    assert_match(/Recommendations based on your profile/,  get_html_part_from(mail))
    assert_match(/Connect/,  get_html_part_from(mail))
    assert_match(/View more Test Mentors &rarr;/,  get_html_part_from(mail))
    assert_match(/Mentor Studenter/,  get_html_part_from(mail))
    assert_match(/Kal Raman/,  get_html_part_from(mail))
    assert_match(/Your compatibility/,  get_html_part_from(mail))
    assert_match(/Accounting Management/,  get_html_part_from(mail))
    assert_match(/Female/,  get_html_part_from(mail))
    assert_match(/50% match/,  get_html_part_from(mail))
    assert_match(/60% match/,  get_html_part_from(mail))
  end

  def test_meeting_request_expired_notification_to_sender_content_no_recommendations
    programs(:albers).update_attribute(:meeting_request_auto_expiration_days, 7)
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    meeting_request = create_meeting_request
    student = meeting_request.student
    mentor = meeting_request.mentor

    meeting_request.close_request!
    User.any_instance.stubs(:can_view_mentors?).returns(false)
    selected_mentors = []
    MentorRecommendationsService.any_instance.stubs(:get_recommendations).returns(selected_mentors)
    ChronusMailer.meeting_request_expired_notification_to_sender(student, meeting_request).deliver_now

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)

    mail = ActionMailer::Base.deliveries.last
    assert_equal [student.email], mail.to
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{mentor.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "Request a new test mentor - #{mentor.name} is unavailable at this time", email.subject
    assert_match(/has been closed because it was not accepted within #{programs(:albers).meeting_request_auto_expiration_days.to_s}/, email_content)
    assert_match users_url(:subdomain => 'primary', :root => 'albers'), email_content
    assert_match contact_admin_url(:subdomain => 'primary', :root => 'albers'), email_content
    assert_match(/This is an automated email/, email_content)
    assert_no_match(/Recommendations based on your profile/,  email_content)
    assert_no_match(/View more Test Mentors →/,  email_content)
    assert_no_match(/Mentor Studenter/,  email_content)
    assert_no_match(/Kal Raman/,  email_content)
    assert_no_match(/Your compatibility/,  email_content)
    assert_no_match(/Accounting Management/,  email_content)
    assert_no_match(/Female/,  email_content)
  end

  def test_content_moderation_admin_notification
    admin_user = users(:f_admin)
    post_user = users(:f_mentor)
    post_user.program.organization.update_attribute(:audit_user_communication, true)
    topic = create_topic(title: "Topic Title")
    post = create_post(topic: topic, body: "Post Body", user: post_user, published: false)

    ChronusMailer.content_moderation_admin_notification(admin_user, post, sender: post.user).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content_text = get_text_part_from(email).squish
    email_content_html = get_html_part_from(email).squish
    assert_equal admin_user.email, email.to.first
    assert_equal [post_user.email], email.cc
    assert_equal "New post in the conversation 'Topic Title' needs review", email.subject
    assert_equal admin_user.email, email.to.first
    assert_match "has posted the following content in the conversation 'Topic Title'", email_content_text
    assert_match "Post Body", email_content_text
    assert_match "Review Post", email_content_text
    assert_match user_url(post_user, subdomain: 'primary', root: 'albers'), email_content_html
    assert_match "/forums/#{post.topic.forum_id}/topics/#{post.topic_id}", email_content_html
  end

  def test_content_moderation_user_notification
    post_user = users(:f_mentor)
    topic = create_topic(title: "Topic Title")
    post = create_post(topic: topic, body: "Post Body", user: post_user, published: false)

    ChronusMailer.content_moderation_user_notification(users(:f_mentor), post, "Inappropriate").deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content_text = get_text_part_from(email).squish
    email_content_html = get_html_part_from(email).squish
    assert_equal "Your post in the conversation 'Topic Title' has not been approved", email.subject
    assert_equal users(:f_mentor).email, email.to.first
    assert_match "The following content posted by you in the conversation 'Topic Title' has not been approved by the test administrators", email_content_text
    assert_match "Reason: Inappropriate", email_content_text
    assert_match "/contact_admin", email_content_html
  end

  def test_reply_to_admin_message_failure_notification
    admin_message = messages(:first_admin_message)
    ChronusMailer.reply_to_admin_message_failure_notification(admin_message, "xyz@example.com", "Test email", "Test Content").deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_equal "Re: Test email", email.subject
    assert_equal "xyz@example.com", email.to.first
    mail_content = get_html_part_from(email)
    assert_match /We're sorry, but your message could not be posted because the sender email, xyz@example.com, is not recognized by the program/, mail_content
    assert_match /Test Content/, mail_content
    assert_match /Hi Xyz/, mail_content
  end

  def test_email_from_address
    group = groups(:mygroup)
    stu = group.students.first
    ChronusMailer.group_creation_notification_to_students(stu, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "no-reply@chronus.com", email.from.first

    organization = stu.member.organization
    organization.update_attribute(:email_from_address, "xyz@chronus.com")
    organization.save!

    stu.reload
    group.reload

    ChronusMailer.group_creation_notification_to_students(stu, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "xyz@chronus.com", email.from.first
  end

  def test_pending_group_added_notification
    group = groups(:mygroup)
    user = group.students.first
    group.message = "House of Cards"
    ChronusMailer.pending_group_added_notification(user, group, nil).deliver_now

    email = ActionMailer::Base.deliveries.last

    assert_equal "You have been added as a test student to #{group.name}", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}\/profile/, mail_content
    assert_match /House of Cards/, mail_content
    assert_match /We will notify you when the mentoring connection starts./, mail_content

    group = groups(:mygroup)
    user = group.mentors.first
    group.message = "Carrie Mathison"
    ChronusMailer.pending_group_added_notification(user, group, nil).deliver_now

    email = ActionMailer::Base.deliveries.last

    assert_equal "You have been added as a test mentor to #{group.name}", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}\/profile/, mail_content
    assert_match /Carrie Mathison/, mail_content
    assert_match /We will notify you when the mentoring connection starts./, mail_content
  end

  def test_pending_group_added_notification_by_owner
    group = groups(:mygroup)
    user = group.students.first
    group.message = "House of Cards"
    make_user_owner_of_group(group, user)
    ChronusMailer.pending_group_added_notification(user, group, user).deliver_now

    email = ActionMailer::Base.deliveries.last

    assert_equal "You have been added as a test student to #{group.name}", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}\/profile/, mail_content
    assert_match /Congratulations! #{user.name(name_only: true)} has added you to .*#{h group.name}.* as a test student./, mail_content
    assert_match /We will notify you when the mentoring connection starts./, mail_content
  end

  def test_pending_group_removed_notification
    user = users(:f_mentor)
    group = groups(:mygroup)
    ChronusMailer.pending_group_removed_notification(user, group, users(:f_admin)).deliver_now

    email = ActionMailer::Base.deliveries.last

    assert_equal "The Program Test Administrator has removed you from #{group.name}", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/find_new/, mail_content
    assert_match /The Program Test Administrator has removed you from the mentoring connection, #{h group.name}./, mail_content
    assert_match /However, there are other mentoring connections that you may find more suitable!/, mail_content
  end

  def test_pending_group_removed_notification_by_owner
    user = users(:f_mentor)
    group = groups(:mygroup)
    make_user_owner_of_group(group, user)
    ChronusMailer.pending_group_removed_notification(user, group, user).deliver_now

    email = ActionMailer::Base.deliveries.last

    assert_equal "Good unique name has removed you from #{group.name}", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/find_new/, mail_content
    assert_match /Good unique name has removed you from the mentoring connection, #{h group.name}./, mail_content
    assert_match /However, there are other mentoring connections that you may find more suitable!/, mail_content
  end

  def test_group_published_notification
    user = users(:f_mentor)
    group = groups(:mygroup)
    ChronusMailer.group_published_notification(user, group, users(:f_admin)).deliver_now

    email = ActionMailer::Base.deliveries.last

    assert_equal "Your mentoring connection '#{group.name}' has started", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}/, mail_content
    assert_match /You can start participating by reviewing the mentoring connection plan and reaching out to other participants./, mail_content
  end

  def test_auto_publish_circles_failure_notification
    user = users(:f_mentor_pbe)
    group = groups(:group_pbe)

    current_time = Time.now.beginning_of_day + 12.hours
    group.update_attribute(:start_date, current_time)

    Member.any_instance.stubs(:get_valid_time_zone).returns("Asia/Kolkata")

    assert_false user.is_owner_of?(group)

    ChronusMailer.auto_publish_circles_failure_notification(user, group).deliver_now

    email = ActionMailer::Base.deliveries.last

    assert_equal "Your mentoring connection, #{group.name} didn't start on #{DateTime.localize(current_time.in_time_zone("Asia/Kolkata"), format: :short)}", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match(/p\/pbe\/groups\/#{group.id}/, mail_content)
    assert_match(/Please specify a new start date for the mentoring connection by clicking on the button below./, mail_content)
    assert_match("Update mentoring connection start date", mail_content)
    assert_match(profile_group_url(group, :subdomain => group.program.organization.subdomain, :src => 'mail', show_set_start_date_popup: true).gsub("&", "&amp;"), mail_content)
    assert_match(get_contact_admin_path(group.program, url_params: { subdomain: group.program.organization.subdomain, root: group.program.root, src: 'mail' }, only_url: true).gsub("&", "&amp;"), mail_content)
    assert_no_match(/Or you can add new members to the mentoring connection so that you can start the mentoring connection right now/, mail_content)

    group.membership_of(user).update_attributes!(owner: true)

    ChronusMailer.auto_publish_circles_failure_notification(user, group).deliver_now

    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_match(/Or you can add new members to the mentoring connection so that you can start the mentoring connection right now/, mail_content)
    assert_match(profile_group_url(group, :subdomain => group.program.organization.subdomain, :src => 'mail', manage_circle_members: true).gsub("&", "&amp;"), mail_content)
  end

  def test_project_request_rejected_mail
    program = programs(:pbe)
    admin = users(:f_admin_pbe)
    project_request = program.project_requests.first
    project_request.response_text = "rejecting the request"
    project_request.receiver_id = admin.id
    project_request.save!
    sender = project_request.sender
    group = project_request.group

    assert_emails 1 do
      ChronusMailer.project_request_rejected(sender, project_request).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "Your request to join mentoring connection has not been accepted", email.subject
    assert_equal sender.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /Unfortunately, we have to reject your request to join the mentoring connection, #{group.name}, in .*#{program.name}/, mail_content
    assert_match project_request.response_text, mail_content
    assert_match admin.name(name_only: true), mail_content
    assert_match "/p/#{program.root}/groups/find_new", mail_content
    assert_match "Visit other mentoring connection", mail_content
  end

  def test_project_accepted_mail
    program = programs(:pbe)
    admin = users(:f_admin_pbe)
    project_request = program.project_requests.first
    sender = project_request.sender
    group = project_request.group

    assert_emails 1 do
      ChronusMailer.project_request_accepted(sender, project_request).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "Your request to join #{group.name} has been accepted!", email.subject
    assert_equal sender.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /Congratulations! We have accepted your request to join #{group.name}. We will notify you when the mentoring connection starts./, mail_content
    assert_match "p/#{program.root}/login?src=mail", mail_content
    assert_match "Visit #{program.name}", mail_content
  end

  def test_circle_request_expired_notification_to_sender
    program = programs(:pbe)
    project_request = program.project_requests.first
    sender = project_request.sender
    group = project_request.group

    assert_emails 1 do
      ChronusMailer.circle_request_expired_notification_to_sender(sender, project_request).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "Your request to join #{group.name} is closed now.", email.subject
    assert_equal sender.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match "Unfortunately, we have to close your request to join the mentoring connection, #{group.name} because it has not been responded.", mail_content
    assert_match "Visit other mentoring connections", mail_content
    assert_match contact_admin_url(:subdomain => program.organization.subdomain, :root => program.root, :src => 'mail'), mail_content
    assert_match find_new_groups_url(subdomain: program.organization.subdomain), mail_content
  end

  def test_circle_request_expired_notification_to_sender_display_settings
    program = programs(:pbe)

    program.update_attribute(:circle_request_auto_expiration_days, nil)
    assert program.project_based?
    assert_false CircleRequestExpiredNotificationToSender.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:circle_request_auto_expiration_days, 10)
    assert CircleRequestExpiredNotificationToSender.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:project_based?).returns(false)
    assert_false CircleRequestExpiredNotificationToSender.mailer_attributes[:program_settings].call(program)
  end

  def test_group_published_by_owner_notification
    user = users(:f_mentor)
    group = groups(:mygroup)
    make_user_owner_of_group(group, user)

    ChronusMailer.group_published_notification(user, group, user).deliver_now

    email = ActionMailer::Base.deliveries.last

    assert_equal "Your mentoring connection '#{group.name}' has started", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /Your Good unique name has started the mentoring connection .*'#{h group.name}'/, mail_content
    assert_match /You can start participating by reviewing the mentoring connection plan and reaching out to other participants./, mail_content
  end

  def test_new_project_request_to_admin_and_no_owner
    programs(:pbe).organization.update_attribute(:audit_user_communication, true)
    user = users(:f_admin_pbe)
    program = programs(:pbe)
    project_request = program.project_requests.first
    group = project_request.group
    sender_name = project_request.sender.name
    assert_equal [], project_request.group.owners
    assert_emails 1 do
      ChronusMailer.new_project_request_to_admin_and_owner(user, project_request, sender: project_request.sender).deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [project_request.sender.email], email.cc
    assert_equal "#{sender_name} via #{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{sender_name} via #{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "#{sender_name} requests to join the mentoring connection, #{group.name}", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/pbe\/groups\/#{group.id}\/profile/, mail_content
    assert_match /p\/pbe\/project_requests/, mail_content
    assert_match /If the mentoring connection is a good fit, please accept their request as soon as possible./, mail_content

    # Sender name is not visible
    project_request.sender.expects(:visible_to?).returns(false)
    ChronusMailer.new_project_request_to_admin_and_owner(user, project_request, sender: project_request.sender).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
  end

  def test_project_proposal_accepted_by_admin
    user = users(:f_admin_pbe)
    program = programs(:pbe)
    project = program.groups.first
    sender = users(:pbe_student_1)
    ChronusMailer.proposed_project_accepted(sender, project, false).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "Your proposed mentoring connection has been accepted!", email.subject
    assert_equal sender.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /Hi student_b/, mail_content
    assert_match /p\/pbe\/groups\/#{project.id}\/profile/, mail_content
    assert_match /Congratulations! We have accepted your proposed mentoring connection, project_a/, mail_content
    assert_match /We will notify you when the mentoring connection starts/, mail_content
    assert_no_match /and made you owner for the same./, mail_content

    ChronusMailer.proposed_project_accepted(sender, project, true).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "Your proposed mentoring connection has been accepted!", email.subject
    assert_equal sender.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /You are the owner of the #{project.name}./, mail_content
  end

  def test_project_proposal_rejected_by_admin
    user = users(:f_admin_pbe)
    program = programs(:pbe)
    project = program.groups.first
    project.message = "Project Request is being rejected"
    sender = users(:pbe_student_1)
    ChronusMailer.proposed_project_rejected(sender, project).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "Your request to create project_a has not been approved", email.subject
    assert_equal sender.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /Hi student_b/, mail_content
    assert_match /Unfortunately, we have to reject your proposed mentoring connection, project_a/, mail_content
    assert_no_match /p\/pbe\/groups\/#{project.id}\/profile/, mail_content
    assert_match /we have to reject /, mail_content
    assert_match /Project Based Engagement/, mail_content
  end

  def test_group_creation_notification_to_custom_users
    user = users(:f_mentor)
    group = groups(:mygroup)
    group.message = "Hi, Admin wishes you best of luck for the connection"
    ChronusMailer.group_creation_notification_to_custom_users(user, group).deliver_now

    email = ActionMailer::Base.deliveries.last

    assert_equal "You have been added to a mentoring connection, name & madankumarrajan!", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /Hi, Admin wishes you best of luck for the connection/, mail_content
    assert_match /#{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}/, mail_content
    assert_match "You have been assigned to name &amp; madankumarrajan.", mail_content
    assert_match "Please review your profile and that verify all the information there is still correct. Update your profile information if anything is wrong or no longer valid. This will help your mentoring partners learn more about you and your common interests.", mail_content
    assert_match "Connect with them today in the mentoring connection area.", mail_content
    assert_match "Visit your mentoring connection area", mail_content
    assert_match "/p/albers/groups/#{group.id}?src=mail\"", mail_content
    assert_match "If you have any questions, please contact me", mail_content
    assert_match "/p/albers/contact_admin", mail_content
    # With url_signup
    email_template = groups(:mygroup).program.mailer_templates.create!(:uid => GroupCreationNotificationToCustomUsers.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    email_template.source = "#{email_template.source} {{url_signup}}"
    email_template.save!

    ChronusMailer.group_creation_notification_to_custom_users(user, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_no_match(/Message from the administrator/, mail_content)
    match_str = "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/users\/new_user_followup\?reset_code"
    assert_match match_str, mail_content
  end

  def test_group_proposed_notification_to_admins
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    admin_user = users(:f_admin_pbe)
    proposer = users(:f_mentor_pbe)
    group = groups(:group_pbe_1)
    group.update_attributes!(created_by: proposer, status: Group::Status::PROPOSED)

    ChronusMailer.group_proposed_notification_to_admins(admin_user, group, sender: group.created_by).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [group.created_by.member.email], email.cc
    assert group.program.organization.audit_user_communication?
    assert_equal "#{proposer.name} via #{group.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{proposer.name} via #{group.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "New mentoring connection proposal", email.subject
    assert_equal admin_user.email, email.to.first
    mail_content = get_html_part_from(email)

    assert_match /Good unique name/, mail_content
    assert_match /has proposed a new mentoring connection called.*#{group.name}/, mail_content
    assert_match /project_b/, mail_content
    assert_match /The mentoring connection is pending for your review - you can choose to either accept or reject the mentoring connection/, mail_content
    # Sender name is not visible
    group.created_by.expects(:visible_to?).returns(false)
    ChronusMailer.group_proposed_notification_to_admins(admin_user, group).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{group.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
  end

  def test_pending_group_owner_addition_notification
    group = groups(:group_pbe_2)
    mentor_user = users(:pbe_mentor_2)
    ChronusMailer.group_owner_addition_notification(mentor_user, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You are now an owner of #{group.name}", email.subject
    assert_false group.published?
    assert_equal mentor_user.email, email.to.first
    mail_content = get_html_part_from(email)
    group_link = profile_group_url(group, :subdomain => group.program.organization.subdomain, :src => 'mail')
    assert_match "Congratulations! We've added you as an owner to the mentoring connection, #{group.name}", mail_content
    assert_match "#{group_link}", mail_content
    assert_match /Visit the mentoring connection/, mail_content
  end

  def test_active_group_owner_addition_notification
    mentor_user = users(:f_mentor)
    group = groups(:mygroup)
    ChronusMailer.group_owner_addition_notification(mentor_user, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "You are now an owner of #{group.name}", email.subject
    assert_equal mentor_user.email, email.to.first
    assert group.published?
    mail_content = get_html_part_from(email)
    group_link = profile_group_url(group, :subdomain => group.program.organization.subdomain, :src => 'mail')
    assert_match "Congratulations! We've added you as an owner to the mentoring connection, #{h group.name}", mail_content
    assert_match "#{group_link}", mail_content
    assert_match /Visit the mentoring connection/, mail_content
  end

  def test_report_alert
    admin_user = programs(:albers).admin_users.first
    alert = report_alerts(:report_alert_1)
    view = alert.metric.abstract_view
    ChronusMailer.program_report_alert(admin_user, [alert]).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "1 dashboard alert needs your attention", email.subject
    assert_equal admin_user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match "The following alerts require your attention:", mail_content
    assert_select_helper_function "a[href=\"https://primary.#{ DEFAULT_HOST_NAME}/p/albers/admin_views/#{view.id}?alert_id=#{alert.id}&src=emetric\"][style=\"text-decoration: none; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; color: #00ADBC;\"]", mail_content, text: "#{alert.metric.count} #{alert.description}"
    assert_match "Alert1 Description", mail_content
  end

  def test_report_alert_multiple
    admin_user = programs(:albers).admin_users.first
    alert = report_alerts(:report_alert_1)
    view = alert.metric.abstract_view
    ChronusMailer.program_report_alert(admin_user, [alert, alert]).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "2 dashboard alerts need your attention", email.subject
    assert_equal admin_user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match "The following alerts require your attention:", mail_content
    assert_select_helper_function "a[href=\"https://primary.#{ DEFAULT_HOST_NAME}/p/albers/admin_views/#{view.id}?alert_id=#{alert.id}&src=emetric\"][style=\"text-decoration: none; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; color: #00ADBC;\"]", mail_content, text: "#{alert.metric.count} #{alert.description}"
    assert_match "Alert1 Description", mail_content
  end

  def test_mail_with_ascii_encoding_in_program
    user = users(:f_student)
    user.state_changer = users(:f_admin)
    user.program.name = "B\xC3\x96TE E-Ment\xC3\xB6rl\xC3\xBCk Program\xC4\xB1"
    user.state_changer = users(:f_admin)

    ChronusMailer.user_activation_notification(user).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal user.email, email.to.first
    assert_match "Your account is now reactivated!", email.subject
    assert_match /Your account in.*#{user.program.name}.*has been reactivated./, get_html_part_from(email)
    assert_match "Login", get_html_part_from(email)
    assert_match login_url(:subdomain => user.program.organization.subdomain, :root => user.program.root), get_html_part_from(email)
    assert_match(/This is an automated email/, get_html_part_from(email))
  end

  def test_coach_rating_notification_to_admin
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    program = programs(:albers)
    group = groups(:mygroup)
    mentee = users(:mkr_student)
    mentor = users(:f_mentor)
    admin = users(:f_admin)
    feedback_form = program.feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
    response = Feedback::Response.create_from_answers(
        mentee, mentor, 5, group, feedback_form, {feedback_form.questions.first.id => 'He was ok'})
    ChronusMailer.coach_rating_notification_to_admin(admin, response, {sender: response.rating_giver}).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert admin.program.organization.audit_user_communication?
    assert_equal [response.rating_giver.member.email], email.cc
    assert_equal "#{mentor.first_name} has been rated by #{mentee.first_name}", email.subject
    assert_equal CampaignConstants::COACH_RATING_NOTIFICATION_TO_ADMIN_MAIL_ID, email.header['X-Mailgun-Tag'].to_s
    assert_equal [admin.email], email.to
    email_content = get_text_part_from(email).gsub("\n", " ")
    assert_match "has submitted a rating for", email_content
    assert_match /Rating: 5.0/, get_html_part_from(email)
    assert_match /Comments: He was ok/, get_html_part_from(email)
    assert_match /View Rating/, get_html_part_from(email)
    assert_match "/p/albers/members/3?show_reviews=true", get_html_part_from(email)
  end

  def test_coach_rating_notification_to_student
    program = programs(:albers)
    group = groups(:mygroup)
    mentee = users(:mkr_student)
    mentor = users(:f_mentor)
    ChronusMailer.coach_rating_notification_to_student(mentee, mentor, group).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal CampaignConstants::COACH_RATING_NOTIFICATION_TO_STUDENT_MAIL_ID, email.header['X-Mailgun-Tag'].to_s
    assert_equal "Rate your test mentor, #{mentor.name}", email.subject
    assert_equal [mentee.email], email.to
    assert_match /Please spend a few minutes providing a rating and feedback on your test mentor/, get_html_part_from(email)
    assert_match "Rate your test mentor", get_html_part_from(email)
    assert_match "/p/albers/groups/#{group.id}?coach_rating=#{mentor.id}", get_html_part_from(email)
  end

  def test_coach_rating_notification_to_admin_display_settings
    program = programs(:albers)
    program.enable_feature(FeatureName::COACH_RATING)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert_false program.project_based?
    assert CoachRatingNotificationToAdmin.mailer_attributes[:program_settings].call(program)
    # change engagement type to project based
    program.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert CoachRatingNotificationToAdmin.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false CoachRatingNotificationToStudent.mailer_attributes[:program_settings].call(program)
  end

  def test_coach_rating_notification_to_student_display_settings
    program = programs(:albers)
    program.enable_feature(FeatureName::COACH_RATING)

    assert program.only_career_based_ongoing_mentoring_enabled?
    assert_false program.project_based?
    assert CoachRatingNotificationToStudent.mailer_attributes[:program_settings].call(program)
    # change engagement type to project based
    program.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert CoachRatingNotificationToStudent.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false CoachRatingNotificationToStudent.mailer_attributes[:program_settings].call(program)
  end

  def test_group_inactivity_notification_display_settings
    program = programs(:albers)
    assert program.only_career_based_ongoing_mentoring_enabled?
    assert_false program.project_based?
    assert !program.inactivity_tracking_period.nil?
    assert GroupInactivityNotification.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:inactivity_tracking_period, nil)
    assert_false GroupInactivityNotification.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:inactivity_tracking_period, 2)
    # change engagement type to project based
    program.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert GroupInactivityNotification.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false GroupInactivityNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_group_inactivity_notification_with_auto_terminate_display_settings
    program = programs(:albers)
    assert program.only_career_based_ongoing_mentoring_enabled?
    assert_false program.project_based?
    assert !program.inactivity_tracking_period.nil?
    assert_false program.auto_terminate?
    assert_false GroupInactivityNotificationWithAutoTerminate.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:auto_terminate_reason_id, 2)
    assert GroupInactivityNotificationWithAutoTerminate.mailer_attributes[:program_settings].call(program)
    # change engagement type to project based
    program.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert GroupInactivityNotificationWithAutoTerminate.mailer_attributes[:program_settings].call(program)

    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false GroupInactivityNotificationWithAutoTerminate.mailer_attributes[:program_settings].call(program)
  end

  def test_group_creation_notification_to_mentor_display_settings
    program = programs(:albers)
    assert program.only_career_based_ongoing_mentoring_enabled?
    assert GroupCreationNotificationToMentor.mailer_attributes[:program_settings].call(program)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert_false GroupCreationNotificationToMentor.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false GroupCreationNotificationToMentor.mailer_attributes[:program_settings].call(program)
  end

  def test_group_creation_notification_to_students_display_settings
    program = programs(:albers)
    assert program.only_career_based_ongoing_mentoring_enabled?
    assert GroupCreationNotificationToStudents.mailer_attributes[:program_settings].call(program)
    # change engagement type
    program.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert_false GroupCreationNotificationToStudents.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false GroupCreationNotificationToStudents.mailer_attributes[:program_settings].call(program)
  end

  def test_group_member_addition_notification_to_new_member_display_settings
    program = programs(:albers)
    assert_false program.allow_one_to_many_mentoring?
    assert_false GroupMemberAdditionNotificationToNewMember.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:allow_one_to_many_mentoring, true)
    assert GroupMemberAdditionNotificationToNewMember.mailer_attributes[:program_settings].call(program)
    assert_equal "a test mentor", GroupMemberAdditionNotificationToNewMember.mailer_attributes[:tags][:specific_tags][:role_name_articleized][:example].call(program)
    assert_equal "the program test administrator", GroupMemberAdditionNotificationToNewMember.mailer_attributes[:tags][:specific_tags][:administrator_or_owner_name][:example].call(program)
  end

  def test_group_member_removal_notification_to_removed_member_display_settings
    program = programs(:albers)
    assert_false program.allow_one_to_many_mentoring?
    assert_false GroupMemberRemovalNotificationToRemovedMember.mailer_attributes[:program_settings].call(program)
    program.update_attribute(:allow_one_to_many_mentoring, true)
    assert GroupMemberRemovalNotificationToRemovedMember.mailer_attributes[:program_settings].call(program)
    assert_equal "the program test administrator", GroupMemberRemovalNotificationToRemovedMember.mailer_attributes[:tags][:specific_tags][:administrator_or_owner_name][:example].call(program)
  end

  def test_group_creation_notification_to_custom_users_display_settings
    program = programs(:ceg)
    assert program.only_career_based_ongoing_mentoring_enabled?
    assert_false program.has_custom_role?
    assert_false GroupCreationNotificationToCustomUsers.mailer_attributes[:program_settings].call(program)
    # creating a custom role
    program.roles.create!(:name => "custom_role")
    assert program.has_custom_role?
    assert GroupCreationNotificationToCustomUsers.mailer_attributes[:program_settings].call(program)
    assert_equal "a custom role", GroupCreationNotificationToCustomUsers.mailer_attributes[:tags][:specific_tags][:role_name_articleized][:example].call(program)
  end

  def test_admin_weekly_status_mail
    Timecop.freeze(Time.now.beginning_of_day + 22.hours) do
      program = programs(:albers)
      admin_user = program.admin_users.first
      admin_user.member.update_attribute(:time_zone, "Asia/Tokyo")
      admin_user.reload
      program.enable_feature(FeatureName::CALENDAR, true)
      create_meeting_request
      meeting_req_received = program.meeting_requests.recent(1.week.ago).count
      pending_meeting_req = program.meeting_requests.active.recent(1.week.ago).count

      SurveyAnswer.where(common_question_id: program.survey_question_ids).destroy_all

      precomputed_hash = program.get_admin_weekly_status_hash
      ChronusMailer.admin_weekly_status(admin_user, program, precomputed_hash).deliver_now
      email = ActionMailer::Base.deliveries.last

      since = 1.week.ago
      since_time = DateTime.localize(since.in_time_zone(admin_user.member.get_valid_time_zone), format: :short)
      current_time = DateTime.localize(Time.now.in_time_zone(admin_user.member.get_valid_time_zone), format: :short)
      assert_equal "Your weekly activity summary (#{since_time} to #{current_time}) for #{program.name}", email.subject
      email_html_content = get_html_part_from(email)

      assert_match /Pending Membership Requests/, email_html_content
      assert_match /New test mentors/, email_html_content
      assert_match /New test students/, email_html_content
      assert_match /Mentoring Requests Received/, email_html_content
      assert_match /Mentoring Connections Established/, email_html_content
      assert_match /Mentoring Requests Pending/, email_html_content
      assert_match /New articles/, email_html_content
      assert_match /Meeting Requests Received/, email_html_content
      assert_match /Meeting Requests Pending/, email_html_content
      assert_no_match /New Survey Responses/, email_html_content

      program.enable_feature(FeatureName::CALENDAR, false)
      program.engagement_type = Program::EngagementType::PROJECT_BASED
      program.save!
      program.reload
      precomputed_hash = program.get_admin_weekly_status_hash

      ChronusMailer.admin_weekly_status(admin_user, program, precomputed_hash).deliver_now
      email = ActionMailer::Base.deliveries.last
      email_html_content = get_html_part_from(email)

      since = 1.week.ago
      since_time = DateTime.localize(since.in_time_zone(admin_user.member.get_valid_time_zone), format: :short)
      current_time = DateTime.localize(Time.now.in_time_zone(admin_user.member.get_valid_time_zone), format: :short)
      assert_equal "Your weekly activity summary (#{since_time} to #{current_time}) for #{program.name}", email.subject
      assert_match /Pending Membership Requests/, email_html_content
      assert_match /New test mentors/, email_html_content
      assert_match /New test students/, email_html_content
      assert_no_match /Mentoring Requests Received/, email_html_content
      assert_match /Mentoring Connections Established/, email_html_content
      assert_no_match /Mentoring Requests Pending/, email_html_content
      assert_match /New articles/, email_html_content
      assert_no_match /Meeting Requests Received/, email_html_content
      assert_no_match /Meeting Requests Pending/, email_html_content
      assert_no_match /New Survey Responses/, email_html_content



      survey = ProgramSurvey.create!(
        :program => programs(:albers),
        :name => "First Survey",
        :recipient_role_names => [:mentor],
        :edit_mode => Survey::EditMode::MULTIRESPONSE)

      survey_question = SurveyQuestion.create!(
        {:program => programs(:albers),
          :question_text => "How are you?",
          :question_type => CommonQuestion::Type::STRING,
          :survey => survey})

      answer_1 = SurveyAnswer.create!(
      {:answer_text => "My answer", :user => users(:f_mentor), :last_answered_at => Time.now.utc, :survey_question => survey_question})


      program.enable_feature(FeatureName::CALENDAR, true)
      program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
      program.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_MENTOR
      program.save!

      program.membership_requests.not_joined_directly.pending.destroy_all

      mr_roles = program.roles.select{|r| r.membership_request || r.join_directly? }
      mr_roles.each do |role|
        role.membership_request = false
        role.join_directly = false
        role.save!
      end

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
      assert_match /New test mentors/, email_html_content
      assert_match /New test students/, email_html_content
      assert_match /Mentoring Requests Received/, email_html_content
      assert_match /Mentoring Connections Established/, email_html_content
      assert_match /Mentoring Requests Pending/, email_html_content
      assert_match /New articles/, email_html_content
      assert_match /#{meeting_req_received} strong Meeting Requests Received/, email_html_content.gsub("&nbsp\;", '').gsub(/[^0-9a-z ]/i, '')
      assert_match /#{pending_meeting_req} strong Meeting Requests Pending/, email_html_content.gsub("&nbsp\;", '').gsub(/[^0-9a-z ]/i, '')
      assert_match /New Survey Responses/, email_html_content
    end
  end

  def test_admin_weekly_status_for_project_based_program
    program = programs(:pbe)
    admin = users(:f_admin_pbe)
    since = 1.week.ago

    program.project_requests.update_all(:created_at => 1.day.ago)

    precomputed_hash = program.get_admin_weekly_status_hash

    proposed_groups = program.groups.proposed.count
    active_project_requests = program.project_requests.active.recent(since).count

    ChronusMailer.admin_weekly_status(admin, program, precomputed_hash).deliver_now
    email = ActionMailer::Base.deliveries.last

    email_content = get_html_part_from(email)

    assert_match "#{active_project_requests} strong Users waiting to join mentoring connections", email_content.gsub("&nbsp\;", '').gsub(/[^0-9a-z ]/i, '')
    assert_match "#{proposed_groups} strong Mentoring Connections waiting to be approved", email_content.gsub("&nbsp\;", '').gsub(/[^0-9a-z ]/i, '')

    program.groups.proposed.destroy_all
    program.reload

    precomputed_hash = program.get_admin_weekly_status_hash

    ChronusMailer.admin_weekly_status(admin, program, precomputed_hash).deliver_now
    email = ActionMailer::Base.deliveries.last

    email_content = get_html_part_from(email)

    assert_no_match /Mentoring Connections waiting to be approved/, email_content.gsub(/[^0-9a-z ]/i, '')
  end

  def test_password_expiry_notification_display_settings
    program = programs(:albers)
    ss = program.organization.security_setting
    ss.password_expiration_frequency = Organization::DISABLE_PASSWORD_AUTO_EXPIRY
    ss.save!

    assert_false program.organization.password_auto_expire_enabled?
    assert_false PasswordExpiryNotification.mailer_attributes[:program_settings].call(program)

    ss.password_expiration_frequency = 12
    ss.save!

    assert program.organization.password_auto_expire_enabled?
    assert PasswordExpiryNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_reactivate_account_display_settings
    program = programs(:albers)

    ss = program.organization.security_setting

    assert ss.reactivation_email_enabled?
    assert ReactivateAccount.mailer_attributes[:program_settings].call(program)

    ss.reactivation_email_enabled = false
    ss.save!

    assert_false ss.reactivation_email_enabled?
    assert_false ReactivateAccount.mailer_attributes[:program_settings].call(program)
  end

  def test_group_owner_addition_notification_display_settings
    program = programs(:pbe)
    assert program.project_based?
    assert GroupOwnerAdditionNotification.mailer_attributes[:program_settings].call(program)

    program = programs(:albers)
    assert_false program.project_based?
    assert_false GroupOwnerAdditionNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_group_proposed_notification_to_admins_display_settings
    program = programs(:pbe)
    assert program.project_based?

    Program.any_instance.stubs(:should_display_proposed_projects_emails?).returns(true)
    assert GroupProposedNotificationToAdmins.mailer_attributes[:program_settings].call(program)

    assert_false GroupProposedNotificationToAdmins.mailer_attributes[:program_settings].call(programs(:albers))

    Program.any_instance.stubs(:should_display_proposed_projects_emails?).returns(false)
    assert_false GroupProposedNotificationToAdmins.mailer_attributes[:program_settings].call(program)
  end

  def test_group_published_notification_display_settings
    program = programs(:pbe)
    assert program.project_based?
    assert GroupPublishedNotification.mailer_attributes[:program_settings].call(program)

    program = programs(:albers)
    assert_false program.project_based?
    assert_false GroupPublishedNotification.mailer_attributes[:program_settings].call(program)
    assert_equal "the program test administrator", GroupPublishedNotification.mailer_attributes[:tags][:specific_tags][:administrator_or_owner_name][:example].call(program)
  end

  def test_new_project_request_to_admin_and_owner_display_settings
    program = programs(:pbe)

    Program.any_instance.stubs(:allows_users_to_apply_to_join_in_project?).returns(true)
    assert program.project_based?
    assert NewProjectRequestToAdminAndOwner.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:allows_users_to_apply_to_join_in_project?).returns(false)
    assert_false NewProjectRequestToAdminAndOwner.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:allows_users_to_apply_to_join_in_project?).returns(true)
    program = programs(:albers)
    assert_false program.project_based?
    assert_false NewProjectRequestToAdminAndOwner.mailer_attributes[:program_settings].call(program)
  end

  def test_pending_group_added_notification_display_settings
    program = programs(:pbe)
    assert program.project_based?
    assert PendingGroupAddedNotification.mailer_attributes[:program_settings].call(program)

    program = programs(:albers)
    assert_false program.project_based?
    assert_false PendingGroupAddedNotification.mailer_attributes[:program_settings].call(program)
    assert_equal "a test mentor", PendingGroupAddedNotification.mailer_attributes[:tags][:specific_tags][:role_name_articleized][:example].call(program)
    assert_equal "the program test administrator", PendingGroupAddedNotification.mailer_attributes[:tags][:specific_tags][:administrator_or_owner_name][:example].call(program)
  end

  def test_pending_group_removed_notification_display_settings
    program = programs(:pbe)
    assert program.project_based?
    assert PendingGroupRemovedNotification.mailer_attributes[:program_settings].call(program)

    program = programs(:albers)
    assert_false program.project_based?
    assert_false PendingGroupRemovedNotification.mailer_attributes[:program_settings].call(program)
    assert_equal "the program test administrator", PendingGroupRemovedNotification.mailer_attributes[:tags][:specific_tags][:administrator_or_owner_name][:example].call(program)
    assert_equal "The Program Test Administrator", PendingGroupRemovedNotification.mailer_attributes[:tags][:specific_tags][:administrator_or_owner_name_capitalized][:example].call(program)
  end

  def test_project_request_accepted_display_settings
    program = programs(:pbe)

    Program.any_instance.stubs(:allows_users_to_apply_to_join_in_project?).returns(true)
    assert program.project_based?
    assert ProjectRequestAccepted.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:allows_users_to_apply_to_join_in_project?).returns(false)
    assert_false ProjectRequestAccepted.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:allows_users_to_apply_to_join_in_project?).returns(true)
    program = programs(:albers)
    assert_false program.project_based?
    assert_false ProjectRequestAccepted.mailer_attributes[:program_settings].call(program)
  end

  def test_project_request_rejected_display_settings
    program = programs(:pbe)

    Program.any_instance.stubs(:allows_users_to_apply_to_join_in_project?).returns(true)
    assert program.project_based?
    assert ProjectRequestRejected.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:allows_users_to_apply_to_join_in_project?).returns(false)
    assert_false ProjectRequestRejected.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:allows_users_to_apply_to_join_in_project?).returns(true)
    program = programs(:albers)
    assert_false program.project_based?
    assert_false ProjectRequestRejected.mailer_attributes[:program_settings].call(program)
  end

  def test_project_request_reminder_notification_display_settings
    program = programs(:pbe)

    program.needs_project_request_reminder = true
    program.save!

    assert program.project_based?
    assert program.needs_project_request_reminder?
    assert ProjectRequestReminderNotification.mailer_attributes[:program_settings].call(program)

    program.needs_project_request_reminder = false
    program.save!

    assert_false program.needs_project_request_reminder?
    assert_false ProjectRequestReminderNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_proposed_project_accepted_display_settings
    program = programs(:pbe)
    assert program.project_based?
    assert program.groups.proposed.any?

    Program.any_instance.stubs(:should_display_proposed_projects_emails?).returns(true)
    assert ProposedProjectAccepted.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:should_display_proposed_projects_emails?).returns(false)
    assert ProposedProjectAccepted.mailer_attributes[:program_settings].call(program)    

    program.groups.proposed.destroy_all
    assert_false ProposedProjectAccepted.mailer_attributes[:program_settings].call(program)
  end

  def test_proposed_project_rejected_display_settings
    program = programs(:pbe)
    assert program.project_based?
    assert program.groups.proposed.any?

    Program.any_instance.stubs(:should_display_proposed_projects_emails?).returns(true)
    assert ProposedProjectRejected.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:should_display_proposed_projects_emails?).returns(false)
    assert ProposedProjectRejected.mailer_attributes[:program_settings].call(program)    

    program.groups.proposed.destroy_all
    assert_false ProposedProjectRejected.mailer_attributes[:program_settings].call(program)
  end

  def test_meeting_reminder_display_settings
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)

    program.needs_meeting_request_reminder = true
    program.meeting_request_reminder_duration = 4
    program.meeting_request_auto_expiration_days = 8
    program.save!

    assert MeetingRequestReminderNotification.mailer_attributes[:program_settings].call(program)

    program.needs_meeting_request_reminder = false
    program.save!

    assert_false MeetingRequestReminderNotification.mailer_attributes[:program_settings].call(program)
    example_text = MeetingRequestReminderNotification.mailer_attributes[:tags][:specific_tags][:pending_meeting_request][:example].call(program)
    assert_equal "There are 3 more meeting requests pending your approval.", ActionController::Base.helpers.strip_tags(example_text).squish
  end

  def test_meeting_request_created_notification_display_settings
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = true
    program.calendar_setting.allow_mentor_to_describe_meeting_preference = false
    program.calendar_setting.save!
    assert MeetingRequestCreatedNotification.mailer_attributes[:program_settings].call(program)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = false
    program.calendar_setting.allow_mentor_to_describe_meeting_preference = true
    program.calendar_setting.save!
    assert_false MeetingRequestCreatedNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_meeting_request_expired_notification_to_sender_display_settings
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)

    program.meeting_request_auto_expiration_days = nil
    program.save!

    assert_false MeetingRequestExpiredNotificationToSender.mailer_attributes[:program_settings].call(program)

    program.meeting_request_auto_expiration_days = 12
    program.save!

    assert MeetingRequestExpiredNotificationToSender.mailer_attributes[:program_settings].call(program)
  end

  def test_meeting_request_sent_notification_display_settings
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = true
    program.calendar_setting.allow_mentor_to_describe_meeting_preference = false
    program.calendar_setting.save!
    assert MeetingRequestSentNotification.mailer_attributes[:program_settings].call(program)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = false
    program.calendar_setting.allow_mentor_to_describe_meeting_preference = true
    program.calendar_setting.save!
    assert_false MeetingRequestSentNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_meeting_request_status_accepted_notification_display_settings
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = true
    program.calendar_setting.allow_mentor_to_describe_meeting_preference = false
    program.calendar_setting.save!
    assert MeetingRequestStatusAcceptedNotification.mailer_attributes[:program_settings].call(program)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = false
    program.calendar_setting.allow_mentor_to_describe_meeting_preference = true
    program.calendar_setting.save!
    assert_false MeetingRequestStatusAcceptedNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_meeting_request_status_accepted_notification_to_self_display_settings
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = true
    program.calendar_setting.allow_mentor_to_describe_meeting_preference = false
    program.calendar_setting.save!
    assert MeetingRequestStatusAcceptedNotificationToSelf.mailer_attributes[:program_settings].call(program)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = false
    program.calendar_setting.allow_mentor_to_describe_meeting_preference = true
    program.calendar_setting.save!
    assert_false MeetingRequestStatusAcceptedNotificationToSelf.mailer_attributes[:program_settings].call(program)
  end

  def test_meeting_request_status_withdrawn_notification_display_settings
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)

    program.calendar_setting.allow_mentor_to_describe_meeting_preference = false
    program.calendar_setting.allow_mentor_to_configure_availability_slots = true
    program.calendar_setting.save!
    assert MeetingRequestStatusWithdrawnNotification.mailer_attributes[:program_settings].call(program)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = false
    program.calendar_setting.allow_mentor_to_describe_meeting_preference = true
    program.calendar_setting.save!
    assert_false MeetingRequestStatusWithdrawnNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_complete_signup_existing_member_notification_display_settings
    program = programs(:albers)

    Program.any_instance.stubs(:allows_apply_to_join_for_a_role?).returns(true)
    assert CompleteSignupExistingMemberNotification.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:allows_apply_to_join_for_a_role?).returns(false)
    assert_false CompleteSignupExistingMemberNotification.mailer_attributes[:program_settings].call(program)
    assert_equal "a test mentor", CompleteSignupExistingMemberNotification.mailer_attributes[:tags][:specific_tags][:roles_applied_for][:example].call(program)
  end

  def test_complete_signup_new_member_notification_display_settings
    program = programs(:albers)

    Program.any_instance.stubs(:allows_apply_to_join_for_a_role?).returns(true)
    assert CompleteSignupNewMemberNotification.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:allows_apply_to_join_for_a_role?).returns(false)
    assert_false CompleteSignupNewMemberNotification.mailer_attributes[:program_settings].call(program)
    assert_equal "a test mentor", CompleteSignupNewMemberNotification.mailer_attributes[:tags][:specific_tags][:roles_applied_for][:example].call(program)
  end

  def test_complete_signup_suspended_member_notification_display_settings
    program = programs(:albers)

    Program.any_instance.stubs(:allows_apply_to_join_for_a_role?).returns(true)
    assert CompleteSignupSuspendedMemberNotification.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:allows_apply_to_join_for_a_role?).returns(false)
    assert_false CompleteSignupSuspendedMemberNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_meeting_request_status_declined_notification_display_settings
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = true
    program.calendar_setting.save!
    assert MeetingRequestStatusDeclinedNotification.mailer_attributes[:program_settings].call(program)

    program.calendar_setting.allow_mentor_to_configure_availability_slots = false
    program.calendar_setting.save!
    assert_false MeetingRequestStatusDeclinedNotification.mailer_attributes[:program_settings].call(program)
    example_text = MeetingRequestStatusDeclinedNotification.mailer_attributes[:tags][:specific_tags][:view_all_mentors_button][:example].call(program)
    assert_equal "View all test mentors →", ActionController::Base.helpers.strip_tags(example_text)
  end

  def test_member_suspension_notification_display_settings
    program = programs(:albers)
    organization = programs(:org_primary)

    assert_false program.standalone?
    assert organization.org_profiles_enabled?
    assert MemberSuspensionNotification.mailer_attributes[:program_settings].call(program)

    organization.enable_feature(FeatureName::ORGANIZATION_PROFILES, false)
    assert MemberSuspensionNotification.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:standalone?).returns(true)
    assert_false MemberSuspensionNotification.mailer_attributes[:program_settings].call(program)

    organization.enable_feature(FeatureName::ORGANIZATION_PROFILES, true)
    assert MemberSuspensionNotification.mailer_attributes[:program_settings].call(program.reload)
  end

  def test_membership_request_accepted_display_settings
    program = programs(:albers)

    pending_mrs = program.membership_requests.not_joined_directly.pending
    assert pending_mrs.present?

    assert MembershipRequestAccepted.mailer_attributes[:program_settings].call(program)

    pending_mrs.destroy_all
    mr_roles = program.roles.select{|r| r.membership_request || r.join_directly }
    assert mr_roles.present?

    mr_roles.each do |r|
      r.membership_request = false
      r.join_directly = false
      r.save!
    end

    assert_false MembershipRequestAccepted.mailer_attributes[:program_settings].call(program)
  end

  def test_membership_request_not_accepted_display_settings
    program = programs(:albers)

    pending_mrs = program.membership_requests.not_joined_directly.pending
    assert pending_mrs.present?

    assert MembershipRequestNotAccepted.mailer_attributes[:program_settings].call(program)

    pending_mrs.destroy_all
    mr_roles = program.roles.select{|r| r.membership_request || r.join_directly }
    assert mr_roles.present?

    mr_roles.each do |r|
      r.membership_request = false
      r.join_directly = false
      r.save!
    end

    assert_false MembershipRequestNotAccepted.mailer_attributes[:program_settings].call(program)
  end

  def test_membership_request_sent_notification_display_settings
    program = programs(:albers)

    pending_mrs = program.membership_requests.not_joined_directly.pending
    assert pending_mrs.present?

    assert MembershipRequestSentNotification.mailer_attributes[:program_settings].call(program)

    pending_mrs.destroy_all
    mr_roles = program.roles.select{|r| r.membership_request || r.join_directly }
    assert mr_roles.present?

    mr_roles.each do |r|
      r.membership_request = false
      r.join_directly = false
      r.save!
    end

    assert_false MembershipRequestSentNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_emails_categorization
    enrollment_user_management_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:category] == EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT}

    assert_equal_unordered [MentorAddedNotification, WelcomeMessageToAdmin, ResendSignupInstructions, MemberActivationNotification, WelcomeMessageToMentor, MembershipRequestNotAccepted, AdminAddedNotification, UserWithSetOfRolesAddedNotification, UserPromotedToAdminNotification, DemotionNotification, CompleteSignupNewMemberNotification, CompleteSignupSuspendedMemberNotification, ManagerNotification, NotEligibleToJoinNotification, MemberSuspensionNotification, InviteNotification, WelcomeMessageToMentee, UserSuspensionNotification, CompleteSignupExistingMemberNotification, PromotionNotification, UserActivationNotification, AdminAddedDirectlyNotification, MenteeAddedNotification, MembershipRequestAccepted, WelcomeMessageToPortalUser, PortalMemberWithSetOfRolesAddedNotificationToReviewProfile, PortalMemberWithSetOfRolesAddedNotification, MembershipRequestSentNotification], enrollment_user_management_mails

    administration_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:category] == EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS}

    assert_equal_unordered [NewAdminMessageNotificationToMember, MentoringAreaExport, ProgramReportAlert, OrganizationReportAlert, AnnouncementNotification, AdminMessageNotification, NewMessageToOfflineUserNotification, MentorRequestsExport, AnnouncementUpdateNotification, EmailReport, MembershipRequestsExport], administration_mails

    three_sixty_related_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:category] == EmailCustomization::NewCategories::Type::THREE_SIXTY_RELATED}

    assert_equal_unordered [ThreeSixtySurveyAssesseeNotification, ThreeSixtySurveyReviewerNotification], three_sixty_related_mails

    community_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:category] == EmailCustomization::NewCategories::Type::COMMUNITY}

    assert_equal_unordered [ArticleCommentNotification, ProgramEventUpdateNotification, ForumTopicNotification, NewArticleNotification, ContentModerationUserNotification, InboxMessageNotificationForTrack, QaAnswerNotification, ProgramEventReminderNotification, ProgramEventDeleteNotification, ContentFlaggedAdminNotification, InboxMessageNotification, ForumNotification, NewProgramEventNotification, ContentModerationAdminNotification], community_mails

    matching_and_engagament_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:category] == EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT}

    assert_equal_unordered [AvailableProjectWithdrawn, MentorRequestRejected, NewProjectRequestToAdminAndOwner, MeetingRequestClosedForRecipient, GroupMemberRemovalNotificationToRemovedMember, GroupMentoringOfferNotificationToNewMentee, GroupPublishedNotification, MentorRequestReminderNotification, ProjectRequestRejected, GroupCreationNotificationToMentor, MentorOfferAcceptedNotificationToMentor, MentorOfferClosedForRecipient, MeetingCancellationNotification, MeetingRequestStatusAcceptedNotification, MeetingRequestStatusDeclinedNotificationNonCalendar, GroupProposedNotificationToAdmins, MeetingCreationNotification, MentorOfferWithdrawn, MentorRequestWithdrawnToAdmin, GroupInactivityNotification, CoachRatingNotificationToAdmin, MentorOfferRejectedNotificationToMentor, MeetingRequestStatusDeclinedNotification, GroupCreationNotificationToCustomUsers, GroupCreationNotificationToStudents, MeetingRequestExpiredNotificationToSender, MentorRequestClosedForRecipient, MentorOfferClosedForSender, MeetingRequestCreatedNotificationNonCalendar, MeetingRequestStatusWithdrawnNotificationNonCalendar, GroupMentoringOfferAddedNotificationToNewMentee, MeetingRequestReminderNotification, GroupInactivityNotificationWithAutoTerminate, MentorRecommendationNotification, MeetingRequestSentNotification, MentorRequestAccepted, PendingGroupAddedNotification, MeetingCreationNotificationToOwner, MeetingRequestClosedForSender, GroupOwnerAdditionNotification, MeetingRequestCreatedNotification, MeetingEditNotification, MentorRequestExpiredToSender, PendingGroupRemovedNotification, MentorRequestWithdrawn, MentorRequestClosedForSender, MeetingReminder, ProjectRequestAccepted, MeetingRequestStatusAcceptedNotificationToSelf, NewMentorRequest, ProposedProjectAccepted, GroupMemberAdditionNotificationToNewMember, MeetingRequestStatusAcceptedNotificationNonCalendar, ProposedProjectRejected, MeetingRsvpNotification, NewMentorRequestToAdmin, GroupReactivationNotification, GroupTerminationNotification, CoachRatingNotificationToStudent, MeetingRequestStatusWithdrawnNotification, ProjectRequestReminderNotification, MeetingCancellationNotificationToSelf, MeetingEditNotificationToSelf, MeetingRsvpNotificationToSelf, MeetingRsvpSyncNotificationFailureMail, CircleRequestExpiredNotificationToSender, GroupConversationCreationNotification, AutoPublishCirclesFailureNotification], matching_and_engagament_mails
  end

  def test_email_subcategorization
    assert_equal EmailCustomization::NewCategories::Type::SubCategoriesForType[EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT], [EmailCustomization::NewCategories::SubCategories::APPLY_TO_JOIN, EmailCustomization::NewCategories::SubCategories::INVITATION, EmailCustomization::NewCategories::SubCategories::ADMIN_ADDING_USERS, EmailCustomization::NewCategories::SubCategories::WELCOME_MESSAGES, EmailCustomization::NewCategories::SubCategories::USER_MANAGEMENT]

    assert_equal EmailCustomization::NewCategories::Type::SubCategoriesForType[EmailCustomization::NewCategories::Type::COMMUNITY], [EmailCustomization::NewCategories::SubCategories::EVENTS, EmailCustomization::NewCategories::SubCategories::FORUMS, EmailCustomization::NewCategories::SubCategories::ARTICLES, EmailCustomization::NewCategories::SubCategories::QA_RELATED, EmailCustomization::NewCategories::SubCategories::OTHERS]

    assert_equal EmailCustomization::NewCategories::Type::SubCategoriesForType[EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT], [EmailCustomization::NewCategories::SubCategories::NEW_CIRCLES_CREATION, EmailCustomization::NewCategories::SubCategories::CIRCLE_REQUEST_RELATED, EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED, EmailCustomization::NewCategories::SubCategories::MENTOR_REQUEST_RELATED, EmailCustomization::NewCategories::SubCategories::MENTORING_OFFERS, EmailCustomization::NewCategories::SubCategories::ADMIN_INITIATED_MATCHING, EmailCustomization::NewCategories::SubCategories::MEETINGS, EmailCustomization::NewCategories::SubCategories::MENTORING_CONNECTIONS_NOTIFICATION]
  end

  def test_apply_to_join_subcategory_and_ordering
    apply_to_join_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::APPLY_TO_JOIN}

    assert_equal_unordered [MembershipRequestNotAccepted, CompleteSignupNewMemberNotification, CompleteSignupSuspendedMemberNotification, ManagerNotification, NotEligibleToJoinNotification, CompleteSignupExistingMemberNotification, MembershipRequestAccepted, MembershipRequestSentNotification], apply_to_join_mails

    assert_equal [CompleteSignupNewMemberNotification, CompleteSignupExistingMemberNotification, NotEligibleToJoinNotification, CompleteSignupSuspendedMemberNotification, MembershipRequestSentNotification, ManagerNotification, MembershipRequestAccepted, MembershipRequestNotAccepted], apply_to_join_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_admin_adding_users_subcategory_and_ordering
    admin_adding_users_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::ADMIN_ADDING_USERS}

    assert_equal_unordered [MentorAddedNotification, ResendSignupInstructions, UserWithSetOfRolesAddedNotification, UserPromotedToAdminNotification, AdminAddedDirectlyNotification, MenteeAddedNotification, PortalMemberWithSetOfRolesAddedNotificationToReviewProfile, PortalMemberWithSetOfRolesAddedNotification], admin_adding_users_mails

    assert_equal [MentorAddedNotification, MenteeAddedNotification, UserWithSetOfRolesAddedNotification, AdminAddedDirectlyNotification, ResendSignupInstructions, PortalMemberWithSetOfRolesAddedNotificationToReviewProfile, PortalMemberWithSetOfRolesAddedNotification, UserPromotedToAdminNotification], admin_adding_users_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_welcome_messages_subcategory_and_ordering
    welcome_messages_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::WELCOME_MESSAGES}

    assert_equal_unordered [WelcomeMessageToAdmin, WelcomeMessageToMentor, WelcomeMessageToMentee, WelcomeMessageToPortalUser], welcome_messages_mails

    assert_equal [WelcomeMessageToMentor, WelcomeMessageToMentee, WelcomeMessageToAdmin, WelcomeMessageToPortalUser], welcome_messages_mails.select{|e| !e.mailer_attributes[:donot_list]}.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_articles_mails_subcategory_and_ordering
    articles_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::ARTICLES}

    assert_equal_unordered [ArticleCommentNotification, NewArticleNotification], articles_mails

    assert_equal [NewArticleNotification, ArticleCommentNotification], articles_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_other_mails_subcategory_and_ordering
    other_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::OTHERS}

    assert_equal_unordered [InboxMessageNotification, InboxMessageNotificationForTrack, ContentFlaggedAdminNotification], other_mails

    assert_equal [InboxMessageNotificationForTrack, ContentFlaggedAdminNotification, InboxMessageNotification], other_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_forum_mails_subcategory_and_ordering
    forum_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::FORUMS}

    assert_equal_unordered [ForumTopicNotification, ContentModerationUserNotification, ForumNotification, ContentModerationAdminNotification], forum_mails

    assert_equal [ForumTopicNotification, ForumNotification, ContentModerationAdminNotification, ContentModerationUserNotification], forum_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_user_management_mails_subcategory_and_ordering
    user_management_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::USER_MANAGEMENT}

    assert_equal_unordered [MemberActivationNotification, DemotionNotification, MemberSuspensionNotification, UserSuspensionNotification, PromotionNotification, UserActivationNotification], user_management_mails

    assert_equal [PromotionNotification, DemotionNotification, UserSuspensionNotification, UserActivationNotification, MemberSuspensionNotification, MemberActivationNotification], user_management_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_admin_initiated_matching_mails_subcategory_and_ordering
    admin_initiated_matching_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::ADMIN_INITIATED_MATCHING}

    assert_equal_unordered [GroupCreationNotificationToMentor, GroupCreationNotificationToStudents, GroupCreationNotificationToCustomUsers, MentorRecommendationNotification], admin_initiated_matching_mails

    assert_equal [MentorRecommendationNotification, GroupCreationNotificationToMentor, GroupCreationNotificationToStudents, GroupCreationNotificationToCustomUsers], admin_initiated_matching_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_connection_notification_mails_subcategory_and_ordering
    connection_notification_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::MENTORING_CONNECTIONS_NOTIFICATION}

    assert_equal_unordered [GroupInactivityNotification, GroupMemberAdditionNotificationToNewMember, CoachRatingNotificationToStudent, CoachRatingNotificationToAdmin, GroupReactivationNotification, GroupMemberRemovalNotificationToRemovedMember, GroupInactivityNotificationWithAutoTerminate, GroupTerminationNotification, GroupConversationCreationNotification], connection_notification_mails

    assert_equal [GroupMemberAdditionNotificationToNewMember, GroupMemberRemovalNotificationToRemovedMember, GroupInactivityNotification, GroupInactivityNotificationWithAutoTerminate, CoachRatingNotificationToStudent, CoachRatingNotificationToAdmin, GroupTerminationNotification, GroupReactivationNotification, GroupConversationCreationNotification], connection_notification_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_mentor_offers_mails_subcategory_and_ordering
    mentor_offers_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::MENTORING_OFFERS}

    assert_equal_unordered [GroupMentoringOfferNotificationToNewMentee, MentorOfferClosedForSender, GroupMentoringOfferAddedNotificationToNewMentee, MentorOfferAcceptedNotificationToMentor, MentorOfferRejectedNotificationToMentor, MentorOfferClosedForRecipient, MentorOfferWithdrawn], mentor_offers_mails

    assert_equal [GroupMentoringOfferNotificationToNewMentee, MentorOfferAcceptedNotificationToMentor, MentorOfferRejectedNotificationToMentor, MentorOfferWithdrawn, MentorOfferClosedForSender, MentorOfferClosedForRecipient, GroupMentoringOfferAddedNotificationToNewMentee], mentor_offers_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_new_circles_creation_mails_subcategory_and_ordering
    new_circles_creation_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::NEW_CIRCLES_CREATION}

    assert_equal_unordered [PendingGroupRemovedNotification, ProposedProjectRejected, GroupOwnerAdditionNotification, GroupPublishedNotification, GroupProposedNotificationToAdmins, PendingGroupAddedNotification, ProposedProjectAccepted, AutoPublishCirclesFailureNotification], new_circles_creation_mails

    assert_equal [GroupProposedNotificationToAdmins, ProposedProjectAccepted, ProposedProjectRejected, PendingGroupAddedNotification, PendingGroupRemovedNotification, GroupOwnerAdditionNotification, GroupPublishedNotification, AutoPublishCirclesFailureNotification], new_circles_creation_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_invitation_mails_subcategory_and_ordering
    invitation_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::INVITATION}

    assert_equal_unordered [AdminAddedNotification, InviteNotification], invitation_mails

    assert_equal [InviteNotification, AdminAddedNotification], invitation_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_meetings_mails_subcategory_and_ordering
    meeting_mails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::MEETINGS}

    assert_equal_unordered [MeetingEditNotification, MeetingCreationNotificationToOwner, MeetingReminder, MeetingRsvpNotification, MeetingRsvpNotificationToSelf, MeetingCancellationNotification, MeetingCreationNotification, MeetingCancellationNotificationToSelf, MeetingEditNotificationToSelf, MeetingRsvpSyncNotificationFailureMail], meeting_mails

    assert_equal [MeetingCreationNotification, MeetingCreationNotificationToOwner, MeetingRsvpNotification, MeetingRsvpNotificationToSelf, MeetingRsvpSyncNotificationFailureMail, MeetingEditNotification, MeetingEditNotificationToSelf, MeetingCancellationNotification, MeetingCancellationNotificationToSelf, MeetingReminder], meeting_mails.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_meeting_request_mails_subcategory_and_ordering
    meeting_request_related = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED}

    assert_equal_unordered [MeetingRequestStatusWithdrawnNotificationNonCalendar, MeetingRequestStatusAcceptedNotification, MeetingRequestStatusDeclinedNotification, MeetingRequestCreatedNotification, MeetingRequestStatusWithdrawnNotification, MeetingRequestReminderNotification, MeetingRequestStatusDeclinedNotificationNonCalendar, MeetingRequestStatusAcceptedNotificationToSelf, MeetingRequestStatusAcceptedNotificationNonCalendar, MeetingRequestSentNotification, MeetingRequestClosedForSender, MeetingRequestExpiredNotificationToSender, MeetingRequestCreatedNotificationNonCalendar, MeetingRequestClosedForRecipient], meeting_request_related

    assert_equal [MeetingRequestCreatedNotification, MeetingRequestCreatedNotificationNonCalendar, MeetingRequestSentNotification, MeetingRequestReminderNotification, MeetingRequestStatusAcceptedNotification, MeetingRequestStatusAcceptedNotificationNonCalendar, MeetingRequestStatusAcceptedNotificationToSelf, MeetingRequestStatusDeclinedNotification, MeetingRequestStatusDeclinedNotificationNonCalendar, MeetingRequestStatusWithdrawnNotification, MeetingRequestStatusWithdrawnNotificationNonCalendar, MeetingRequestClosedForSender, MeetingRequestClosedForRecipient, MeetingRequestExpiredNotificationToSender], meeting_request_related.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_mentor_request_mails_subcategory_and_ordering
    mentor_request_related = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::MENTOR_REQUEST_RELATED}

    assert_equal_unordered [MentorRequestReminderNotification, MentorRequestWithdrawnToAdmin, NewMentorRequest, MentorRequestAccepted, MentorRequestRejected, MentorRequestExpiredToSender, MentorRequestWithdrawn, NewMentorRequestToAdmin, MentorRequestClosedForSender, MentorRequestClosedForRecipient], mentor_request_related

    assert_equal [NewMentorRequest, MentorRequestReminderNotification, MentorRequestAccepted, NewMentorRequestToAdmin, MentorRequestWithdrawnToAdmin, MentorRequestRejected, MentorRequestWithdrawn, MentorRequestClosedForRecipient, MentorRequestClosedForSender, MentorRequestExpiredToSender], mentor_request_related.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_events_mails_subcategory_and_ordering
    events_related = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::EVENTS}

    assert_equal_unordered [NewProgramEventNotification, ProgramEventUpdateNotification, ProgramEventDeleteNotification, ProgramEventReminderNotification], events_related

    assert_equal [NewProgramEventNotification, ProgramEventUpdateNotification, ProgramEventReminderNotification, ProgramEventDeleteNotification], events_related.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_circle_request_mails_subcategory_and_ordering
    circle_request_related = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::CIRCLE_REQUEST_RELATED}

    assert_equal_unordered [ProjectRequestAccepted, ProjectRequestRejected, ProjectRequestReminderNotification, NewProjectRequestToAdminAndOwner, AvailableProjectWithdrawn, CircleRequestExpiredNotificationToSender], circle_request_related

    assert_equal [NewProjectRequestToAdminAndOwner, ProjectRequestReminderNotification, CircleRequestExpiredNotificationToSender, ProjectRequestAccepted, AvailableProjectWithdrawn, ProjectRequestRejected], circle_request_related.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_qa_related_mails_subcategory_and_ordering
    qa_related = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::QA_RELATED}

    assert_equal_unordered [QaAnswerNotification], qa_related

    assert_equal [QaAnswerNotification], qa_related.sort_by{|e| e.mailer_attributes[:listing_order]}
  end

  def test_all_hidden_mails
    assert_equal_unordered [UserCampaignEmailNotification, AutoEmailNotification, PasswordExpiryNotification, EmailMonitorMail, ProgramInvitationCampaignEmailNotification, ReactivateAccount, CampaignEmailNotification, PostingInMentoringAreaFailure, EmailChangeNotification, ForgotPassword, ReplyToAdminMessageFailureNotification, SurveyCampaignEmailNotification, PostingInMeetingAreaFailure, MeetingRsvpSyncNotificationFailureMail, MobileAppLogin], ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:donot_list]}
  end

  def test_auto_publish_circles_failure_notification_display_settings
    program = programs(:pbe)

    assert program.allow_circle_start_date?
    assert AutoPublishCirclesFailureNotification.mailer_attributes[:program_settings].call(program)

    Program.any_instance.stubs(:project_based?).returns(false)
    assert_false AutoPublishCirclesFailureNotification.mailer_attributes[:program_settings].call(program)
    Program.any_instance.stubs(:project_based?).returns(true)

    program.update_attribute(:allow_circle_start_date, false)
    assert_false AutoPublishCirclesFailureNotification.mailer_attributes[:program_settings].call(program)
  end

  def test_membership_requests_export_display_settings
    program = programs(:albers)

    pending_mrs = program.membership_requests.not_joined_directly.pending
    assert pending_mrs.present?

    assert MembershipRequestsExport.mailer_attributes[:program_settings].call(program)

    pending_mrs.destroy_all
    mr_roles = program.roles.select{|r| r.membership_request || r.join_directly }
    assert mr_roles.present?

    mr_roles.each do |r|
      r.membership_request = false
      r.join_directly = false
      r.save!
    end

    assert_false MembershipRequestsExport.mailer_attributes[:program_settings].call(program)
  end

  def test_invite_notification_display_settings
    program = programs(:albers)

    assert InviteNotification.mailer_attributes[:program_settings].call(program)
    assert program.has_roles_that_can_invite?

    non_admins = program.roles_without_admin_role
    non_admins.each do |non_admin|
      non_admins.each do |role|
        permission = "invite_#{role.name.pluralize}"
        program.remove_role_permission(non_admin.name, permission)
      end
    end

    assert_false program.has_roles_that_can_invite?
    assert_false InviteNotification.mailer_attributes[:program_settings].call(program)
    assert_equal "a test mentor", InviteNotification.mailer_attributes[:tags][:specific_tags][:invited_as][:example].call(program)
  end

  def test_invite_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    program = programs(:albers)
    user = users(:f_admin)
    invitation = create_program_invitation(email: user.email, role_names: [RoleConstants::STUDENT_NAME], program: user.program)
    user.member.update_attributes!(first_name: "User user", last_name: "f_admin f_admin")

    program.mailer_templates.create!(uid: "7as01het", subject: "Welcome!", source: "Welcome {{receiver_name}}! Hi {{receiver_first_name}}! Hello {{receiver_last_name}}!")
    ChronusMailer.invite_notification(invitation, sender: invitation.user).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [invitation.user.member.email], email.cc
    assert_match(/Welcome User user f_admin f_admin! Hi User user! Hello f_admin f_admin!/, get_html_part_from(email))
    assert program.organization.audit_user_communication?
  end

  def test_complete_signup_new_member_notification
    program = programs(:albers)
    signup_code = Password.create!(email_id: "testuser@example.com").reset_code
    ChronusMailer.complete_signup_new_member_notification(program, "testuser@example.com", [RoleConstants::MENTOR_NAME], signup_code).deliver_now

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert email.to[0].include?("testuser@example.com")
    assert_equal "Complete signing-up for #{program.name}", email.subject
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_match /Thank you for your interest in joining as a test mentor in #{program.name}/, email_content
    assert_match /If the link above does not work, copy and paste the following link in your browser/, email_content
    assert_match /Sign Up/, email_content
    assert_match /#{signup_code}/, email_content
  end

  def test_complete_signup_existing_member_notification
    program = programs(:albers)
    member = members(:f_student)

    ChronusMailer.complete_signup_existing_member_notification(program, member, [RoleConstants::MENTOR_NAME], "reset-password-code", false).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert email.to[0].include?(member.email)
    assert_equal "Sign in to #{program.name}", email.subject
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_match /Thank you for your interest in joining as a test mentor in #{program.name}/, email_content
    assert_match /We noticed you already have login credentials. Please login with your existing password to continue on your way./, email_content
    assert_match /Login to continue/, email_content
    assert_match /If you can't remember your password, please click/, email_content
    assert_match /If you need other assistance, please click/, email_content
    assert_match /to contact the test administrators/, email_content
    assert_no_match(/signup_roles/, email_content)
    assert_match /login/, email_content
    assert_match /change_password\?reset_code=reset-password-code/, email_content

    ChronusMailer.complete_signup_existing_member_notification(program, member, [RoleConstants::MENTOR_NAME], "reset-password-code", true).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_match /login\?signup_roles%5B%5D=#{RoleConstants::MENTOR_NAME}/, email_content
    assert_match /change_password\?reset_code=reset-password-code&amp;signup_roles%5B%5D=#{RoleConstants::MENTOR_NAME}/, email_content
  end

  def test_complete_signup_suspended_member_notification
    program = programs(:cit)
    member = members(:inactive_user)
    ChronusMailer.complete_signup_suspended_member_notification(program, member).deliver_now

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert email.to[0].include?(member.email)
    assert_equal "Your membership has been suspended", email.subject
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_match /Thank you for applying to join #{program.name}./, email_content
    assert_match /Unfortunately, the administrator has suspended your membership in #{member.organization.name}, and therefore your access to #{program.name} is restricted./, email_content
    assert_match /Contact the #{program.name} administrator .*here.* for more information or to request to reactivate your membership./, email_content
  end

  def test_email_theme_colors_in_preview
    uid = AdminAddedNotification.mailer_attributes[:uid]
    mailer_template = Mailer::Template.new(:uid => uid, :source => "Dear John,<br/>\n<br/>\n<div class=\"heading\">Hi</div>\n<br/>\n{{widget_signature}}", :subject => "Subject {{program_name}}")

    AdminAddedNotification.preview(users(:f_admin), members(:f_admin), programs(:albers), programs(:org_primary), mailer_template_obj: mailer_template).deliver_now
    email = ActionMailer::Base.deliveries.last

    assert_match /style=\"font-size: 18px; line-height: 25px; font-family: Helvetica, Arial, sans-serif; color: #1eaa79; padding: 0 0 20px;\">Hi/, get_html_part_from(email)
  end

  def test_different_language_success
    locale = :de
    sa = ThreeSixty::SurveyAssessee.first
    member = sa.assessee
    survey = sa.survey
    Language.set_for_member(member, locale)

    ChronusMailer.three_sixty_survey_assessee_notification(member.reload, survey).deliver_now
    email = ActionMailer::Base.deliveries.last
    content = get_text_part_from(email).gsub(/\n/, " ")

    run_in_another_locale(locale) do
      assert_match 'email_translations.three_sixty_survey_assessee_notification.tags.add_reviewers_text.tag_content_html'.translate, content
    end
    assert_no_match /'email_translations.three_sixty_survey_assessee_notification.tags.add_reviewers_text.tag_content_html'.translate/, content
  end

  def test_content_flagged_admin_notification_with_locale
    flag = create_flag
    admin = users(:f_admin)
    Language.set_for_member(admin.member, :de)
    ChronusMailer.content_flagged_admin_notification(admin.reload, flag).deliver_now
    email = ActionMailer::Base.deliveries.last
    content = get_text_part_from(email).gsub(/\n/, " ")
    assert_no_match "has flagged the following", content

    Language.set_for_member(admin.member, I18n.default_locale.to_s)
    ChronusMailer.content_flagged_admin_notification(admin.reload, flag).deliver_now
    email = ActionMailer::Base.deliveries.last
    content = get_text_part_from(email).gsub(/\n/, " ")
    assert_match /has flagged the following/, content
  end

  def test_complete_signup_new_member_notification_with_locale
    program = programs(:albers)
    email_id = "test_mentor@example.com"

    signup_code = Password.create!(email_id: email_id).reset_code
    ChronusMailer.complete_signup_new_member_notification(program, email_id, [RoleConstants::MENTOR_NAME], signup_code, { locale: :de }).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_no_match /If the link above does not work, copy and paste the following link in your browser/, get_html_part_from(email)

    ChronusMailer.complete_signup_new_member_notification(program, email_id, [RoleConstants::MENTOR_NAME], signup_code).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_match /If the link above does not work, copy and paste the following link in your browser/, get_html_part_from(email)
  end

  def test_announcement_test_send_for_new_announcement_locale
    program = programs(:albers)
    admin = members(:f_admin)
    non_admin = members(:f_mentor)

    locale = :de
    Language.set_for_member(admin, locale)
    Language.set_for_member(non_admin, locale)

    notification_list = "abc@example.com,bcd@example.com,efg@example.com"
    ann = program.announcements.new(:title => "All should assemble in hall",
      :body => "blah blah blah\nThis is it", :wants_test_email => true,
      :notification_list_for_test_email => notification_list)

    ann.program.mailer_template_enable_or_disable(AnnouncementNotification, true)
    mailer = ChronusMailer.announcement_notification(admin.reload.user_in_program(program), ann, {:is_test_mail => true, :non_system_email => notification_list})
    assert_equal :de, mailer.instance_variable_get(:@mail_locale)
    mailer.deliver_now

    email = ActionMailer::Base.deliveries.last
    assert_no_match(/has posted a new announcement!/, get_html_part_from(email))

    mailer = ChronusMailer.announcement_notification(non_admin.reload.user_in_program(program), ann, {:is_test_mail => true, :non_system_email => notification_list})
    assert_equal :de, mailer.instance_variable_get(:@mail_locale)

    organization_languages(:hindi).program_languages.where(program_id: program.id).delete_all

    ann.program.mailer_template_enable_or_disable(AnnouncementNotification, true)
    mailer = ChronusMailer.announcement_notification(admin.reload.user_in_program(program), ann, {:is_test_mail => true, :non_system_email => notification_list})
    assert_equal :de, mailer.instance_variable_get(:@mail_locale)

    email = ActionMailer::Base.deliveries.last
    assert_no_match(/has posted a new announcement!/, get_html_part_from(email))

    mailer = ChronusMailer.announcement_notification(non_admin.reload.user_in_program(program), ann, {:is_test_mail => true, :non_system_email => notification_list})
    assert_equal :en, mailer.instance_variable_get(:@mail_locale)

    locale = I18n.default_locale.to_s
    Language.set_for_member(admin, locale)

    ChronusMailer.announcement_notification(admin.reload.user_in_program(program), ann, {:is_test_mail => true, :non_system_email => notification_list}).deliver_now

    email = ActionMailer::Base.deliveries.last
    assert_match(/has posted a new announcement!/, get_html_part_from(email))
  end

  def test_program_event_test_send_for_update_program_event_locale
    event = program_events(:birthday_party)
    ChronusMailer.program_event_update_notification(nil, event, test_mail: true, email: "test1@test.com").deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_match(/If you have any questions about this event/, get_html_part_from(email))

    user = users(:f_admin)
    member = user.member
    Language.set_for_member(member, :de)
    ChronusMailer.program_event_update_notification(user, event, test_mail: true).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_no_match(/If you have any questions about this event/, get_html_part_from(email))
  end

  def test_program_event_test_send_for_new_program_event_locale
    event = program_events(:birthday_party)
    ChronusMailer.new_program_event_notification(nil, event,  test_mail: true, email: "test1@test.com").deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_match(/If you have any questions about this event/, get_html_part_from(email))

    user = users(:f_admin)
    member = user.member
    Language.set_for_member(member, :de)
    ChronusMailer.new_program_event_notification(user, event, test_mail: true).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_no_match(/If you have any questions about this event/, get_html_part_from(email))
  end

  def test_not_eligible_to_join_notification
    program = programs(:albers)
    roles = program.roles.where(name: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    roles_applied_for = RoleConstants.human_role_string(roles.collect(&:name), :program => roles.first.program, :articleize => true, :no_capitalize => true)
    member = members(:f_mentor)
    template = program.mailer_templates.where(:uid => NotEligibleToJoinNotification.mailer_attributes[:uid]).first
    template ||= program.mailer_templates.create!(:uid => NotEligibleToJoinNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    template.subject = "Customised: Your membership request cannot be processed"
    template.save!

    ChronusMailer.not_eligible_to_join_notification(program, member, roles.pluck(:name)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert email.to[0].include?(member.email)
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "Customised: Your membership request cannot be processed", email.subject
    email_content = get_html_part_from(email)

    assert_match /Thank you for your interest in joining/, email_content
    match_str = "https://primary." + DEFAULT_HOST_NAME + "/p/" + programs(:albers).root
    assert_match match_str, email_content
    assert_match /#{programs(:albers).name}/, email_content
    assert_match /#{roles_applied_for}. Unfortunately, based on available information, it appears you do not meet the required entry criteria. We are therefore unable to process your request at this time./, email_content
    assert_match /If you have any questions, please feel free to/, email_content
    assert_match /contact the test administrator/, email_content
    assert_match contact_admin_url(:subdomain => 'primary', :root => 'albers'), email_content
  end

  def test_prog_level_email_in_multitrack_org
    organization = programs(:org_primary)
    program = programs(:albers)
    assert_false organization.standalone?
    ProgramAsset.create!({program_id: program.id})
    assert_false program.program_asset.logo.present?
    program.reload.update_attributes(:logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    assert_equal "test_pic.png", program.program_asset.logo_file_name

    ProgramAsset.create!({program_id: organization.id})
    assert organization.program_asset.present?
    assert_false organization.program_asset.logo.present?

    roles = program.roles.where(name: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    roles_applied_for = RoleConstants.human_role_string(roles.collect(&:name), :program => roles.first.program, :articleize => true, :no_capitalize => true)
    member = members(:f_mentor)
    email = ChronusMailer.not_eligible_to_join_notification(program, member, roles.pluck(:name))
    email_content = get_html_part_from(email)
    assert_select_helper_function "div.email_content > div", email_content, text: /Thanks/ do
      assert_select "a [href='https://#{organization.url}/p/#{program.root}/']", text: "#{program.name}"
    end
  end

  def test_prog_level_email_in_standalone_org
    organization = programs(:org_foster)
    program = programs(:foster)
    assert organization.standalone?
    ProgramAsset.create!({program_id: program.id})
    assert_false program.program_asset.logo.present?
    program.reload.update_attributes(:logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    assert_equal "test_pic.png", program.program_asset.logo_file_name

    ProgramAsset.create!({program_id: organization.id})
    assert organization.program_asset.present?
    assert_false organization.program_asset.logo.present?

    roles = program.roles.where(name: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    roles_applied_for = RoleConstants.human_role_string(roles.collect(&:name), :program => roles.first.program, :articleize => true, :no_capitalize => true)
    member = members(:foster_mentor1)
    email = ChronusMailer.not_eligible_to_join_notification(program, member, roles.pluck(:name)).deliver_now
    email_content = get_html_part_from(email)

    assert_select_helper_function "div.email_content > div", email_content, text: /Thanks/ do
      assert_select "a [href='https://#{organization.url}/p/#{program.root}/']", text: "#{program.name}"
    end
  end

  def test_meeting_creation_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    program = programs(:albers)
    meeting = create_meeting
    meeting_owner = meeting.owner
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    ics_event = Meeting.get_ics_event(meeting, user: users(:mkr_student))
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    meeting.update_attribute(:location, "Mechanical Sciences Block")
    meeting.update_attribute(:description, "This is a long meeting description and this should get truncated after 150 charecters and after that read more should come which will be a link to the meeting url.")
    template = program.mailer_templates.where(:uid => MeetingCreationNotification.mailer_attributes[:uid]).first
    template ||= program.mailer_templates.create!(:uid => MeetingCreationNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    template.subject = "Customized Subject"
    template.save!

    ChronusMailer.meeting_creation_notification(users(:mkr_student), meeting, calendar.export, sender: meeting.owner).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [meeting.owner.email], email.cc
    email_content = get_html_part_from(email)
    assert_equal "#{meeting_owner.name} via #{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{meeting_owner.name} via #{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, members(:mkr_student).email
    assert_equal "Customized Subject", email.subject
    assert_match meeting.topic, email_content
    assert_match /Mechanical Sciences Block/, email_content
    assert_match "read more", email_content
    assert_match(/Propose a New Time/, email_content)
    assert_match(meeting_url(meeting, subdomain: program.organization.subdomain, root: meeting.program.root, src: 'mail', open_edit_popup: true).gsub("&", "&amp;"), email_content)
    assert_match meeting.description.truncate(Meeting::DESCRIPTION_TRUNCATION_LENGTH_IN_MAILS), email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    assert_match(/UTC/, get_html_part_from(email))
    assert_match(/Yes/, email_content)
    assert_match(/No/, email_content)
    assert_equal(0, email.attachments.size)
    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ ,email_content

    #test for calendar event content
    calendar_event_content = get_calendar_event_part_from(email).gsub("\n ", "")
    assert_match /SUMMARY:#{meeting.topic}/, calendar_event_content
    assert_match /Message description.*This is a long meeting description/, calendar_event_content
    assert_match /Attendees.*unique name.*mkr_student madankumarrajan/, calendar_event_content
    assert_match /ORGANIZER.*Apollo Services/, calendar_event_content
    assert_match /To go to the meeting area/, calendar_event_content

    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ ,email_content
    # Sender name is not visible
    meeting_owner.expects(:visible_to?).returns(false)
    ics_event = Meeting.get_ics_event(meeting, user: users(:mkr_student))
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    ChronusMailer.meeting_creation_notification(users(:mkr_student), meeting, calendar.export, sender: meeting.owner).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
  end

  def test_subject_meeting_creation_notification_to_owner
    program = programs(:albers)
    meeting = create_meeting
    ics_event = Meeting.get_ics_event(meeting, user: users(:f_mentor))
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    ChronusMailer.meeting_creation_notification_to_owner(users(:f_mentor), meeting, calendar.export).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "Invite Confirmation: #{meeting.topic}", email.subject
  end

  def test_meeting_creation_notification_to_owner
    program = programs(:albers)
    meeting = create_meeting
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    ics_event = Meeting.get_ics_event(meeting, user: users(:f_mentor))

    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    template = program.mailer_templates.where(:uid => MeetingCreationNotificationToOwner.mailer_attributes[:uid]).first
    template ||= program.mailer_templates.create!(:uid => MeetingCreationNotificationToOwner.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    template.subject = "Customised Meeting Created: #{meeting.topic}"
    template.content_changer_member_id = 1
    template.content_updated_at = Time.now
    template.save!

    ChronusMailer.meeting_creation_notification_to_owner(users(:f_mentor), meeting, calendar.export).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal email.to.first, members(:f_mentor).email
    assert_equal "Customised Meeting Created: #{meeting.topic}", email.subject
    assert_match meeting.topic, email_content
    assert_match meeting.description, email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    assert_match(/Propose a New Time/, email_content)
    assert_match(meeting_url(meeting, subdomain: program.organization.subdomain, root: meeting.program.root, src: 'mail', open_edit_popup: true).gsub("&", "&amp;"), email_content)
    meeting.guests.each do |g|
      assert_match g.name, email_content
    end
    assert_match "You have successfully created a meeting", email_content
    assert_match(/UTC/, get_html_part_from(email))
    assert_match(/This is an automated email/, email_content)
    assert_equal(0, email.attachments.size)
    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ ,email_content

    #test for calendar event content
    calendar_event_content = get_calendar_event_part_from(email).gsub("\n ", "")
    assert_match /SUMMARY:#{meeting.topic}/, calendar_event_content
    assert_match /Message description.*This is a description of the meeting/, calendar_event_content
    assert_match /Attendees.*Good unique name.*mkr_student madankumarrajan/, calendar_event_content
    assert_match /ORGANIZER.*Apollo Services/, calendar_event_content
    assert_match /To go to the meeting area/, calendar_event_content
    assert_match /primary.#{DEFAULT_HOST_NAME}\/p\/albers\/meetings\/#{meeting.id}/, calendar_event_content.gsub(" ", "")

    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ ,email_content
  end

  def test_meeting_edit_notification_when_sender_not_owner
    program = programs(:albers)
    start_time = Time.now + 2.days
    end_time = start_time + 30.minutes
    meeting = create_meeting(:start_time => start_time, :end_time => end_time)
    meeting_owner = meeting.owner

    ics_event = Meeting.get_ics_event(meeting, user: users(:mkr_student))
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    template = program.mailer_templates.where(:uid => MeetingEditNotification.mailer_attributes[:uid]).first
    template ||= program.mailer_templates.create!(:uid => MeetingEditNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    template.subject = "Customised Updated Invitation: #{meeting.topic}"
    template.save!
    updating_member = (meeting.members - [meeting.owner]).first

    ChronusMailer.meeting_edit_notification(users(:mkr_student), meeting, calendar.export, nil, sender: updating_member).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_match /This event has been updated by #{updating_member.name}/, email_content
    assert_match(/Propose a New Time/, email_content)
    assert_match(meeting_url(meeting, subdomain: program.organization.subdomain, root: meeting.program.root, src: 'mail', open_edit_popup: true).gsub("&", "&amp;"), email_content)
  end

  def test_meeting_edit_notification_to_self
    program = programs(:albers)
    start_time = Time.now + 2.days
    end_time = start_time + 30.minutes
    meeting = create_meeting(:start_time => start_time, :end_time => end_time)

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    ics_event = Meeting.get_ics_event(meeting, user: users(:mkr_student))
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    ChronusMailer.meeting_edit_notification_to_self(users(:mkr_student), meeting, calendar.export, nil).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal email.to.first, members(:mkr_student).email
    assert_equal "Updated: #{meeting.topic}", email.subject
    assert_match(/UTC/, get_html_part_from(email))
    assert_match /You updated this event./, email_content
    assert_match meeting.topic, email_content
    assert_match meeting.description, email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    assert_match(/Propose a New Time/, email_content)
    assert_match(meeting_url(meeting, subdomain: program.organization.subdomain, root: meeting.program.root, src: 'mail', open_edit_popup: true).gsub("&", "&amp;"), email_content)
    meeting.members.each do |g|
      assert_match g.name, email_content
    end

    #test for calendar event content
    calendar_event_content = get_calendar_event_part_from(email).gsub("\n ", "")
    assert_match /SUMMARY:#{meeting.topic}/, calendar_event_content
    assert_match /Message description.*This is a description of the meeting/, calendar_event_content
    assert_match /Attendees.*Good unique name.*mkr_student madankumarrajan/, calendar_event_content
    assert_match /ORGANIZER.*Apollo Services/, calendar_event_content
    assert_match /To go to the meeting area/, calendar_event_content
    assert_match /p\/albers\/meetings\/#{meeting.id}/, calendar_event_content
  end

  def test_meeting_edit_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    program = programs(:albers)
    start_time = Time.now + 2.days
    end_time = start_time + 30.minutes
    meeting = create_meeting(:start_time => start_time, :end_time => end_time)
    meeting_owner = meeting.owner
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)

    ics_event = Meeting.get_ics_event(meeting, user: users(:mkr_student),)
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    template = program.mailer_templates.where(:uid => MeetingEditNotification.mailer_attributes[:uid]).first
    template ||= program.mailer_templates.create!(:uid => MeetingEditNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    template.subject = "Customised Updated Invitation: #{meeting.topic}"
    template.save!

    ChronusMailer.meeting_edit_notification(users(:mkr_student), meeting, calendar.export, nil, sender: meeting.owner).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [meeting.owner.email], email.cc
    email_content = get_html_part_from(email)
    assert_equal "#{meeting_owner.name} via #{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{meeting_owner.name} via #{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, members(:mkr_student).email
    assert_equal "Customised Updated Invitation: #{meeting.topic}", email.subject
    assert_match(/UTC/, get_html_part_from(email))
    assert_match meeting.topic, email_content
    assert_match meeting.description, email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end

    #test for calendar event content
    calendar_event_content = get_calendar_event_part_from(email).gsub("\n ", "")
    assert_match /SUMMARY:#{meeting.topic}/, calendar_event_content
    assert_match /Message description.*This is a description of the meeting/, calendar_event_content
    assert_match /Attendees.*Good unique name.*mkr_student madankumarrajan/, calendar_event_content
    assert_match /ORGANIZER.*Apollo Services/, calendar_event_content
    assert_match /To go to the meeting area/, calendar_event_content
    assert_match /p\/albers\/meetings\/#{meeting.id}/, calendar_event_content

    #Not responded the meeting
    assert_equal MemberMeeting::ATTENDING::NO_RESPONSE, members(:mkr_student).member_meetings.find_by(meeting_id: meeting.id).attending
    assert_match(/Not Responded to/, email_content)
    assert_match(/UTC/, get_html_part_from(email))
    assert_equal(0, email.attachments.size)
    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ ,email_content

    #If Member had accepted the invitation
    template.destroy
    members(:mkr_student).mark_attending!(meeting)
    ics_event = Meeting.get_ics_event(meeting, user: users(:mkr_student),)
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    ChronusMailer.meeting_edit_notification(users(:mkr_student), meeting, calendar.export, nil, sender: meeting.owner).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)

    assert_equal [meeting.owner.email], email.cc
    assert_equal "Updated: #{meeting.topic}", email.subject
    assert_match(/Confirmed/, email_content)

    #If Member had rejected the invitation
    members(:mkr_student).mark_attending!(meeting, attending: MemberMeeting::ATTENDING::NO)
    ics_event = Meeting.get_ics_event(meeting, user: users(:mkr_student),)
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    ChronusMailer.meeting_edit_notification(users(:mkr_student), meeting, calendar.export, nil, sender: meeting.owner).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [meeting.owner.email], email.cc
    email_content = get_html_part_from(email)

    assert_match(/Declined/, email_content)

    # Sender name is not visible
    meeting_owner.expects(:visible_to?).returns(false)
    ics_event = Meeting.get_ics_event(meeting, user: users(:mkr_student),)
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT)
    ChronusMailer.meeting_cancellation_notification(users(:mkr_student), meeting, calendar.export, nil, nil, sender: meeting.owner).deliver_now
    mail = ActionMailer::Base.deliveries.last

    assert_equal [meeting.owner.email], mail.cc
    assert program.organization.audit_user_communication?

    assert_equal "#{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_meeting_cancellation_notification
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    program = programs(:albers)
    meeting = create_meeting
    meeting_owner = meeting.owner
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    ics_event = Meeting.get_ics_event(meeting, user: users(:mkr_student))
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CANCEL_EVENT)
    template = program.mailer_templates.where(:uid => MeetingCancellationNotification.mailer_attributes[:uid]).first
    template ||= program.mailer_templates.create!(:uid => MeetingCancellationNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    template.subject = "Customised Cancelled Invitation: #{meeting.topic}"
    template.save!

    ChronusMailer.meeting_cancellation_notification(users(:mkr_student), meeting, calendar.export, nil, nil, sender: meeting.owner).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal [meeting.owner.email], email.cc
    assert program.organization.audit_user_communication?
    email_content = get_html_part_from(email)
    assert_equal "#{meeting_owner.name} via #{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{meeting_owner.name} via #{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, members(:mkr_student).email
    assert_equal "Customised Cancelled Invitation: #{meeting.topic}", email.subject
    assert_match "#{meeting_owner.name} has cancelled the meeting", email_content
    assert_match meeting.topic, email_content
    assert_match meeting.description, email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    assert_match(/This is an automated email/, email_content)
    assert_equal(0, email.attachments.size)
    #test for calendar event content
    calendar_event_content = get_calendar_event_part_from(email).gsub("\n ", "")
    assert_match /SUMMARY:#{meeting.topic}/, calendar_event_content
    assert_match /Message description.*This is a description of the meeting/, calendar_event_content
    assert_match /Attendees.*Good unique name.*mkr_student madankumarrajan/, calendar_event_content
    assert_match /ORGANIZER.*Apollo Services/, calendar_event_content
    assert_match /To go to the meeting area/, calendar_event_content
    assert_match /primary.#{DEFAULT_HOST_NAME}\/p\/albers\/meetings\/#{meeting.id}/, calendar_event_content.gsub(" ", "")

    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;">download ICS<\/a>/ ,email_content
    # Sender name is not visible
    meeting_owner.expects(:visible_to?).returns(false)
    template.destroy
    ics_event = Meeting.get_ics_event(meeting, user: users(:mkr_student))
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CANCEL_EVENT)
    ChronusMailer.meeting_cancellation_notification(users(:mkr_student), meeting, calendar.export, nil, nil, sender: meeting.owner).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Cancelled: #{meeting.topic}", mail.subject
    assert_equal "#{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s
  end

  def test_meeting_cancellation_notification_to_self
    programs(:org_primary).update_attribute(:audit_user_communication, true)
    program = programs(:albers)
    meeting = create_meeting
    meeting_owner = meeting.owner
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    ics_event = Meeting.get_ics_event(meeting, user: meeting.owner_user)
    calendar = Meeting.generate_ics_calendar_events(ics_event, Meeting::IcsCalendarScenario::CANCEL_EVENT)

    ChronusMailer.meeting_cancellation_notification_to_self(meeting.owner_user, meeting, calendar.export, nil, nil).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal email.to.first, meeting.owner.email
    assert_equal "Cancelled: #{meeting.topic}", email.subject
    assert_match "You cancelled the meeting", email_content
    assert_match meeting.topic, email_content
    assert_match meeting.description, email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    assert_match(/This is an automated email/, email_content)
    assert_equal(0, email.attachments.size)
    assert_match /<a href=\"https:\/\/s3.amazonaws.com\/chronus-mentor-assets\/global-assets\/files\/20140321091645_sample_event.ics\" style=\"-webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; text-decoration: none; color: #00ADBC;\">download ICS<\/a>/ ,email_content

    #test for calendar event content
    calendar_event_content = get_calendar_event_part_from(email).gsub("\n ", "")
    assert_match /SUMMARY:#{meeting.topic}/, calendar_event_content
    assert_match /Message description.*This is a description of the meeting/, calendar_event_content
    assert_match /Attendees.*Good unique name.*mkr_student madankumarrajan/, calendar_event_content
    assert_match /ORGANIZER.*Apollo Services/, calendar_event_content
    assert_match /To go to the meeting area/, calendar_event_content
    assert_match /p\/albers\/meetings\/#{meeting.id}/, calendar_event_content
  end

  def test_meeting_rsvp_sync_notification_failure_mail
    program = programs(:albers)
    meeting = create_meeting

    ChronusMailer.meeting_rsvp_sync_notification_failure_mail(meeting.owner_user, meeting).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal email.to.first, meeting.owner.email
    assert_equal "RSVP notification: #{meeting.topic}", email.subject
    assert_match(meetings_url(:subdomain => program.organization.subdomain, :root => program.root, group_id: meeting.group_id, src: "email").gsub("&", "&amp;"), email_content)
    assert_match meeting.topic, email_content
    assert_match meeting.description, email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
  end

  def test_meeting_rsvp_notification
    program = programs(:albers)
    meeting = create_meeting
    members(:mkr_student).mark_attending!(meeting)
    template = program.mailer_templates.where(:uid => MeetingRsvpNotification.mailer_attributes[:uid]).first
    template ||= program.mailer_templates.create!(:uid => MeetingRsvpNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    template.subject = "Customised Accepted: #{meeting.topic}"
    template.save!

    ChronusMailer.meeting_rsvp_notification(meeting.owner.user_in_program(programs(:albers)),members(:mkr_student).member_meetings.find_by(meeting_id: meeting.id)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "#{members(:mkr_student).name} via #{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{members(:mkr_student).name} via #{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal email.to.first, meeting.owner.email
    assert_equal "Customised Accepted: #{meeting.topic}", email.subject
    assert_match "has accepted the meeting", get_html_part_from(email)
    assert_match meeting.topic, get_html_part_from(email)
    assert_match meeting.description, get_html_part_from(email)
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), get_html_part_from(email)
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), get_html_part_from(email)

    members(:mkr_student).mark_attending!(meeting, attending: MemberMeeting::ATTENDING::NO)
    template.subject = "Customised Declined: #{meeting.topic}"
    template.save!
    ChronusMailer.meeting_rsvp_notification(meeting.owner.user_in_program(programs(:albers)),members(:mkr_student).member_meetings.find_by(meeting_id: meeting.id)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal email.to.first, meeting.owner.email
    assert_equal "Customised Declined: #{meeting.topic}", email.subject
    assert_match "has declined the meeting", get_html_part_from(email)
    assert_match(/UTC/, get_html_part_from(email))

    # Sender name is not visible
    Member.any_instance.expects(:visible_to?).returns(false)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    ChronusMailer.meeting_rsvp_notification(meeting.owner.user_in_program(programs(:albers)),members(:mkr_student).member_meetings.find_by(meeting_id: meeting.id)).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_equal "#{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['from'].to_s
    assert_equal "#{meeting.program.name} <#{MAILER_ACCOUNT[:email_address]}>", mail['sender'].to_s

    #test for calendar event content
    calendar_event_content = get_calendar_event_part_from(mail).gsub("\n ", "")
    assert_match /SUMMARY:#{meeting.topic}/, calendar_event_content
    assert_match /Message description.*This is a description of the meeting/, calendar_event_content
    assert_match /Attendees.*Good unique name.*/, calendar_event_content
    assert_match /ORGANIZER.*Apollo Services/, calendar_event_content
    assert_match /To go to the meeting area/, calendar_event_content
    assert_match /p\/albers\/meetings\/#{meeting.id}/, calendar_event_content

    Member.any_instance.expects(:visible_to?).returns(false)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    meeting.update_attribute(:recurrent, true)
    member_meeting = members(:f_mentor).member_meetings.find_by(meeting_id: meeting.id)
    occurrence_start_time = meeting.first_occurrence

    ChronusMailer.meeting_rsvp_notification(members(:mkr_student).user_in_program(programs(:albers)), member_meeting, occurrence_start_time).deliver_now
    mail = ActionMailer::Base.deliveries.last

    assert_match(/Reschedule Meeting/, get_html_part_from(mail))
    assert_match(meetings_url(subdomain: program.organization.subdomain, root: meeting.program.root, group_id: meeting.group.id, src: 'mail').gsub("&", "&amp;"), get_html_part_from(mail))
    start_time = DateTime.localize(occurrence_start_time, format: :ics_full_time)
    parsed_start_time = DateTime.localize(start_time.to_time.utc, format: :ics_full_time)
    calendar_event_content = get_calendar_event_part_from(mail).gsub("\n ", "")
    assert_match /#{parsed_start_time}/, calendar_event_content
  end

  def test_meeting_rsvp_notification_to_self
    program = programs(:albers)
    meeting = create_meeting
    members(:mkr_student).mark_attending!(meeting)

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    ChronusMailer.meeting_rsvp_notification_to_self(members(:mkr_student).user_in_program(programs(:albers)),members(:mkr_student).member_meetings.find_by(meeting_id: meeting.id)).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal email.to.first, members(:mkr_student).email
    assert_equal "Accepted: #{meeting.topic}", email.subject
    assert_match "You have accepted the meeting", get_html_part_from(email)
    assert_match meeting.topic, get_html_part_from(email)
    assert_match meeting.description, get_html_part_from(email)
    assert_match meeting.start_time.strftime(MentoringSlot.calendar_datetime_format), get_html_part_from(email)
    assert_match(/Propose a New Time/, get_html_part_from(email))
    assert_match(meeting_url(meeting, subdomain: program.organization.subdomain, root: meeting.program.root, src: 'mail', open_edit_popup: true).gsub("&", "&amp;"), get_html_part_from(email))

    #test for calendar event content
    calendar_event_content = get_calendar_event_part_from(email).gsub("\n ", "")
    assert_match /SUMMARY:#{meeting.topic}/, calendar_event_content
    assert_match /Message description.*This is a description of the meeting/, calendar_event_content
    assert_match /Attendees.*Good unique name.*mkr_student madankumarrajan/, calendar_event_content
    assert_match /ORGANIZER.*Apollo Services/, calendar_event_content
    assert_match /To go to the meeting area/, calendar_event_content
    assert_match /p\/albers\/meetings\/#{meeting.id}/, calendar_event_content
  end

  def test_meeting_reminder
    program = programs(:albers)
    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), "2010-02-26 12:00:00".to_time(:utc), "2010-02-26 13:00:00".to_time(:utc), {duration: 1.hour})
    members(:f_mentor).update_attribute(:time_zone, "Asia/Kolkata")
    members(:mkr_student).update_attribute(:time_zone, "Asia/Tokyo") # +9 hrs
    meeting = meetings(:f_mentor_mkr_student)
    meeting.program.update_attributes!(allow_one_to_many_mentoring: true)

    template = program.mailer_templates.where(:uid => MeetingReminder.mailer_attributes[:uid]).first
    template ||= program.mailer_templates.create!(:uid => MeetingReminder.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    template.subject = "Customised Reminder: #{meeting.topic} is starting soon"
    template.save!

    ChronusMailer.meeting_reminder(users(:f_mentor), members(:f_mentor).member_meetings.first).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal email.to.first, members(:f_mentor).email
    assert_equal "Customised Reminder: #{meeting.topic} is starting soon", email.subject
    assert_match meeting.topic, email_content
    assert_match meeting.description, email_content
    assert_match /February 26, 2010 05:30 pm to 06:30 pm/, email_content
    assert_match(/IST/, get_html_part_from(email))
    assert_match(/Confirmed/, email_content)
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    assert_match(/Reschedule Meeting/, email_content)
    assert_match(meetings_url(subdomain: program.organization.subdomain, root: meeting.program.root, group_id: meeting.group.id, src: 'mail').gsub("&", "&amp;"), email_content)

    ChronusMailer.meeting_reminder(users(:mkr_student), members(:f_mentor).member_meetings.first).deliver_now
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal email.to.first, members(:mkr_student).email
    assert_equal "Customised Reminder: #{meeting.topic} is starting soon", email.subject
    assert_match meeting.topic, email_content
    assert_match meeting.description, email_content
    assert_match /February 26, 2010 09:00 pm to 10:00 pm/, email_content
    assert_match(/JST/, get_html_part_from(email))
    assert_no_match(/Reschedule Meeting/, email_content)
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
  end

  def test_mentor_recommendation_notification
    rahim = users(:rahim)
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    recommended_users = mentor_recommendation.recommended_users
    assert_equal MentorRecommendationNotification.mailer_attributes[:feature], FeatureName::MENTOR_RECOMMENDATION
    assert_equal MentorRecommendationNotification.mailer_attributes[:campaign_id], CampaignConstants::MENTOR_RECOMMENDATION_NOTIFICATION_ID

    ChronusMailer.mentor_recommendation_notification(rahim, mentor_recommendation).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "Recommended Test Mentors for you", email['subject'].to_s
    assert_equal "#{rahim.member.email}", email['to'].to_s

    email_content = get_html_part_from(email)
    assert_match "Your test administrator in Albers Mentor Program has recommended test mentors for you", email_content
    assert rahim.program.matching_by_mentee_alone?
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/members\/#{recommended_users.first.member.id}?src=mail", email_content
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/members\/#{recommended_users.last.member.id}?src=mail", email_content
    assert_match recommended_users.first.member.name(name_only: true), email_content
    assert_match recommended_users.last.member.name(name_only: true), email_content
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/members\/#{recommended_users.first.id}?show_mentor_request_popup=true&amp;src=mail", email_content
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/members\/#{recommended_users.last.id}?show_mentor_request_popup=true&amp;src=mail", email_content
    assert_match "90%", email_content
    assert_match ">Connect<\/a>", email_content
  end

  def test_mentor_recommendation_notification_match_score_flag_disabled
    rahim = users(:rahim)
    program = programs(:albers)
    program.allow_end_users_to_see_match_scores = false
    program.save!

    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    recommended_users = mentor_recommendation.recommended_users
    assert_equal MentorRecommendationNotification.mailer_attributes[:feature], FeatureName::MENTOR_RECOMMENDATION
    assert_equal MentorRecommendationNotification.mailer_attributes[:campaign_id], CampaignConstants::MENTOR_RECOMMENDATION_NOTIFICATION_ID

    ChronusMailer.mentor_recommendation_notification(rahim, mentor_recommendation).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "Recommended Test Mentors for you", email['subject'].to_s
    assert_equal "#{rahim.member.email}", email['to'].to_s

    email_content = get_html_part_from(email)
    assert_match "Your test administrator in Albers Mentor Program has recommended test mentors for you", email_content
    assert rahim.program.matching_by_mentee_alone?
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/members\/#{recommended_users.first.member.id}?src=mail", email_content
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/members\/#{recommended_users.last.member.id}?src=mail", email_content
    assert_match recommended_users.first.member.name(name_only: true), email_content
    assert_match recommended_users.last.member.name(name_only: true), email_content
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/members\/#{recommended_users.first.id}?show_mentor_request_popup=true&amp;src=mail", email_content
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/members\/#{recommended_users.last.id}?show_mentor_request_popup=true&amp;src=mail", email_content
    assert_no_match(/90%/, email_content)
    assert_match ">Connect<\/a>", email_content
  end

  def test_mentor_recommendation_notification_for_preferred_mentoring
    rahim = users(:rahim)
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    recommended_users = mentor_recommendation.recommended_users
    assert_equal MentorRecommendationNotification.mailer_attributes[:feature], FeatureName::MENTOR_RECOMMENDATION
    assert_equal MentorRecommendationNotification.mailer_attributes[:campaign_id], CampaignConstants::MENTOR_RECOMMENDATION_NOTIFICATION_ID
    rahim.program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    rahim.program.stubs(:matching_by_mentee_alone?).returns(false)

    ChronusMailer.mentor_recommendation_notification(rahim, mentor_recommendation).deliver_now
    email = ActionMailer::Base.deliveries.last
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['from'].to_s
    assert_equal "#{programs(:albers).name} <#{MAILER_ACCOUNT[:email_address]}>", email['sender'].to_s
    assert_equal "Recommended Test Mentors for you", email['subject'].to_s
    assert_equal "#{rahim.member.email}", email['to'].to_s

    email_content = get_html_part_from(email)
    assert_match "Your test administrator in Albers Mentor Program has recommended test mentors for you", email_content
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/members\/#{recommended_users.first.member.id}?src=mail", email_content
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/members\/#{recommended_users.last.member.id}?src=mail", email_content
    assert_match recommended_users.first.member.name(name_only: true), email_content
    assert_match recommended_users.last.member.name(name_only: true), email_content
    assert_match "https:\/\/primary." + DEFAULT_HOST_NAME + "\/p\/albers\/mentor_requests\/new", email_content
    assert_match "90%", email_content
    assert_match "Request Mentoring Connection", email_content
  end

  def test_program_mail_should_show_updated_example_and_description_for_tags
    program = programs(:albers)
    assert_equal "We have organized a grand lunch and networking event next friday at our cafeteria between noon and 2.00pm. This will be a great platform to extend your professional network.", AnnouncementUpdateNotification.mailer_attributes[:tags][:specific_tags][:announcement_body][:example].call(program)
    assert_equal "a test mentor", InviteNotification.mailer_attributes[:tags][:specific_tags][:invited_as][:example].call(program)
    assert_equal "as a test mentor", InviteNotification.mailer_attributes[:tags][:specific_tags][:as_role_name_articleized][:example].call(program)
    assert_equal "a test mentor", NotEligibleToJoinNotification.mailer_attributes[:tags][:specific_tags][:roles_applied_for][:example].call(program)
    assert_equal "Joining as a test mentor", AdminMessageNotification.mailer_attributes[:tags][:specific_tags][:message_subject][:example].call(program)
    assert_match /fill out your application as a Test Mentor./, AdminMessageNotification.mailer_attributes[:tags][:specific_tags][:message_content][:example].call(program)
    assert_equal "a test mentor", MembershipRequestAccepted.mailer_attributes[:tags][:specific_tags][:member_role][:example].call(program)
    assert_equal "When is the next networking event for program members?", QaAnswerNotification.mailer_attributes[:tags][:specific_tags][:question_summary][:example].call(program)
    assert_equal "The next networking event is coming next Saturday at 5:00 pm.", QaAnswerNotification.mailer_attributes[:tags][:specific_tags][:answer][:example].call(program)
    assert_equal "Role of the member added to the program appended with (a/an)", DemotionNotification.mailer_attributes[:tags][:specific_tags][:role_name][:description].call(program)
    assert_equal "a test mentor", DemotionNotification.mailer_attributes[:tags][:specific_tags][:role_name][:example].call(program)
    assert_equal "a test mentor", PromotionNotification.mailer_attributes[:tags][:specific_tags][:promoted_role_articleized][:example].call(program)
    assert_equal "test mentor", PromotionNotification.mailer_attributes[:tags][:specific_tags][:promoted_role][:example].call(program)
    assert_equal "It looks like you are enrolled in the program.", CompleteSignupExistingMemberNotification.mailer_attributes[:tags][:specific_tags][:user_state_content][:example].call(program)
    assert_equal "Hello Mark! Can you please review my resume?", ReplyToAdminMessageFailureNotification.mailer_attributes[:tags][:specific_tags][:content][:example].call(program)
    assert_equal "We have organized a grand lunch and networking event next friday at our cafeteria between noon and 2.00pm. This will be a great platform to extend your professional network.", AnnouncementNotification.mailer_attributes[:tags][:specific_tags][:announcement_body][:example].call(program)

    example = ProgramReportAlert.mailer_attributes[:tags][:specific_tags][:alert_details][:example].call(program)
    assert_match /Pending Membership Requests/, example
    assert_match /3 Membership Requests are pending more than 15 days/,  example

    organization = program.organization
    example = OrganizationReportAlert.mailer_attributes[:tags][:specific_tags][:alert_details_consolidated][:example].call(program, organization)
    assert_match /Pending Membership Requests/, example
    assert_match /3 Membership Requests are pending more than 15 days/,  example
    assert_match organization.programs.first.name, example
    assert_match organization.programs.last.name,  example

    assert_equal "3 alerts in 2 programs", OrganizationReportAlert.mailer_attributes[:tags][:specific_tags][:alerts_count_consolidated][:example].call(program, organization)
    alerts_to_notify = [Report::Alert.first]
    email = ChronusMailer.organization_report_alert(members(:f_admin), { program => alerts_to_notify })
    assert_equal "1 alert needs your attention", email.subject.to_s
  end

  def test_mentor_offer_withdrawn
    program = programs(:albers)
    program.organization.update_attribute(:audit_user_communication, true)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    group = groups(:mygroup)
    mentee = group.students.first
    mentor = group.mentors.first
    mentor_offer = create_mentor_offer(:mentor => mentor, :student => mentee)
    ChronusMailer.mentor_offer_withdrawn(mentee, mentor_offer, sender: mentor_offer.mentor)
    email = ActionMailer::Base.deliveries.last
    assert_equal [mentor.email], email.cc
  end

  def test_new_mentor_request
    program = programs(:albers)
    program.organization.update_attribute(:audit_user_communication, true)

    student = users(:f_student)
    mentor = users(:f_mentor)
    mreq = create_mentor_request(:student => student, :mentor => mentor)

    ChronusMailer.new_mentor_request(mentor, mreq, sender: student)
    email = ActionMailer::Base.deliveries.last
    assert_equal [student.email], email.cc
  end

  def test_new_mentor_request_with_message_tag
    program = programs(:albers)
    assert program.matching_by_mentee_alone?
    mailer_template = program.mailer_templates.create!(uid: NewMentorRequest.mailer_attributes[:uid], source: '{{message_to_recipient}}', :content_changer_member_id => 1, :content_updated_at => Time.now)
    student = users(:f_student)
    mentor = users(:f_mentor)
    mreq = create_mentor_request(:student => student, :mentor => mentor, :message => "Can u mentor me?")

    ChronusMailer.new_mentor_request(mentor, mreq, sender: student)
    email = ActionMailer::Base.deliveries.last
    content = get_text_part_from(email)
    assert_match "Can u mentor me?", content
  end

  def test_new_mentor_request_to_admin_with_message_tag
    make_member_of(:moderated_program, :f_student)
    mentor_request = create_mentor_request(:student => users(:f_student), :program => programs(:moderated_program), :message => "Can u mentor me?")
    mailer_template = programs(:moderated_program).mailer_templates.create!(uid: NewMentorRequestToAdmin.mailer_attributes[:uid], source: '{{message_to_admin}}', :content_changer_member_id => 1, :content_updated_at => Time.now)
    ChronusMailer.new_mentor_request_to_admin(mentor_request.receivers.first, mentor_request, {sender: mentor_request.student}).deliver_now

    mail = ActionMailer::Base.deliveries.last
    content = get_text_part_from(mail)
    assert_match "Can u mentor me?", content
  end

  def test_campaign_message_with_program_logo_url_theme
    program = programs(:albers)
    cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_admin).create_personalized_message
    mail = get_html_part_from(ActionMailer::Base.deliveries.last)
    assert mail.scan("/#{program.organization.url}/p/#{program.root}/").present?
    assert_match /Campaign Message - Content 1/, mail
    assert_match /Albers Mentor Program/, mail
  end

  def test_campaign_tag_examples
    program = programs(:albers)
    program.roles.where(administrative: false).first.customized_term.save_term('Test Mentor', CustomizedTerm::TermType::ROLE_TERM)
    assert_equal "test mentor", ProgramInvitationCampaignEmailNotification.all_tags[:role_name][:example].call(program)
    assert_equal "as a test mentor", ProgramInvitationCampaignEmailNotification.all_tags[:as_role_name_articleized][:example].call(program)
  end

  private

  def read_fixture(action)
    IO.readlines("#{FIXTURES_PATH}/user_mailer/#{action}")
  end

  def encode(subject)
    quoted_printable(subject, CHARSET)
  end

  def helpers
    ActionController::Base.helpers
  end

  def _a_article
    "an article"
  end

  def _article
    "article"
  end

  def _Article
    "Article"
  end

  def _articles
    "articles"
  end

  def _Articles
    "Articles"
  end

  def _mentor
    "mentor"
  end
end