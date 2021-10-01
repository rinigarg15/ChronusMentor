require_relative './../../test_helper.rb'

class PeriodicMailerTest < ActionMailer::TestCase

  include Rails.application.routes.url_helpers

  def default_url_options
    ActionMailer::Base.default_url_options
  end

  def test_admin_weekly_status
    admin = users(:f_admin)
    p = programs(:albers)
    User.where("id IN (?)", (p.student_users+p.mentor_users).flatten).update_all({:created_at => 1.day.ago})
    MembershipRequest.where("id IN (?)", p.membership_requests.collect(&:id)).update_all({:created_at => 1.day.ago})
    MentorRequest.where("id IN (?)", p.mentor_requests.collect(&:id)).update_all({:created_at => 1.day.ago})
    Group.where("id IN (?)", p.groups.collect(&:id)).update_all({:created_at => 1.day.ago})
    Article.where("id IN (?)", p.articles.collect(&:id)).update_all({:created_at => 1.day.ago})

    p.reload
    assert_equal 12, p.membership_requests.size
    mark_object_old membership_requests(:membership_request_0)

    assert_equal 23, p.mentor_users.size
    mark_object_old users(:f_mentor)

    assert_equal 21, p.student_users.size
    mark_object_old users(:f_student)

    assert_equal 20, p.mentor_requests.size
    mark_object_old mentor_requests(:mentor_request_0)

    assert_equal 4, p.articles.published.size
    mark_object_old articles(:economy)

    assert_equal 1, p.groups.select(&:expiring_next_week?).size

    p.reload
    precomputed_hash = p.get_admin_weekly_status_hash

    ChronusMailer.admin_weekly_status(admin, p, precomputed_hash).deliver_now
    mail = ActionMailer::Base.deliveries.last
    assert_match /#{p.name}/ , mail['from'].to_s
    assert_match /Your weekly activity summary (.*)/, mail.subject
    assert_equal [admin.email], mail.to
    assert_match(/This is an automated email/, get_html_part_from(mail))

    mail_content = ActionView::Base.full_sanitizer.sanitize(get_html_part_from(mail)).gsub(/&nbsp\;/,"").gsub(/[^0-9a-z ]/i, '')
    assert_match /11  Pending Membership Requests/, mail_content
    assert_match /22  New mentors/, mail_content
    assert_match /20  New students/, mail_content
    assert_match /19  Mentoring Requests Received/, mail_content
    assert_match /7  Mentoring Connections Established/, mail_content
    assert_match /14  Mentoring Requests Pending/, mail_content
    assert_match /3  New #{_articles}/, mail_content
  end

  def test_pending_project_request_notification
    user = users(:pbe_student_2)
    program = programs(:pbe)
    request = groups(:group_pbe_2).project_requests.active.first
    user_email = nil
    user_email = ChronusMailer.project_request_reminder_notification(user, request).deliver_now

    mail_text = get_text_part_from(user_email)
    assert_match /#{user.program.name}/ , user_email['from'].to_s
    assert_equal user.email , user_email['to'].to_s
    assert_equal "Reminder! #{request.sender.name(name_only: true)}'s mentoring connection request is pending your approval", user_email.subject
    assert_match "student_e example asked to join project_c", mail_text
    project_requests_link = "https:\/\/primary\." +  DEFAULT_HOST_NAME + "\/p\/pbe\/project_requests?src=email"
    group_link = "https:\/\/primary\." +  DEFAULT_HOST_NAME + "\/p\/pbe\/groups\/#{groups(:group_pbe_2).id}\/profile"
    assert_match project_requests_link, mail_text
    assert_match group_link, mail_text
    assert_match "View Request", mail_text
  end

  private

  def mark_object_old(object)
    object.update_attribute(:created_at, 1.month.ago)
    object.save!
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
end