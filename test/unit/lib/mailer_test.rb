require_relative './../../test_helper.rb'

class TestMailerKlass < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'randomstring',
    :subject      => Proc.new{ '{{customized_mentors_term}}' },
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_attachment_tag],
    :excluded_tags => [:current_time]
  }

  private

  register_tags do
    tag :registered_tag, { description: Proc.new { "Some description" }, example: Proc.new { "Some example" } } do

    end
  end
  register!
end

class MailerTest < ActiveSupport::TestCase

  def test_preview
    program = programs(:albers)
    program.organization.update_attributes(name: "<script>alert(\"Test Program\")</script>")
    user = users(:f_admin)
    template = Mailer::Template.create!(program: program, uid: AdminWeeklyStatus.mailer_attributes[:uid], source: "Yours sincerely", subject: "Subject <script>alert(\"Subject\")</script> {{program_name}}", enabled: true, content_changer_member_id: 1, content_updated_at: Time.now)
    assert_equal "Subject <script>alert(\"Subject\")</script> <script>alert(\"Test Program\")</script>", ChronusActionMailer::Base.preview(user, user.member, program, program.organization, mailer_template_obj: template).subject
  end

  def test_get_tags_from_email
    TestMailerKlass.stubs(:default_email_content_from_path).returns("Dear {{receiver_name}}, {{customized_mentees_term}}")
    tags = TestMailerKlass.get_tags_from_email.keys

    assert tags.include?(:customized_mentors_term)
    assert tags.include?(:receiver_name)
    assert tags.include?(:customized_mentees_term)
    assert tags.include?(:program_name)
    assert tags.include?(:url_program)
    assert tags.include?(:receiver_name)
    assert tags.include?(:receiver_first_name)
    assert tags.include?(:receiver_last_name)
    assert tags.include?(:subprogram_name)
    assert tags.include?(:url_subprogram)
    assert tags.include?(:subprogram_or_program_name)
    assert tags.include?(:url_subprogram_or_program)
    assert tags.include?(:url_program_login)
    assert tags.include?(:url_meeting_request_calendar_attachment)
    assert_false tags.include?(:current_time)
    assert_equal 14, tags.size

    mailer_attributes = TestMailerKlass.mailer_attributes.merge({:level => EmailCustomization::Level::ORGANIZATION, :other_registered_tags => []})
    TestMailerKlass.stubs(:mailer_attributes).returns(mailer_attributes)
    tags = TestMailerKlass.get_tags_from_email.keys
    assert tags.include?(:customized_mentors_term)
    assert tags.include?(:receiver_name)
    assert tags.include?(:customized_mentees_term)
    assert tags.include?(:program_name)
    assert tags.include?(:url_program)
    assert tags.include?(:receiver_name)
    assert tags.include?(:receiver_first_name)
    assert tags.include?(:receiver_last_name)
    assert_false tags.include?(:subprogram_name)
    assert_false tags.include?(:url_subprogram)
    assert_false tags.include?(:subprogram_or_program_name)
    assert_false tags.include?(:url_subprogram_or_program)
    assert_false tags.include?(:url_program_login)
    assert_false tags.include?(:url_meeting_request_calendar_attachment)
    assert_false tags.include?(:current_time)
    assert_equal 8, tags.size
  end

  def test_get_for_role_names_ary
    assert_equal [RoleConstants::MENTOR_NAME], GroupCreationNotificationToMentor.get_for_role_names_ary
    assert_equal [], AnnouncementNotification.get_for_role_names_ary
    assert_equal [RoleConstants::TEACHER_NAME], GroupCreationNotificationToCustomUsers.get_for_role_names_ary(programs(:pbe))
  end

  def test_always_enabled
    mailer_attributes = AdminWeeklyStatus.mailer_attributes.merge(always_enabled: true)
    AdminWeeklyStatus.stubs(:mailer_attributes).returns(mailer_attributes)
    assert ChronusActionMailer::Base.always_enabled?(mailer_attributes[:uid])

    mailer_attributes = AdminWeeklyStatus.mailer_attributes.merge(always_enabled: false)
    AdminWeeklyStatus.stubs(:mailer_attributes).returns(mailer_attributes)
    assert_false ChronusActionMailer::Base.always_enabled?(mailer_attributes[:uid])

    assert_false ChronusActionMailer::Base.always_enabled?("invalid uid")
  end
end