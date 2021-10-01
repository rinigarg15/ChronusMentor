require_relative './../../test_helper.rb'

class PendoHelperTest < ActionView::TestCase
  def setup
    super
    helper_setup
  end

  def test_track_in_pendo
    assert_false self.send(:track_in_pendo?)

    self.stubs(:pendo_tracking_enabled?).returns(true)
    self.stubs(:working_on_behalf?).returns(false)
    self.stubs(:current_member).returns(members(:f_admin))
    assert_equal true, self.send(:track_in_pendo?)

    self.stubs(:pendo_tracking_enabled?).returns(false)
    assert_false self.send(:track_in_pendo?)

    self.stubs(:pendo_tracking_enabled?).returns(true)
    self.stubs(:working_on_behalf?).returns(true)
    assert_false self.send(:track_in_pendo?)

    self.stubs(:working_on_behalf?).returns(false)
    self.stubs(:current_member).returns(members(:f_mentor))
    self.stubs(:current_user).returns(users(:f_mentor))
    assert_false self.send(:track_in_pendo?)

    self.stubs(:current_user).returns(users(:f_admin))
    assert_equal true, self.send(:track_in_pendo?)
  end

  def test_show_pendo_launcher
    self.stubs(:mobile_device?).returns(false)
    assert_equal true, self.send(:show_pendo_launcher?)

    self.stubs(:mobile_device?).returns(true)
    assert_false self.send(:show_pendo_launcher?)

    @show_pendo_launcher_in_all_devices = true
    assert_equal true, self.send(:show_pendo_launcher?)

    @show_pendo_launcher_in_all_devices = false
    assert_equal false, self.send(:show_pendo_launcher?)
  end

  def test_render_pendo
    @current_organization = programs(:org_primary)
    @current_program = programs(:albers)
    admin_user = users(:f_admin)
    admin_member = admin_user.member
    self.stubs(:program_context).returns(@current_program)
    self.stubs(:current_member).returns(admin_member)

    self.stubs(:track_in_pendo?).returns(false)
    assert_nil render_pendo

    self.stubs(:track_in_pendo?).returns(true)
    self.stubs(:show_pendo_launcher?).returns(false)
    @current_organization.stubs(:programs_count).returns(500)
    content = render_pendo

    # visitor attributes
    assert_match(/id: \"#{admin_member.email}\"/, content)
    assert_match(/email: \"#{admin_member.email}\"/, content)
    assert_match(/name: \"#{admin_member.name(name_only: true)}\"/, content)
    assert_match(/globalAdmin: true/, content)
    assert_match(/profileUrl: \"#{member_url(admin_member)}\"/, content)
    assert_match(/environment: \"test\"/, content)

    # account attributes
    assert_match(/id: \"test_#{@current_organization.id}_#{@current_program.id}\"/, content)
    assert_match(/name: \"#{@current_organization.account_name} - #{@current_organization.name} - #{@current_program.name}\"/, content)
    assert_equal 2, content.scan(/accountName: \"#{@current_organization.account_name}\"/).size # in both account and parentAccount
    assert_match(/url: \"#{@current_organization.get_protocol}:\/\/#{@current_program.url}\"/, content)
    assert_match(/creationDate: \"#{@current_program.created_at.to_date}\"/, content)
    assert_match(/matchingMode: \"Mentee requesting mentor\"/, content)
    assert_match(/engagementMode: \"Ongoing\"/, content)
    assert_match(/mentorEnrollmentMode: \"membership_request\"/, content)
    assert_match(/menteeEnrollmentMode: \"membership_request\"/, content)

    # parentAccount attributes
    assert_match(/id: \"test_#{@current_organization.id}\"/, content)
    assert_match(/name: \"#{@current_organization.name}\"/, content)
    assert_match(/planLevel: \"#{@current_organization.verbose_subscription_type}\"/, content)
    assert_match(/url: \"#{@current_organization.get_protocol}:\/\/#{@current_organization.url}\"/, content)
    assert_match(/creationDate: \"#{@current_organization.created_at.to_date}\"/, content)
    assert_match(/nPrograms: 500/, content)
    assert_match(/nActiveMembers: #{@current_organization.current_users_with_published_profiles_count}/, content)
    assert_match(/nOngoingConnections: #{@current_organization.groups.active.count}/, content)

    assert_match(/pendo.removeLauncher/, content)

    self.stubs(:show_pendo_launcher?).returns(true)
    content = render_pendo
    assert_not_nil content
    assert_no_match(/pendo.removeLauncher/, content)
  end
end