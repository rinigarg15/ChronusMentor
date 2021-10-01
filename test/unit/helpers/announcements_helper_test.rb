require_relative './../../test_helper.rb'

class AnnouncementsHelperTest < ActionView::TestCase
  def test_get_options_for_email_notifications
    content = get_options_for_email_notifications(UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE)
    assert_select_helper_function "option", content, text: "Immediately", selected: "selected", valued: "#{UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE}"
    assert_select_helper_function "option", content, text: "As part of user digest email (according to their notification setting)", selected: "", valued: "#{UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY}"
    assert_select_helper_function "option", content, text: "Don't send", selected: "", valued: "#{UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND}"
  end

  def test_get_announcement_recipients
    announcement = announcements(:assemble)
    assert_equal "Mentors and Students", get_announcement_recipients(announcement)

    announcement = create_announcement(title: "hello")
    Announcement.any_instance.stubs(:recipient_roles).returns([])
    assert_equal "--", get_announcement_recipients(announcement)
  end

  def test_get_announcement_title
    announcement = announcements(:assemble)
    assert_equal "All come to audi small", get_announcement_title(announcement)

    announcement = create_announcement(:recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name), title: "", status: Announcement::Status::DRAFTED)
    assert_equal "(No title)", get_announcement_title(announcement)
  end

  def test_announcement_expiration_date
    announcement = announcements(:assemble)
    assert_equal "--", announcement_expiration_date(announcement.expiration_date)

    announcement = announcements(:expired_announcement)
    expiration_date = announcement.expiration_date
    self.stubs(:wob_member).returns(members(:f_admin))
    assert_equal DateTime.localize(expiration_date, format: "%b #{expiration_date.day.ordinalize}"), announcement_expiration_date(expiration_date)
  end

  def test_get_label_class
    announcement = announcements(:assemble)
    assert_nil get_label_class(announcement.expiration_date)

    announcement = announcements(:expired_announcement)
    assert_equal "label-warning", get_label_class(announcement.expiration_date)
  end
end