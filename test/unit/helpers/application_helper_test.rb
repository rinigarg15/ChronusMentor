require_relative './../../test_helper.rb'

class ApplicationHelperTest < ActionView::TestCase
  include CareerDevTestHelper
  include GroupsHelper
  include WillPaginate::ViewHelpers
  include ReportsHelper

  @@skip_local_render = false
  def setup
    super
    helper_setup
  end

  def teardown
    super
    @@skip_local_render = false
  end

  def test_secure_protocol
    assert_equal 'http', secure_protocol
    Rails.application.config.stubs(:force_ssl).returns(true)
    assert_equal 'https', secure_protocol
  end

  def test_show_link
    user_1 = users(:f_student)
    user_2 = users(:f_mentor)
    member_1 = users(:student_3)
    member_2 = users(:mentor_3)
    admin_user = users(:f_admin)
    admin_member = admin_user.member
    program_level_admin_member = members(:ram)

    assert user_1.active?
    assert show_link?(user_1, admin_user)
    assert show_link?(user_1, user_2)

    user_1.suspend_from_program!(admin_user, "Not really good")
    assert show_link?(user_1, admin_user)
    assert_false show_link?(user_1, user_2)

    assert member_1.active?
    assert show_link?(member_1, admin_member)
    assert show_link?(member_1, member_2)
    assert show_link?(member_1, member_1)
    assert show_link?(member_1, program_level_admin_member)

    member_1.update_attribute(:state, Member::Status::SUSPENDED)
    assert show_link?(member_1, admin_member)
    assert_false show_link?(member_1, member_2)
    assert_false show_link?(member_1, member_1)
    assert_false show_link?(member_1, program_level_admin_member)
  end

  def test_show_send_message_link
    user_1 = users(:f_student)
    user_2 = users(:f_mentor)
    assert show_send_message_link?(user_1, user_2)

    self.expects(:current_user_or_member).once.returns(user_2)
    self.expects(:show_link?).with(user_1, user_2).twice.returns(true)
    user_2.expects(:allowed_to_send_message?).with(user_1).twice.returns(true)
    assert show_send_message_link?(user_1, user_2)
    assert show_send_message_link?(user_1)

    self.expects(:show_link?).with(user_1, user_2).once.returns(false)
    user_2.expects(:allowed_to_send_message?).with(user_1).never
    assert_false show_send_message_link?(user_1, user_2)

    self.expects(:show_link?).with(user_1, user_2).once.returns(true)
    user_2.expects(:allowed_to_send_message?).with(user_1).once.returns(false)
    assert_false show_send_message_link?(user_1, user_2)
  end

  def test_get_send_message_link
    group = groups(:mygroup)
    program = group.program
    group_mentor = group.mentors.first
    group_student = group.students.first
    admin_user = users(:f_admin)
    non_admin_user = users(:f_student)

    message_regex = /messages\/new/
    message_js_regex = /jQueryShowQtip.*messages\/new/
    scrap_regex = /\/groups\/.*?\?new_scrap=true/

    assert program.allow_user_to_send_message_outside_mentoring_area?
    assert_match message_regex, get_send_message_link(group_student, group_mentor)
    assert_match message_regex, get_send_message_link(admin_user, group_mentor)
    assert_match message_regex, get_send_message_link(non_admin_user, group_mentor)
    assert_match message_js_regex, get_send_message_link(non_admin_user, group_mentor, listing_page: true)[:js]

    program.update_attribute(:allow_user_to_send_message_outside_mentoring_area, false)
    group_mentor.reload
    assert_match scrap_regex, get_send_message_link(group_student, group_mentor)
    assert_match message_regex, get_send_message_link(admin_user, group_mentor)
    assert_match message_regex, get_send_message_link(non_admin_user, group_mentor)
    assert_match message_regex, get_send_message_link(group_student.member, group_mentor.member)

    admin_user.role_names += [RoleConstants::MENTOR_NAME]
    admin_user.save!
    group.update_members(group.mentors + [admin_user], group.students + [non_admin_user])
    group_mentor.reload
    assert_match scrap_regex, get_send_message_link(group_student, group_mentor)
    assert_match scrap_regex, get_send_message_link(admin_user, group_mentor)
    assert_match message_regex, get_send_message_link(group_mentor, admin_user.reload)
    assert_match scrap_regex, get_send_message_link(non_admin_user, group_mentor)
    assert_match scrap_regex, get_send_message_link(group_mentor, group_student, listing_page: true)[:url]

    Group.any_instance.stubs(:scraps_enabled?).returns(false)
    group_mentor.reload
    assert_match message_regex, get_send_message_link(group_student, group_mentor)
    assert_match message_regex, get_send_message_link(admin_user, group_mentor)
    assert_match message_regex, get_send_message_link(non_admin_user, group_mentor)

    Group.any_instance.stubs(:scraps_enabled?).returns(true)
    group.terminate!(admin_user, "Reason", program.permitted_closure_reasons.first.id)
    group_mentor.reload
    assert_match message_regex, get_send_message_link(group_student, group_mentor)
    assert_match message_regex, get_send_message_link(admin_user, group_mentor)
    assert_match message_regex, get_send_message_link(non_admin_user, group_mentor)
  end

  def test_formatted_time_in_words
    two_seconds_ago = 2.seconds.ago.getlocal
    two_hours_ago = 2.hours.ago.getlocal
    assert_equal "less than a minute ago", formatted_time_in_words(two_seconds_ago)
    assert_equal 'about 2 hours ago', formatted_time_in_words(two_hours_ago)

    assert_equal two_seconds_ago.strftime("%B %d, %Y at %I:%M %p"),
      formatted_time_in_words(two_seconds_ago, :no_ago => true)
    assert_equal two_seconds_ago.strftime("%B %d, %Y at %I:%M %p"),
      formatted_time_in_words(two_seconds_ago, :no_ago => true)

    t = 2.days.ago.getlocal
    assert_equal t.strftime("%B %d, %Y at %I:%M %p"), formatted_time_in_words(t)
    assert_equal t.strftime("%B %d, %Y"), formatted_time_in_words(t, :no_time => true)
    assert_equal t.strftime("%B %Y"), formatted_time_in_words(t, :no_time => true, :no_date => true)

    assert_equal t.strftime("%b %d, %Y, %I:%M %P"), formatted_time_in_words(t, :full_display_no_day_short_month => true)

    # No getlocal must be used. The input date/time must be same as output data/time
    t = Time.parse("Sat, 12 Jun 2010 00:50:49 UTC 00:00")
    assert_equal "June 12, 2010 at 12:50 AM", formatted_time_in_words(t, :no_ago => true)

    t = User.first.updated_at - 20.days
    assert_equal t.strftime("%B %d, %Y"), formatted_time_in_words(t, :no_time => true)

    t = t.to_date
    assert_equal t.strftime("%B %d, %Y"), formatted_time_in_words(t, :no_time => true)

    assert_equal t.strftime("%b %d, %Y"), formatted_time_in_words(t, :short_date => true)
  end

  def test_formatted_date_in_words
    self.stubs(:wob_member).returns(members(:f_mentor))
    two_days_ago = 2.days.ago.to_date.in_time_zone(wob_member.get_valid_time_zone)
    assert_equal two_days_ago.strftime("%B %d, %Y"), formatted_date_in_words(two_days_ago)
  end

  def test_default_if_blank
    assert_equal "hello", default_if_blank(nil, "hello")
    assert_equal "hello", default_if_blank("", "hello")
    assert_equal "good", default_if_blank(" ", "good")
    assert_equal "hey", default_if_blank("hey", "good")
  end

  # profile_questions_recently_updated? should be false if there are no questions
  def test_profile_questions_recently_updated_for_no_questions
    @current_program = programs(:albers)
    @current_user = users(:f_mentor)
    programs(:org_primary).profile_questions_with_email_and_name.destroy_all

    # No questions yet. So no update
    assert_equal(false, profile_questions_recently_updated?)
  end

  # profile_questions_recently_updated? should be false if there are questions, but they are old (> 2 weeks)
  def test_profile_questions_recently_updated_for_old_questions
    @current_program = programs(:albers)
    @current_user = users(:f_mentor)
    programs(:org_primary).profile_questions_with_email_and_name.destroy_all

    # Create a question 2 weeks back
    Timecop.freeze(15.days.ago) do
      create_mentor_question
    end
    assert_equal(false, profile_questions_recently_updated?)
  end

  # profile_questions_recently_updated? should be true if there are questions, and were recently created or updated
  def test_profile_questions_recently_updated_for_new_questions
    @current_program = programs(:albers)
    @current_user = users(:f_mentor)
    programs(:org_primary).profile_questions.destroy_all

    # Create a new question
    create_mentor_question
    assert_equal(true, profile_questions_recently_updated?)
  end

  def test_include_common_sort_by_id_fields
    assert_select_helper_function_block('input', include_common_sort_by_id_fields(sort_field: 'f', sort_order: 'o')) do
      assert_select "input[name=sort_field].cjs-sort-field", value: 'f'
      assert_select "input[name=sort_order].cjs-sort-order", value: 'o'
    end
  end

  def test_include_sort_info_for_basic_sort_by_id_options_for_top_bar
    assert_equal_hash({:sort_info=>[{:field=>"id", :order=>"desc", :label=>"Sort by most recent", :mobile_label=>"Most recent"}, {:field=>"id", :order=>"asc", :label=>"Sort by oldest", :mobile_label=>"Oldest"}], a: 1}, include_sort_info_for_basic_sort_by_id_options_for_top_bar({a: 1}))
  end

  def test_basic_sort_by_id_options_for_top_bar
    assert_equal_hash({}, basic_sort_by_id_options_for_top_bar(false, {}))
    assert_equal_hash({:sort_info=>[{:field=>"id", :order=>"desc", :label=>"Sort by most recent", :mobile_label=>"Most recent"}, {:field=>"id", :order=>"asc", :label=>"Sort by oldest", :mobile_label=>"Oldest"}], :on_select_function=>"function", :sort_field=>"sf", :sort_order=>"so"},  basic_sort_by_id_options_for_top_bar(true, {on_select_function: 'function', sort_field: 'sf', sort_order: 'so'}))
    assert_equal_hash({:sort_info=>[{:field=>"id", :order=>"desc", :label=>"Sort by most recent", :mobile_label=>"Most recent"}, {:field=>"id", :order=>"asc", :label=>"Sort by oldest", :mobile_label=>"Oldest"}], :on_select_function=>"updateSortCommon", :sort_field=>"sf", :sort_order=>"so"},  basic_sort_by_id_options_for_top_bar(true, {sort_field: 'sf', sort_order: 'so'}))
  end

  # If there's no cookie, render the prompt
  def test_render_profile_questions_change_for_no_cookie
    @current_program = programs(:albers)
    @current_user = users(:f_mentor)
    create_mentor_question

    assert_equal(true, render_profile_questions_change?)
  end

  # For an admin, it should always be false
  def test_admin_render_profile_questions_change_for_no_cookie
    @current_program = programs(:albers)
    @current_user = users(:f_admin)
    programs(:org_primary).profile_questions.destroy_all
    create_mentor_question

    assert_equal(false, render_profile_questions_change?)
  end

  # If there's a cookie, and its value timestamp is less than the latest profile update value, render the prompt
  def test_render_profile_questions_change_for_cookie_with_value_less_than_update_time
    @current_program = programs(:albers)
    @current_user = users(:f_mentor)
    @current_member = members(:f_mentor)
    @cookies = { DISABLE_PROFILE_PROMPT => '123' }
    Timecop.freeze(2.days.ago) do
      q1 = create_mentor_question
    end

    Timecop.freeze(1.days.ago) do
      ProfileAnswer.create!(:ref_obj => @current_member, :profile_question => ProfileQuestion.last, :answer_text => "Abc")
    end

    # The answers are more recent than the questions. So, the prompt should not be showable.
    assert_equal(false, render_profile_questions_change?)

    # There's a new question now. So, the prompt should be showable.
    create_mentor_question
    assert_equal(true, render_profile_questions_change?)
  end

  # If there's a cookie, and its value timestamp is greater than or equal to the ladef test_rofile_update_valuen't render the prompt
  def test_render_profile_questions_change_for_cookie_with_value_gte_than_update_time
    @current_program = programs(:albers)
    @current_user = users(:f_mentor)
    t = 3.days.ago
    @cookies = { DISABLE_PROFILE_PROMPT => t.to_i }
    Timecop.freeze(t) do
      create_mentor_question
    end

    assert_equal(false, render_profile_questions_change?)
  end

   def test_tooltip
    test_str = "hi test ' \" <b>bold</b>"
    assert_equal "<script>\n//<![CDATA[\njQuery(\"#id\").tooltip({html: true, title: '<div>hi test \\&#39; \\&quot; &lt;b&gt;bold&lt;\\/b&gt;</div>', placement: \"top\", container: \"#id\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\"#id\").on(\"remove\", function () {jQuery(\"#id .tooltip\").hide().remove();})\n//]]>\n</script>", tooltip('id', test_str)
    assert_equal "<script>\n//<![CDATA[\njQuery(\"#id\").tooltip({html: true, title: '<div>hi test \\&#39; \\&quot; &lt;b&gt;bold&lt;\\/b&gt;</div>', placement: \"top\", container: \"body\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\"#id\").on(\"remove\", function () {jQuery(\"#id .tooltip\").hide().remove();})\n//]]>\n</script>", tooltip('id', test_str, false, container: 'body')
    assert_equal "<script>\n//<![CDATA[\njQuery(\"#id\").tooltip({html: true, title: 'hi test \\' \\\" <b>bold<\\/b>', placement: \"top\", container: \"#id\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\"#id\").on(\"remove\", function () {jQuery(\"#id .tooltip\").hide().remove();})\n//]]>\n</script>", tooltip('id', test_str, false, html_escape: false)

    # With Class
    test_str = "hi test ' \" <b>bold</b>"
    assert_equal "<script>\n//<![CDATA[\njQuery(\".class\").tooltip({html: true, title: '<div>hi test \\&#39; \\&quot; &lt;b&gt;bold&lt;\\/b&gt;</div>', placement: \"top\", container: \".class\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\".class\").on(\"remove\", function () {jQuery(\".class .tooltip\").hide().remove();})\n//]]>\n</script>", tooltip('class', test_str, false, is_identifier_class: true)
    assert_equal "<script>\n//<![CDATA[\njQuery(\".class\").tooltip({html: true, title: '<div>hi test \\&#39; \\&quot; &lt;b&gt;bold&lt;\\/b&gt;</div>', placement: \"top\", container: \"body\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\".class\").on(\"remove\", function () {jQuery(\".class .tooltip\").hide().remove();})\n//]]>\n</script>", tooltip('class', test_str, false, container: 'body', is_identifier_class: true)
    assert_equal "<script>\n//<![CDATA[\njQuery(\".class\").tooltip({html: true, title: 'hi test \\' \\\" <b>bold<\\/b>', placement: \"top\", container: \".class\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\".class\").on(\"remove\", function () {jQuery(\".class .tooltip\").hide().remove();})\n//]]>\n</script>", tooltip('class', test_str, false, html_escape: false, is_identifier_class: true)
  end

  def test_popover
    test_str = "hi test ' \" <b>bold</b>"
    assert_equal "<script>\n//<![CDATA[\njQuery(\"id\").addClass(\"cjs-node-popover\"); jQuery(\"id\").popover({html: true, placement: \"bottom\", title: \"<div>title<\\/div>\", content: \"<div>hi test &#39; &quot; &lt;b&gt;bold&lt;/b&gt;<\\/div>\", container: \"body\"});\n//]]>\n</script>", popover('id', "title", test_str, container: 'body')

    assert_equal "<script>\n//<![CDATA[\njQuery(\"id\").addClass(\"cjs-node-popover\"); jQuery(\"id\").popover({html: true, placement: \"top\", title: \"<div>title<\\/div>\", content: \"<div>hi test &#39; &quot; &lt;b&gt;bold&lt;/b&gt;<\\/div>\", container: \"body\"});\n//]]>\n</script>", popover('id', "title", test_str, {container: 'body', placement: 'top'})
    
  end

  def test_translated_tab_label
    assert_equal 'Home', translated_tab_label(TabConstants::HOME)
    assert_equal 'Manage', translated_tab_label(TabConstants::MANAGE)
    assert_equal 'Forums', translated_tab_label(TabConstants::FORUMS)
    assert_equal 'Invite', translated_tab_label(TabConstants::INVITE)
    assert_equal 'Home', translated_tab_label(TabConstants::APP_HOME)
    assert_equal 'Program Overview', translated_tab_label(TabConstants::ABOUT_PROGRAM)
    assert_equal 'Question & Answers', translated_tab_label(TabConstants::QA)
    assert_equal 'Advice', translated_tab_label(TabConstants::ADVICE)
    assert_equal 'Membership Requests', translated_tab_label(TabConstants::MEMBERSHIP_REQUESTS)
    assert_equal 'Program Status', translated_tab_label(TabConstants::REPORT)
    assert_equal 'My Meetings', translated_tab_label(TabConstants::MY_MEETINGS)
    assert_equal 'My Availability', translated_tab_label(TabConstants::MY_AVAILABILITY)
    assert_equal 'Mentoring Calendar', translated_tab_label(TabConstants::MENTORING_CALENDAR)
    assert_equal 'Meetings', translated_tab_label(TabConstants::MEETINGS)
    assert_equal 'Mentoring Requests', translated_tab_label(TabConstants::MENTOR_REQUESTS)
    assert_equal 'Other translated labels', translated_tab_label('Other translated labels')
  end

  def test_get_program_context_path
    program = programs(:albers)
    organization = program.organization

    assert_equal program_root_path(:root => program.root, :src => "sidebar"), get_program_context_path(program, "sidebar")
    assert_equal root_organization_path(:src => "sidebar"), get_program_context_path(organization, "sidebar")
  end

  def test_render_tabs_with_no_subtabs
    tab_info = mock(:label => "Test", :url => "http://google.com", :subtabs => nil, :iconclass => nil, :tab_class => nil)
    tab_code = render_tab(tab_info, "active")
    set_response_text(tab_code)
    assert_select "a[href=?]", "http://google.com", :text => "Test"
  end

  def test_render_tabs_with_subtabs
    tab_info = mock()
    subtab_key_1 = "google"
    subtab_key_2 = "yahoo"
    subtabs = get_subtabs_hash

    subtabs[TabConfiguration::Tab::SubTabKeys::LINKS_LIST] << subtab_key_1
    subtabs[TabConfiguration::Tab::SubTabKeys::LINKS_LIST] << subtab_key_2
    subtabs[TabConfiguration::Tab::SubTabKeys::LINKS_LIST] << TabConstants::DIVIDER

    subtabs[TabConfiguration::Tab::SubTabKeys::LINK_LABEL_HASH][subtab_key_1] = "Google"
    subtabs[TabConfiguration::Tab::SubTabKeys::BADGE_COUNT_HASH][subtab_key_1] = 10
    subtabs[TabConfiguration::Tab::SubTabKeys::ICON_CLASS_HASH][subtab_key_1] = "fa-user-plus"
    subtabs[TabConfiguration::Tab::SubTabKeys::IS_ACTIVE_HASH][subtab_key_1] = true
    subtabs[TabConfiguration::Tab::SubTabKeys::HAS_PARTIAL_HASH][subtab_key_1] = false
    subtabs[TabConfiguration::Tab::SubTabKeys::RENDER_PATH_HASH][subtab_key_1] = "http://google.com"

    subtabs[TabConfiguration::Tab::SubTabKeys::LINK_LABEL_HASH][subtab_key_2] = "Yahoo"
    subtabs[TabConfiguration::Tab::SubTabKeys::ICON_CLASS_HASH][subtab_key_2] = "fa-user-plus-o"
    subtabs[TabConfiguration::Tab::SubTabKeys::IS_ACTIVE_HASH][subtab_key_2] = false
    subtabs[TabConfiguration::Tab::SubTabKeys::HAS_PARTIAL_HASH][subtab_key_2] = false
    subtabs[TabConfiguration::Tab::SubTabKeys::RENDER_PATH_HASH][subtab_key_2] = "http://yahoo.com"

    tab_info.stubs(:label).returns("Test")
    tab_info.stubs(:subtabs).returns(subtabs)
    tab_info.stubs(:open_by_default).returns(true)
    tab_info.stubs(:tab_class).returns("header_class")
    tab_code = render_tab(tab_info, "active")
    set_response_text(tab_code)

    assert_select "li" do
      assert_select "div.cjs_navigation_header.header_class", :text => "Test"
      assert_select "ul.nav.collapse.in" do
        assert_select "li" do
          assert_select "div.media-left.no-horizontal-padding" do
            assert_select "i.fa.fa-fw.fa-user-plus-o"
          end
          assert_select "div.media-body.row" do
            assert_select "div.col-md-12.col-xs-12.no-horizontal-padding", :text => "Yahoo"
          end
          assert_select "a.navigation_tab_link[href=?]", "http://yahoo.com", :text => "Yahoo"
        end
        assert_select "li.active" do
          assert_select "div.media-left.no-horizontal-padding" do
            assert_select "i.fa.fa-fw.fa-user-plus"
          end
          assert_select "div.media-body.row" do
            assert_select "div.col-md-10.col-xs-10.no-horizontal-padding", :text => "Google"
            assert_select "div.col-md-2.col-xs-2.no-horizontal-padding" do
              assert_select "span.badge.badge-danger.pull-right"
            end
          end
          assert_select "a.navigation_tab_link[href=?]", "http://google.com", :text => "Google10"
        end
        assert_select "li" do
          assert_select "hr.no-margins"
        end
      end
    end
  end

  def test_render_tabs_with_subtabs_with_partial
    tab_info = mock()
    subtab_key_1 = "meetings"
    subtabs = get_subtabs_hash

    subtabs[TabConfiguration::Tab::SubTabKeys::LINKS_LIST] << subtab_key_1
    subtabs[TabConfiguration::Tab::SubTabKeys::IS_ACTIVE_HASH][subtab_key_1] = true
    subtabs[TabConfiguration::Tab::SubTabKeys::HAS_PARTIAL_HASH][subtab_key_1] = true
    subtabs[TabConfiguration::Tab::SubTabKeys::RENDER_PATH_HASH][subtab_key_1] = "forums/forum_subtabs"

    tab_info.stubs(:label).returns("Test")
    tab_info.stubs(:subtabs).returns(subtabs)
    tab_info.stubs(:open_by_default).returns(true)
    tab_info.stubs(:tab_class).returns("header_class")
    tab_code = render_tab(tab_info, "active")

    set_response_text(tab_code)
    assert_select "li" do
      assert_select "div.cjs_navigation_header.header_class", :text => "Test"
      assert_select "span", :text => "RENDERING forums/forum_subtabs"
    end
  end

  def test_get_tab_link_content
    link_content = get_tab_link_content("fa-user-plus", "Link label", "#", {tab_class: "subtab_class", tab_badge_count: 10, tab_badge_class: "badge-danger"})
    set_response_text(link_content)

    assert_select "li.subtab_class" do
      assert_select "div.media-left.no-horizontal-padding" do
        assert_select "i.fa.fa-fw.fa-user-plus"
      end
      assert_select "div.media-body.row" do
        assert_select "div.col-md-10.col-xs-10.no-horizontal-padding", :text => "Link label"
        assert_select "div.col-md-2.col-xs-2.no-horizontal-padding" do
          assert_select "span.badge.badge-danger.pull-right"
        end
      end
      assert_select "a.navigation_tab_link[href=?]", "#", :text => "Link label10"
    end

    link_content = get_tab_link_content("fa-user-plus", "Link label", "#", {tab_class: "subtab_class", tab_badge_count: 10, tab_badge_class: "badge-success"})
    set_response_text(link_content)

    assert_select "li.subtab_class" do
      assert_select "div.media-left.no-horizontal-padding" do
        assert_select "i.fa.fa-fw.fa-user-plus"
      end
      assert_select "div.media-body.row" do
        assert_select "div.col-md-10.col-xs-10.no-horizontal-padding", :text => "Link label"
        assert_select "div.col-md-2.col-xs-2.no-horizontal-padding" do
          assert_select "span.badge.badge-success.pull-right"
        end
      end
      assert_select "a.navigation_tab_link[href=?]", "#", :text => "Link label10"
    end

    link_content = get_tab_link_content("fa-user-plus", "Link label", "#", {tab_class: "subtab_class"})
    set_response_text(link_content)

    assert_select "li.subtab_class" do
      assert_select "div.media-left.no-horizontal-padding" do
        assert_select "i.fa.fa-fw.fa-user-plus"
      end
      assert_select "div.media-body.row" do
        assert_select "div.col-md-12.col-xs-12.no-horizontal-padding", :text => "Link label"
      end
      assert_select "a.navigation_tab_link[href=?]", "#", :text => "Link label"
    end

    link_content = get_tab_link_content("fa-user-plus", "Link label", "#")
    set_response_text(link_content)

    assert_select "li" do
      assert_select "div.media-left.no-horizontal-padding" do
        assert_select "i.fa.fa-fw.fa-user-plus"
      end
      assert_select "div.media-body.row" do
        assert_select "div.col-md-12.col-xs-12.no-horizontal-padding", :text => "Link label"
      end
      assert_select "a.navigation_tab_link[href=?]", "#", :text => "Link label"
    end
  end

  def test_render_mobile_tab
    tab_info = mock()
    tab_info.stubs(:label).returns("Test")
    tab_info.stubs(:url).returns("#")
    tab_info.stubs(:iconclass).returns("fa fa-users-plus")
    tab_info.stubs(:mobile_tab_badge).returns("2")
    tab_info.stubs(:mobile_tab_modal_id).returns("#modal_id")
    tab_info.stubs(:active).returns(true)
    tab_info.stubs(:mobile_tab_class).returns("tab_class")

    tab_code = render_mobile_tab(tab_info)
    set_response_text(tab_code)
    assert_select "div.b-b" do
      assert_select "a.tab_class[href='#']", data: {target: "#modal_id"} do
        assert_select "div" do
          assert_select "span.label", text: "2"
          assert_select "div", text: "Test"
        end
      end
    end

    tab_info.stubs(:mobile_tab_badge).returns(nil)
    tab_info.stubs(:mobile_tab_modal_id).returns(nil)
    tab_info.stubs(:url).returns(meeting_requests_path)
    tab_info.stubs(:active).returns(false)
    tab_info.stubs(:mobile_tab_class).returns("")

    tab_code = render_mobile_tab(tab_info)
    set_response_text(tab_code)
    assert_select "div" do
      assert_select "a[href='#{meeting_requests_path}']"do
        assert_select "div" do
          assert_no_select "span.label"
          assert_select "div", text: "Test"
        end
      end
    end
  end

  def test_mobile_footer_dropup_quick_link
    dropup_link_text = mobile_footer_dropup_quick_link("Meeting", meeting_requests_path, "fa fa-calendar-plus-0", 2, {class: "list-group-item"})
    set_response_text(dropup_link_text)
    assert_select "a.list-group-item[href='#{meeting_requests_path}']"do
      assert_select "div.media-left"
      assert_select "div.media-body" do
        assert_select "div.pull-left" , text: "Meeting"
        assert_select "div.badge", text: "2", class: "badge-danger badge pull-right m-l-xs", id: ""
      end
    end
    dropup_link_text = mobile_footer_dropup_quick_link("Meeting", meeting_requests_path, "fa fa-calendar-plus-0", 0, {class: "list-group-item"})
    set_response_text(dropup_link_text)
    assert_select "a.list-group-item[href='#{meeting_requests_path}']"do
      assert_select "div.media-left"
      assert_select "div.media-body" do
        assert_select "div.pull-left" , text: "Meeting"
        assert_no_select "div.badge"
      end
    end

    dropup_link_text = mobile_footer_dropup_quick_link("Meeting", meeting_requests_path, "fa fa-calendar-plus-0", 2, {class: "list-group-item", badge_class: "abcd", badge_id: "xyz"})
    set_response_text(dropup_link_text)
    assert_select "a.list-group-item[href='#{meeting_requests_path}']"do
      assert_select "div.media-left"
      assert_select "div.media-body" do
        assert_select "div.pull-left"
        assert_select "div.badge", text: "2", class: "abcd badge pull-right m-l-xs", id: "xyz"
      end
    end
  end

  def test_is_mobile_tab_active
    self.stubs(:is_mobile_home_tab_active?).returns(true)
    assert is_mobile_tab_active?(MobileTab::Home)
    self.stubs(:is_mobile_home_tab_active?).returns(false)
    assert_false is_mobile_tab_active?(MobileTab::Home)

    self.stubs(:is_mobile_requests_tab_active?).returns(true)
    assert is_mobile_tab_active?(MobileTab::Request)
    self.stubs(:is_mobile_requests_tab_active?).returns(false)
    assert_false is_mobile_tab_active?(MobileTab::Request)

    self.stubs(:is_mobile_messages_tab_active?).returns(true)
    assert is_mobile_tab_active?(MobileTab::Message)
    self.stubs(:is_mobile_messages_tab_active?).returns(false)
    assert_false is_mobile_tab_active?(MobileTab::Message)

    self.stubs(:is_mobile_connections_tab_active?).returns(true)
    assert is_mobile_tab_active?(MobileTab::Connection)
    self.stubs(:is_mobile_connections_tab_active?).returns(false)
    assert_false is_mobile_tab_active?(MobileTab::Connection)

    self.stubs(:is_mobile_notifications_tab_active?).returns(true)
    assert is_mobile_tab_active?(MobileTab::Notification)
    self.stubs(:is_mobile_notifications_tab_active?).returns(false)
    assert_false is_mobile_tab_active?(MobileTab::Notification)

    assert is_mobile_tab_active?(MobileTab::Discover, {controller: "groups", action: "find_new"})
    assert is_mobile_tab_active?(MobileTab::Match, {controller: "users", action: "index"})
    self.stubs(:is_manage_tab_active?).returns(true)
    assert is_mobile_tab_active?(MobileTab::Manage, {controller: "users", action: "index"})
    self.stubs(:is_manage_tab_active?).returns(false)
    assert_false is_mobile_tab_active?(MobileTab::Manage, {controller: "users", action: "index"})
  end

  def test_is_mobile_home_tab_active
    assert is_mobile_tab_active?(MobileTab::Home, {controller: "programs", action: "show"})
    assert is_mobile_tab_active?(MobileTab::Home, {controller: "reports", action: "management_report"})
  end

  def test_is_mobile_requests_tab_active
    assert is_mobile_tab_active?(MobileTab::Request, {controller: "mentor_requests", action: "index"})
    assert is_mobile_tab_active?(MobileTab::Request, {controller: "meeting_requests", action: "index"})
    assert is_mobile_tab_active?(MobileTab::Request, {controller: "mentor_offers", action: "index"})
    assert is_mobile_tab_active?(MobileTab::Request, {controller: "program_events", action: "index"})
    assert is_mobile_tab_active?(MobileTab::Request, {controller: "mentor_requests", action: "index", tab: MembersController::ShowTabs::AVAILABILITY})
  end

  def test_is_mobile_connections_tab_active
    self.instance_variable_set(:@current_user, users(:f_mentor))
    self.instance_variable_set(:@current_program, programs(:albers))
    assert is_mobile_tab_active?(MobileTab::Connection, {controller: "groups", action: "show"})
    assert is_mobile_tab_active?(MobileTab::Connection, {controller: "groups", action: "index"})
    assert is_mobile_tab_active?(MobileTab::Connection, {controller: "members", action: "show", tab: MembersController::ShowTabs::AVAILABILITY, program: programs(:albers)})
    assert is_mobile_tab_active?(MobileTab::Connection, {controller: "meetings", action: "index", group_id: groups(:mygroup).id})
  end

  def test_is_mobile_messages_tab_active
    assert is_mobile_tab_active?(MobileTab::Message, {controller: "messages", action: "index"})
    assert is_mobile_tab_active?(MobileTab::Message, {controller: "admin_messages", action: "index"})
  end

  def test_is_mobile_notifications_tab_active
    assert is_mobile_tab_active?(MobileTab::Notification, {controller: "messages", action: "index"})
    assert is_mobile_tab_active?(MobileTab::Notification, {controller: "admin_messages", action: "index"})
    assert is_mobile_tab_active?(MobileTab::Notification, {controller: "program_events", action: "index"})
    assert is_mobile_tab_active?(MobileTab::Notification, {controller: "project_requests", action: "index"})
    assert_false is_mobile_tab_active?(MobileTab::Notification, {controller: "members", action: "show"})
    assert is_mobile_tab_active?(MobileTab::Notification, {controller: "members", action: "show", tab: MembersController::ShowTabs::AVAILABILITY})
  end

  def test_is_manage_tab_active
    assert is_manage_tab_active?('pages', 'index')
    assert is_manage_tab_active?('programs', 'manage')
    assert is_manage_tab_active?('programs', 'edit')
    assert is_manage_tab_active?('programs', 'new')
    assert is_manage_tab_active?('mentor_requests', 'index')
    assert is_manage_tab_active?('announcements', 'index')
    assert is_manage_tab_active?('membership_requests', 'index')
    assert is_manage_tab_active?('programs', 'invite_users')
    assert is_manage_tab_active?('users', 'new')
    assert is_manage_tab_active?('users', 'matches_for_student')
    assert is_manage_tab_active?('users', 'new_from_other_program')
    assert is_manage_tab_active?('csv_imports', '')
    assert is_manage_tab_active?('bulk_matches', '')
    assert is_manage_tab_active?('bulk_recommendations', '')
    assert is_manage_tab_active?('questions', '')
    assert is_manage_tab_active?('reports', 'index')
    assert_false is_manage_tab_active?('reports', 'management_report')
    assert is_manage_tab_active?('admins', '')
    assert is_manage_tab_active?('groups', 'index')
    assert is_manage_tab_active?('groups', 'new')
    assert is_manage_tab_active?('groups', 'add_members')
    assert is_manage_tab_active?('mentoring_tips', '')
    assert is_manage_tab_active?('surveys', '')
    assert is_manage_tab_active?('survey_questions', '')
    assert is_manage_tab_active?('programs', 'edit_analytics')
    assert is_manage_tab_active?('program_invitations', '')
    assert is_manage_tab_active?('confidentiality_audit_logs', '')
    assert is_manage_tab_active?('admin_messages', '')
    assert is_manage_tab_active?('forums', 'index')
    assert_false is_manage_tab_active?('forums', 'show')
    assert is_manage_tab_active?('mentor_request/instructions', 'index')
    assert is_manage_tab_active?('connection/questions', 'index')
    assert is_manage_tab_active?('themes', '')
    assert is_manage_tab_active?('email_templates', '')
    assert is_manage_tab_active?('profile_questions', '')
    assert is_manage_tab_active?('role_questions', '')
    assert is_manage_tab_active?('mailer_templates', '')
    assert is_manage_tab_active?('mailer_widgets', '')
    assert is_manage_tab_active?('membership_questions', '')
    assert is_manage_tab_active?('resources', '')
    assert is_manage_tab_active?('admin_views', '')
    assert is_manage_tab_active?('flags', 'index')
    assert is_manage_tab_active?('posts', 'moderatable_posts')
    assert is_manage_tab_active?('meetings', 'mentoring_sessions')
    assert is_manage_tab_active?('data_imports', '')
    assert is_manage_tab_active?('organization_languages', '')
    assert is_manage_tab_active?('match_configs', '')
    assert is_manage_tab_active?('mentoring_models', '')
    assert is_manage_tab_active?('campaign_management/user_campaigns', '')
    assert is_manage_tab_active?('group_checkins', '')
    assert is_manage_tab_active?('campaign_management/abstract_campaign_messages', '')
    assert is_manage_tab_active?('translations', '')
    self.stubs(:current_user).returns(users(:f_student_pbe))
    assert_false is_manage_tab_active?('project_requests', 'index')
    self.stubs(:current_user).returns(users(:f_admin_pbe))
    assert is_manage_tab_active?('project_requests', 'index')
  end

  def test_render_subtab_in_tab
    tab_info = mock()
    subtab_key = "meetings"
    subtabs = get_subtabs_hash

    subtabs[TabConfiguration::Tab::SubTabKeys::LINK_LABEL_HASH][subtab_key] = "Link label"
    subtabs[TabConfiguration::Tab::SubTabKeys::BADGE_COUNT_HASH][subtab_key] = 10
    subtabs[TabConfiguration::Tab::SubTabKeys::ICON_CLASS_HASH][subtab_key] = "fa-user-plus"
    link_or_partial = "#"
    subtab_class = "subtab_class"

    tab_info.stubs(:subtabs).returns(subtabs)

    subtab_content = render_subtab_in_tab(tab_info, subtab_key, link_or_partial, subtab_class)
    set_response_text(subtab_content)

    assert_select "li.subtab_class" do
      assert_select "div.media-left.no-horizontal-padding" do
        assert_select "i.fa.fa-fw.fa-user-plus"
      end
      assert_select "div.media-body.row" do
        assert_select "div.col-md-10.col-xs-10.no-horizontal-padding", :text => "Link label"
        assert_select "div.col-md-2.col-xs-2.no-horizontal-padding" do
          assert_select "span.badge.badge-danger.pull-right"
        end
      end
      assert_select "a.navigation_tab_link[href=?]", "#", :text => "Link label10"
    end

    subtab_key = TabConstants::DIVIDER

    subtab_content = render_subtab_in_tab(tab_info, subtab_key, link_or_partial, subtab_class)
    set_response_text(subtab_content)

    assert_select "li" do
      assert_select "hr.no-margins"
    end
  end

  def test_show_mobile_connections_tab
    user = users(:f_mentor)
    assert show_mobile_connections_tab?(user)
    program = user.program
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    program.enable_feature(FeatureName::CALENDAR, true)
    program.reload
    user.update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    user.groups.active.delete_all
    assert_false show_mobile_connections_tab?(user.reload)

    user = users(:f_student)
    assert show_mobile_connections_tab?(user)

    user = users(:f_admin)
    assert_false show_mobile_connections_tab?(user)
  end

  def test_render_tab_without_subtabs
    tab_info = mock()
    tab_class = "tab_class"

    tab_info.stubs(:label).returns(UnicodeUtils.upcase(_Meetings))
    tab_info.stubs(:url).returns("#")
    tab_info.stubs(:iconclass).returns("fa-users")
    tab_info.stubs(:tab_class).returns("hidden-sm")

    tab_content = render_tab_without_subtabs(tab_info, tab_class)
    set_response_text(tab_content)

    assert_select "li.tab_class.hidden-sm" do
      assert_select "a[href=?]", "#", :text => UnicodeUtils.upcase(_Meetings) do
        assert_select "div.media-body"
      end
    end

    tab_content = render_tab_without_subtabs(tab_info, tab_class, {non_logged_in: true})
    set_response_text(tab_content)

    assert_select "li.tab_class.hidden-sm" do
      assert_select "a[href=?]", "#", :text => UnicodeUtils.upcase(_Meetings) do
        assert_no_select "div.media-body"
      end
    end

    tab_info.stubs(:label).returns(TabConstants::DIVIDER)

    tab_content = render_tab_without_subtabs(tab_info, tab_class)
    set_response_text(tab_content)

    assert_select "li.tab_class.hidden-sm" do
      assert_select "hr.no-margins"
    end
  end

  def test_date_range_filter_header
    daterange_values = {start: Date.new(2018,9,10), end: Date.new(2018,9,20)}
    assert_select_helper_function_block 'a#report_date_range', date_range_filter_header(daterange_values) do
      assert_select "span.cjs_reports_time_filter", html: get_reports_time_filter(daterange_values)
    end
    assert_select_helper_function_block 'a#report_date_range_123', date_range_filter_header(daterange_values, id_suffix: "_123") do
      assert_select "span.cjs_reports_time_filter", html: get_reports_time_filter(daterange_values)
    end
    assert_select_helper_function_block 'a.some_class', date_range_filter_header(daterange_values, id_suffix: "_123", additional_header_class: "some_class") do
      assert_select "span.cjs_reports_time_filter", html: get_reports_time_filter(daterange_values)
    end
  end

  def test_get_sidebar_navigation_header_content
    tab_info = mock()

    tab_info.stubs(:label).returns("Header Text")
    tab_info.stubs(:open_by_default).returns(false)
    tab_info.stubs(:tab_class).returns("cjs_meetings_header")

    header_content = get_sidebar_navigation_header_content(tab_info)
    set_response_text(header_content)

    assert_select "div.cjs_navigation_header.cjs_meetings_header", :text => "Header Text" do
      assert_select "i.fa-caret-down.cjs_open_icon.hide"
      assert_select "i.fa-caret-left.cjs_close_icon"
    end

    tab_info.stubs(:open_by_default).returns(true)

    header_content = get_sidebar_navigation_header_content(tab_info)
    set_response_text(header_content)

    assert_select "div.cjs_navigation_header.cjs_meetings_header", :text => "Header Text" do
      assert_select "i.fa-caret-down.cjs_open_icon"
      assert_select "i.fa-caret-left.cjs_close_icon.hide"
    end
  end

  def test_email_notification_consequences_for_multiple_mailers_html
    program = programs(:albers)
    mailers = [GroupCreationNotificationToMentor, GroupCreationNotificationToStudents, GroupCreationNotificationToCustomUsers]
    mailers.each {|mailer| program.mailer_template_enable_or_disable(mailer, true) }
    content = email_notification_consequences_for_multiple_mailers_html(mailers, program: program)
    assert_equal "An email will be sent to the users (<a target=\"_blank\" href=\"/mailer_templates/whtckoad/edit?src=read_sysemail\">mentors</a> and <a target=\"_blank\" href=\"/mailer_templates/6tkd5hoc/edit?src=read_sysemail\">students</a>) if you complete this action.", content
    assert content.html_safe?
    program.mailer_template_enable_or_disable(GroupCreationNotificationToCustomUsers, false)
    assert_equal "An email will be sent to the users (<a target=\"_blank\" href=\"/mailer_templates/whtckoad/edit?src=read_sysemail\">mentors</a> and <a target=\"_blank\" href=\"/mailer_templates/6tkd5hoc/edit?src=read_sysemail\">students</a>) if you complete this action.", content
    program.mailer_template_enable_or_disable(GroupCreationNotificationToMentor, false)
    assert_equal "An email is usually sent to the users as part of completing this action, but has been disabled for <a target=\"_blank\" href=\"/mailer_templates/whtckoad/edit?src=read_sysemail\">mentors</a>, and enabled only for <a target=\"_blank\" href=\"/mailer_templates/6tkd5hoc/edit?src=read_sysemail\">students</a>.", email_notification_consequences_for_multiple_mailers_html(mailers, program: program)
    program.mailer_template_enable_or_disable(GroupCreationNotificationToStudents, false)
    assert_equal "An email is usually sent to the users (<a target=\"_blank\" href=\"/mailer_templates/whtckoad/edit?src=read_sysemail\">mentors</a> and <a target=\"_blank\" href=\"/mailer_templates/6tkd5hoc/edit?src=read_sysemail\">students</a>) as part of completing this action, but has been disabled. No email will be sent.", email_notification_consequences_for_multiple_mailers_html(mailers, program: program)
    assert_equal "An email is usually sent to the selected users (<a target=\"_blank\" href=\"/mailer_templates/whtckoad/edit?src=read_sysemail\">mentors</a> and <a target=\"_blank\" href=\"/mailer_templates/6tkd5hoc/edit?src=read_sysemail\">students</a>) as part of completing this action, but has been disabled. No email will be sent.", email_notification_consequences_for_multiple_mailers_html(mailers, program: program, selected_users: true)
  end

  def test_email_notification_consequences_on_action_html
    program = programs(:albers)
    content = email_notification_consequences_on_action_html(ContentModerationUserNotification, organization_or_program: program, div_enclose: false)
    assert content.html_safe?
    assert_equal "An <a target=\"_blank\" href=\"/mailer_templates/5ycj4x60/edit?src=read_sysemail\">email</a> will be sent to the author of the post if you complete this action.", content
    assert_equal "<div class=\"test-abc\">An <a target=\"_blank\" href=\"/mailer_templates/5ycj4x60/edit?src=read_sysemail\">email</a> will be sent to the author of the post if you complete this action.</div>", email_notification_consequences_on_action_html(ContentModerationUserNotification, organization_or_program: program, div_class: "test-abc")
    assert_false program.email_template_disabled_for_activity?(ContentModerationUserNotification)
    program.mailer_template_enable_or_disable(ContentModerationUserNotification, false)
    content = email_notification_consequences_on_action_html(ContentModerationUserNotification, organization_or_program: program, div_enclose: false)
    assert content.html_safe?
    assert_equal "An <a target=\"_blank\" href=\"/mailer_templates/5ycj4x60/edit?src=read_sysemail\">email</a> is usually sent to the author of the post as part of completing this action, but has been disabled. No email will be sent.", content
    assert_equal "<div class=\"test-abc\">An <a target=\"_blank\" href=\"/mailer_templates/5ycj4x60/edit?src=read_sysemail\">email</a> is usually sent to the author of the post as part of completing this action, but has been disabled. No email will be sent.</div>", email_notification_consequences_on_action_html(ContentModerationUserNotification, organization_or_program: program, div_class: "test-abc")

    # count related
    stub_current_program(program)
    assert_false program.email_template_disabled_for_activity?(MembershipRequestAccepted)
    assert_equal "An <a target=\"_blank\" href=\"/mailer_templates/z6g2m5of/edit?src=read_sysemail\">email</a> invitation with the message will be sent to the selected 5 users if you complete this action.", email_notification_consequences_on_action_html(MembershipRequestAccepted, with_count: true, count: 5, div_enclose: false)
    assert_equal "An <a target=\"_blank\" href=\"/mailer_templates/z6g2m5of/edit?src=read_sysemail\">email</a> invitation with the message will be sent to the user if you complete this action.", email_notification_consequences_on_action_html(MembershipRequestAccepted, with_count: true, count: 1, div_enclose: false)
    program.mailer_template_enable_or_disable(MembershipRequestAccepted, false)
    assert_equal "An <a target=\"_blank\" href=\"/mailer_templates/z6g2m5of/edit?src=read_sysemail\">email</a> invitation with the message is usually sent to the selected 5 users as part of completing this action, but has been disabled. No email will be sent.", email_notification_consequences_on_action_html(MembershipRequestAccepted, with_count: true, count: 5, div_enclose: false)
    assert_equal "An <a target=\"_blank\" href=\"/mailer_templates/z6g2m5of/edit?src=read_sysemail\">email</a> invitation with the message is usually sent to the user as part of completing this action, but has been disabled. No email will be sent.", email_notification_consequences_on_action_html(MembershipRequestAccepted, with_count: true, count: 1, div_enclose: false)
    assert_equal link_to("email", edit_mailer_template_path(ContentModerationUserNotification.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), target: :_blank), email_notification_consequences_on_action_html(ContentModerationUserNotification, organization_or_program: program, return_email_link_only: true)
    assert_equal link_to("acceptor mail", edit_mailer_template_path(ContentModerationUserNotification.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL), target: :_blank), email_notification_consequences_on_action_html(ContentModerationUserNotification, organization_or_program: program, return_email_link_only: true, email_link_text: "acceptor mail")

    # testing default
    mail_klass = NewMentorRequest
    main_translation_key = "email_translations.#{mail_klass.name.underscore}"
    secondary_translation_key = "enabled_html"
    assert_false I18n.t(main_translation_key).keys.include?(secondary_translation_key.to_sym)
    assert_equal "An <a target=\"_blank\" href=\"/mailer_templates/#{mail_klass.mailer_attributes[:uid]}/edit?src=read_sysemail\">email</a> will be sent to the users if you complete this action.", email_notification_consequences_on_action_html(mail_klass, organization_or_program: program, div_enclose: false)
  end

  def test_inner_tabs
    tab_info_list = [
      { label: "A", url: "javascript:void(0)", tab_class: "disabled" },
      { label: "B", url: "https://google.com", tab_class: "disabled", link_options: { id: "b_link_id" } },
      { label: "C", url: "javascript:void(0)", active: true },
      { tab_class: "dropdown", dropdown: { options: { title: "D & E" }, actions: [ { label: "D", url: "https://chronus.com" }, { label: "E", js: "javascript:void(0)" } ] } }
    ]

    content = inner_tabs(tab_info_list, tab_position_class: "tabs-left")
    assert_select_helper_function_block "div.tabs-container.inner_tabs", content do
      assert_select "div.tabs-left" do
        assert_select "ul.nav.nav-tabs" do
          assert_select "li.disabled", count: 2
          assert_select "li.active", count: 1
          assert_select "li.dropdown", count: 1
          assert_select "li.disabled" do
            assert_select "a[href=?]", "javascript:void(0)", text: "A", count: 1
            assert_select "a#b_link_id[href=?]", "https://google.com", text: "B", count: 1
          end
          assert_select "li.active" do
            assert_select "a[href=?]", "javascript:void(0)", text: "C"
          end
          assert_select "li.dropdown" do
            assert_select "a[data-toggle='dropdown']", text: "D & E", count: 1
            assert_select "ul.dropdown-menu" do
              assert_select "a[href=?]", "https://chronus.com", text: "D", count: 1
              assert_select "a[href=?]", "javascript:void(0)", text: "E", count: 1
            end
          end
        end
      end
    end

    assert_nil inner_tabs([])
  end

  def test_radio_button_filter_for_cur_value
    self.expects(:url_for).returns("/mentor_requests")
    stub_request_parameters
    value = 'all'
    str = radio_button_filter("All", value, value, :list)
    set_response_text(str)
    assert_select "input[type=radio][checked=checked][value='#{value}']"
  end

  def test_radio_button_filter_for_non_cur_value
    self.expects(:url_for).returns("/mentor_requests")
    stub_request_parameters
    cur_value = 'all'; filter_value = 'none'
    str = radio_button_filter("All", cur_value, filter_value, :list)
    set_response_text(str)
    assert_select "input[type=radio][value='#{filter_value}']"
    assert_no_select 'input[type=radio][checked=checked]'
  end

  def test_pluralize_only_text
    assert_equal 'bag', pluralize_only_text(1, 'bag', 'bags')
    assert_equal 'bags', pluralize_only_text(2, 'bag', 'bags')
    assert_equal 'bags', pluralize_only_text(0, 'bag', 'bags')
    assert_equal 'fans', pluralize_only_text(3, 'bag', 'fans')
  end

  def test_search_view
    assert_false search_view?
    @search_query = ""
    assert search_view?
    @search_query = nil
    assert_false search_view?
    @search_query = "Hi"
    assert search_view?
  end

  def test_non_existing_user_picture
    str = non_existing_user_picture
    set_response_text(str)

    assert_select 'img', :alt=> "User_non_existing", :src=> /http:\/\/test-asset-host\.chronus\.com\/assets\/user_non_existing\.jpg/
  end

  def test_get_valid_emails
    test_emails = ",,\r\n, \r\ntest.mail@mail.com\ntest@mail.com, abcd, \n\r\n\r, test@gmail.com, a b, test@gmail.com"
    valid_emails = get_valid_emails(test_emails)
    assert_equal "test@gmail.com", valid_emails
  end

  def test_generate_block_with_initials
    current_user = users(:f_mentor)
    set_response_text generate_block_with_initials(current_user.member, :small)
    assert_select "div.image_with_initial.inline.image_with_initial_dimensions_small.profile-picture-white_and_grey.profile-font-styles[title='Good unique name']", {text: "GN"}
  end

  def test_member_picture_for_generating_image_with_initials
    @current_user = users(:f_mentor)
    set_response_text(member_picture(@current_user.member, {size: :small, new_size: :tiny}))
    assert_select 'div.member_box' do
      assert_select 'a' do
        assert_select 'a.no-text-decoration'
        assert_select 'div.inline', text: "GN"
        assert_select 'div.image_with_initial_dimensions_tiny', :title => "Good unique name"
        assert_select 'div.profile-picture-white_and_grey'
        assert_select 'div.profile-font-styles'
      end
    end

    set_response_text(member_picture(@current_user.member, {size: :small, new_size: :tiny, style_name_without_link: "member_name_class"}))
    assert_select 'div.member_box.small' do
      assert_select 'a' do
        assert_select 'a.no-text-decoration'
        assert_select 'div.inline', text: "GN"
        assert_select 'div.image_with_initial_dimensions_tiny', :title => "Good unique name"
        assert_select 'div.profile-picture-white_and_grey'
        assert_select 'div.profile-font-styles'
      end
      assert_select 'span.member_name_class', text: "Good unique name"
    end

    set_response_text(member_picture(@current_user.member, {size: :small, new_size: :tiny, style_name_without_link: "member_name_class", skip_outer_class: true}))
    assert_no_select 'div.member_box'
    assert_select 'a' do
      assert_select 'a.no-text-decoration'
      assert_select 'div.inline', text: "GN"
      assert_select 'div.image_with_initial_dimensions_tiny', :title => "Good unique name"
      assert_select 'div.profile-picture-white_and_grey'
      assert_select 'div.profile-font-styles'
    end
    assert_select 'span.member_name_class', text: "Good unique name"

    ProfilePicture.create!(:member => @current_user.member, :image => nil, :not_applicable => true)
    set_response_text(member_picture(@current_user.member, {size: :small, new_size: :tiny}))
    assert_select 'a' do
      assert_select 'a.no-text-decoration'
      assert_select 'div.inline', text: "GN"
      assert_select 'div.image_with_initial_dimensions_tiny', :title => "Good unique name"
      assert_select 'div.profile-picture-white_and_grey'
      assert_select 'div.profile-font-styles'
    end
  end

  def test_build_dropdown_filters_without_button
    set_response_text(build_dropdown_filters_without_button("All Members", [{label: "Action 1"}, {label: "Action 2"}, {label: "Action 3"}], options = {id: "test_id_1"}))
    assert_select 'div.group-filters' do
      assert_select 'a' do
        assert_select 'a.text-default'
      end
      assert_select 'a#test_id_1', text: "All Members"
      assert_select 'ul.dropdown-menu' do
        assert_select 'li', text: "Action 1"
        assert_select 'li', text: "Action 2"
        assert_select 'li', text: "Action 3"
      end
    end
  end

  def ignore_test_user_picture_for_anonymous_view # Rails3T
    fetch_role(:albers, :student).remove_permission('view_mentors')
    assert_false users(:f_student).reload.can_view_mentors?

    ProfilePicture.create(
      :member => members(:f_mentor),
      :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    )

    assert members(:f_mentor).reload.profile_picture

    self.expects(:current_user).at_least(0).returns(users(:f_student))
    set_response_text(user_picture(users(:f_mentor)))
    assert_select "img[src=?]", /^#{UserConstants::DEFAULT_PICTURE[:large]}(\?\d+)?/
    assert_select "a[href=?]", member_path(members(:f_mentor)), :count => 0

    self.expects(:current_user).at_least(0).returns(users(:student_2))
    set_response_text(user_picture(users(:f_mentor), :current_user => users(:student_2)))
    assert_select "img[src=?]", /^#{UserConstants::DEFAULT_PICTURE[:large]}(\?\d+)?/
    assert_select "a[href=?]", member_path(members(:f_mentor)), :count => 0

    self.expects(:current_user).at_least(0).returns(users(:f_mentor_student))
    set_response_text(user_picture(users(:f_mentor), :current_user => users(:f_mentor_student)))
    assert_select "a[href=?]", member_path(members(:f_mentor)) do
      assert_select "img[src=?]", members(:f_mentor).picture_url(:large)
    end

    assert_select "a[href=?]", member_path(members(:f_mentor)), :text => members(:f_mentor).name
  end

  def test_per_page_selector_v3
    ajax_content = per_page_selector_v3(users_path, 25, { per_page_option: [25, 50, 75, 100], use_ajax: true } )
    assert_match /select.* id=\"items_per_page_selector\" onchange=\"submitPerPageSelectorFormAjax\(this.value\)/, ajax_content
    assert_match /option selected=\"selected\" value=\"25\">25/, ajax_content
    assert_match /option value=\"50\">50/, ajax_content
    assert_match /option value=\"75\">75/, ajax_content
    assert_match /option value=\"100\">100/, ajax_content
    assert_no_match(/change_items_form/, ajax_content)

    ajax_content2 = per_page_selector_v3(users_path, 25, { per_page_option: [25, 50, 75, 100], use_ajax: true, ajax_function: 'something' } )
    assert_match (/select.* id=\"items_per_page_selector\" onchange=\"something\(this.value\)/), ajax_content2
    assert_match (/option selected=\"selected\" value=\"25\">25/), ajax_content2
    assert_match (/option value=\"50\">50/), ajax_content2
    assert_match (/option value=\"75\">75/), ajax_content2
    assert_match (/option value=\"100\">100/), ajax_content2
    assert_no_match(/change_items_form/, ajax_content2)

    non_ajax_content = per_page_selector_v3(users_path, 25, { per_page_option: [25, 50, 75, 100], url_params: { sort: "name" } } )
    assert_match /select.* id=\"items_per_page_selector\" onchange=\"submitPerPageSelectorForm\(this.value\)/, non_ajax_content
    assert_match /option selected=\"selected\" value=\"25\">25/, non_ajax_content
    assert_match /option value=\"50\">50/, non_ajax_content
    assert_match /option value=\"75\">75/, non_ajax_content
    assert_match /option value=\"100\">100/, non_ajax_content
    assert_match /form action=\"\/users\" method=\"get\" id=\"change_items_form\" class=\"hide\"/, non_ajax_content
    assert_match /input type=\"hidden\" name=\"items_per_page\" id=\"change_items_field\" value=\"\"/, non_ajax_content
    assert_match /input type=\"hidden\" name=\"sort\" id=\"sort\" value=\"name\"/, non_ajax_content
  end

  def test_vertical_filters
    content = vertical_filters("Hello", [
        {:text => "Great", :url => "http://great.com"},
        {:text => "Hello", :url => "/hello", :count => 5},
        {:text => "Test", :url => "/test?abc=true", :disabled => true},
        {:text => "Success", :url => "/success"}
      ]
    )

    set_response_text content
    assert_select ".vertical_filters" do
      assert_select "li" do
        assert_select "a[href=?]", "http://great.com", :text => "Great"
      end

      assert_select "li.gray-bg" do
        assert_select "a[href=?]", "/hello", :text => "Hello (5)"
      end

      assert_select "li" do
        assert_select "a.disabled[href=?]", "javascript:void(0)", :text => "Test"
      end

      assert_select "li" do
        assert_select "a[href=?]", "/success", :text => "Success"
      end
    end
  end

  def test_chrng_template_cache
    ret = chrng_template_cache("id.html", element_name: "dom-element") { "abc" }
    assert_equal "<script type=\"text/ng-template\" id=\"id.html\">abc</script>", ret
    assert_equal ["dom-element"], @_angularjs_element_directives
  end

  def test_fetch_status_icon_for_enabled_message
    uid = NewArticleNotification.mailer_attributes[:uid]
    template = Mailer::Template.create!(:uid => NewArticleNotification.mailer_attributes[:uid], :program => programs(:org_primary))
    template.update_attribute(:enabled, true)
    assert template.enabled?

    text = fetch_status_icon({:uid => uid},
      update_status_mailer_template_path(uid, :email_template => {:status => Mailer::Template::Status::DISABLED}),
      update_status_mailer_template_path(uid, :email_template => {:status => Mailer::Template::Status::ENABLED}),
      true)

    set_response_text(text)

    assert_select "span#status_icon_#{uid}" do
      assert_select 'a' do
        assert_select "i#toggle_img_#{uid}"
      end
    end
  end

  def test_fetch_status_icon_for_disabled_message
    uid = NewArticleNotification.mailer_attributes[:uid]
    template = Mailer::Template.create!(:uid => NewArticleNotification.mailer_attributes[:uid], :program => programs(:org_primary))
    template.update_attribute(:enabled, false)
    assert_false template.enabled?

    text = fetch_status_icon({:uid => uid},
      update_status_mailer_template_path(uid, :email_template => {:status => Mailer::Template::Status::DISABLED}),
      update_status_mailer_template_path(uid, :email_template => {:status => Mailer::Template::Status::ENABLED}),
      false)

    set_response_text(text)

    assert_select "span#status_icon_#{uid}" do
      assert_select 'a' do
        assert_select "i#toggle_img_#{uid}"
      end
    end
  end

  def test_get_content_after_page_load
    text = get_content_after_page_load("http://google.com")
    set_response_text(text)

    assert_select "script", :text => /jQuery\(function.*jQuery.ajax\('http:\/\/google.com'/
  end

  def test_dynamic_text_filter_box_with_handler_argument
    set_response_text(dynamic_text_filter_box("solar_system", "planet_earth", "photoSynthesis", {:handler_argument => "generate_energy"}))

    assert_select "div.cui_find_and_select_item" do
      assert_select "div#solar_system" do
        assert_select "input#quick_planet_earth", :name => "quick_find", :type => "text"
      end
      assert_select "div.input-group-btn" do
        assert_select "button.dropdown-toggle", :text => "Show"
        assert_select "a.show_selected", :text => "Selected", :onclick => /photoSynthesis\.showSelected\(\'generate_energy\'\)/
        assert_select "a", :text => "All", :onclick => /photoSynthesis\.showAll\(\'generate_energy\'\)/
      end
    end
  end

  def test_dynamic_text_filter_box_without_handler_argument
    set_response_text(dynamic_text_filter_box("solar_system", "planet_earth", "photoSynthesis"))

    assert_select "div.cui_find_and_select_item" do
      assert_select "div#solar_system" do
        assert_select "input#quick_planet_earth", :name => "quick_find", :type => "text"
      end
      assert_select "div.input-group-btn" do
        assert_select "button.dropdown-toggle", :text => "Show"
        assert_select "a.show_selected", :text => "Selected", :onclick => /photoSynthesis\.showSelected\(\)/
        assert_select "a", :text => "All", :onclick => /photoSynthesis\.showAll\(\)/
      end
    end
  end

  def test_dynamic_text_filter_box_with_show_helper
    set_response_text(dynamic_text_filter_box("solar_system", "planet_earth", "photoSynthesis", {:handler_argument => "generate_energy", :display_show_helper => true, :display_select_helper => false}))

    assert_select "div.cui_find_and_select_item" do
      assert_select "div#solar_system" do
        assert_select "input#quick_planet_earth", :name => "quick_find", :type => "text"
      end
      assert_select "div.input-group-btn" do
        assert_select "button.dropdown-toggle", :text => "Show"
        assert_select "a.show_selected", :text => "Selected", :onclick => /photoSynthesis\.showSelected\(\'generate_energy\'\)/
        assert_select "a", :text => "All", :onclick => /photoSynthesis\.showAll\(\'generate_energy\'\)/
      end

      assert_select "button.dropdown-toggle", :text => "Select", :count => 0
    end
  end

  def test_dynamic_text_filter_box_with_select_helper
    set_response_text(dynamic_text_filter_box("solar_system", "planet_earth", "photoSynthesis", {:handler_argument => "generate_energy", :display_show_helper => false, :display_select_helper => true}))

    assert_select "div.cui_find_and_select_item" do
      assert_select "div#solar_system" do
        assert_select "input#quick_planet_earth", :name => "quick_find", :type => "text"
      end
      assert_select "div.input-group-btn" do
        assert_select "button.dropdown-toggle", :text => "Select"
        assert_select "a.select_all", :text => "All", :onclick => /photoSynthesis\.showSelected\(\'generate_energy\'\)/
        assert_select "a.select_none", :text => "None", :onclick => /photoSynthesis\.showAll\(\'generate_energy\'\)/
      end

      assert_select "button.dropdown-toggle", :text => "Show", :count => 0
    end
  end

  def test_show_noscript_warning
    set_response_text(show_noscript_warning)
    assert_select("noscript") do
      assert_select "div#noscript_warning", :text => /Javascript is not currently enabled in your browser. Please enable Javascript in order for this site to work properly/ do
        assert_select "a", :href => "http://www.google.com/support/bin/answer.py?answer=23852", :target => "_blank", :text => "Please enable Javascript"
      end
    end
  end

  def test_program_listing
    p1 = programs(:albers)
    assert_select_helper_function "a[href=\"/p/albers/\"][title=\"Albers Mentor Program\"]", program_listing(p1), text: "Albers Mento..."
  end

  def test_display_error_flash
    @@skip_local_render = true
    member = create_member
    member.first_name = "sample123"
    member.save

    assert_match /toastr.clear.*toastr.error.*Please correct the below error\(s\) highlighted in red.*/m, display_error_flash(member)
    assert_match /toastr.clear.*toastr.error.*sample error.*/m, display_error_flash(member, "sample error")

    member.first_name = "sample"
    member.save
    assert_nil display_error_flash(member)
  end

  def test_email_recipients_note
    set_response_text(email_recipients_note("all advisors"))
    assert_select "p", text: "Note: Please note that this will send an email to all advisors" do
      assert_select "b", text: "Note:"
    end
  end

  def test_generate_slots_list
    slots_list = generate_slots_list(30)
    assert_equal [
      "12:00 am", "12:30 am", "01:00 am", "01:30 am", "02:00 am",
      "02:30 am", "03:00 am", "03:30 am", "04:00 am", "04:30 am", "05:00 am",
      "05:30 am", "06:00 am", "06:30 am", "07:00 am", "07:30 am", "08:00 am",
      "08:30 am", "09:00 am", "09:30 am", "10:00 am", "10:30 am", "11:00 am",
      "11:30 am", "12:00 pm", "12:30 pm", "01:00 pm", "01:30 pm", "02:00 pm",
      "02:30 pm", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm",
      "05:30 pm", "06:00 pm", "06:30 pm", "07:00 pm", "07:30 pm", "08:00 pm",
      "08:30 pm", "09:00 pm", "09:30 pm", "10:00 pm", "10:30 pm", "11:00 pm",
      "11:30 pm", "12:00 am"], slots_list

    slots_list = generate_slots_list(30, 3)
    assert_equal ["12:00 am", "12:30 am", "01:00 am", "01:30 am", "02:00 am", "02:30 am", "03:00 am"], slots_list

    slots_list = generate_slots_list(60, 3)
    assert_equal ["12:00 am", "01:00 am", "02:00 am", "03:00 am"], slots_list
  end

  def test_get_contact_admin_path
    program = programs(:albers)
    setup_admin_custom_term
    current_user_is users(:f_admin)
    assert_equal content_tag(:a, "Contact Super Admin", :href => contact_admin_url, :class=>"no-waves"), get_contact_admin_path(program)
    assert_equal ["Contact Super Admin", contact_admin_url], get_contact_admin_path(program, :as_array => true)
    assert_equal content_tag(:a, "Custom label", :href => contact_admin_url, :class=>"no-waves"), get_contact_admin_path(program, :label => "Custom label")
    assert_equal contact_admin_url, get_contact_admin_path(program, :only_url => true)
    assert_equal contact_admin_url(:type => 'test'), get_contact_admin_path(program, :only_url => true, :url_params => {:type => 'test'})
    program.contact_admin_setting = ContactAdminSetting.new
    program.contact_admin_setting.label_name = "Contact HR"
    program.contact_admin_setting.contact_url = "mailto:test@test.com"
    program.contact_admin_setting.save!
    assert_equal content_tag(:a, "Contact HR", href: "mailto:test@test.com", class: "no-waves"), get_contact_admin_path(program)
    assert_equal content_tag(:a, "Contact HR", href: "mailto:test@test.com", class: "no-waves", target: :blank), get_contact_admin_path(program, target: :blank)
    assert_equal ["Contact HR", "mailto:test@test.com"], get_contact_admin_path(program, :as_array => true)
    assert_equal content_tag(:a, "Custom label", :href => "mailto:test@test.com", :class=>"no-waves"), get_contact_admin_path(program, :label => "Custom label")
    assert_equal "mailto:test@test.com", get_contact_admin_path(program, :only_url => true, :url_params => {:type => 'test'})
  end

  def test_has_education_experience
    questions = [profile_questions(:profile_questions_1), profile_questions(:profile_questions_2)]
    assert_false has_importable_question?(questions)
    questions << profile_questions(:profile_questions_7)
    assert has_importable_question?(questions)
    questions << profile_questions(:profile_questions_6)
    assert has_importable_question?(questions)
    questions = [profile_questions(:profile_questions_6)]
    assert_false has_importable_question?(questions)
    questions = [profile_questions(:profile_questions_7)]
    assert has_importable_question?(questions)
    questions = []
    assert_false has_importable_question?(questions)
  end

  def test_match_score_tooltip
    @current_program = programs(:albers)
    @current_program.zero_match_score_message = 'message'
    self.expects(:current_program).returns(@current_program)

    tt = match_score_tool_tip(95)
    assert_match("This shows the compatibility percentage between you and the mentor. Matching will be based on similar fields.", tt)

    tt = match_score_tool_tip(0)
    assert_match("message", tt)

    tt = match_score_tool_tip(nil)
    assert_match("Match score for this user is not available at this time, please try again later", tt)
  end

  def test_to_daterangepicker_display_format_string
    assert_match("mm/dd/yy", to_daterangepicker_display_format_string("%m/%d/%Y"))
  end

  def test_to_js_datetime_format_string
    assert_match("MM/dd/yyyy", to_js_datetime_format_string("%m/%d/%Y"))
  end

  def test_response_flash
    @@skip_local_render = true
    output = response_flash("flash_container_id", :class => "alert-danger", :message => "Error Message")
    assert_match("toastr.error('Error Message', '', {})", output)

    output = response_flash("flash_container_id", :class => "alert-warning", :message => "Warning Message")
    assert_match("toastr.warning('Warning Message', '', {})", output)

    output = response_flash("flash_container_id", :class => "alert-success", :message => "Success Message")
    assert_match("toastr.success('Success Message', '', #{ToastrType::OPTIONS[ToastrType::SUCCESS].to_json})", output)
  end

  def test_show_ajax_jquery_flash_message
    assert_equal "", show_ajax_jquery_flash_message
    flash[:notice] = "some_notice"
    assert_match "toastr.clear(); toastr.success('some_notice', '', #{ToastrType::OPTIONS[ToastrType::SUCCESS].to_json});", show_ajax_jquery_flash_message

    flash[:notice] = nil
    flash[:error] = "Some_Error"
    assert_equal "toastr.clear(); toastr.error('Some_Error');", show_ajax_jquery_flash_message
  end

  def test_append_time_zone
    mentor = members(:f_mentor)
    mentor.update_attributes(time_zone: "Asia/Kolkata")
    assert_equal Time.now.to_s + " " + "IST", append_time_zone(Time.now, mentor)
    mentor.update_attributes(time_zone: "Asia/Tokyo")
    assert_equal Time.now.to_s + " " + "JST", append_time_zone(Time.now, mentor)
  end

  def test_formatted_form_error_with_object
    program = programs(:albers)
    organization = programs(:org_primary)
    organization.name = ''
    organization.valid?

    form = mock
    form.expects(:object).times(3).returns(program)
    form.expects(:error_messages).with({})

    formatted_form_error(form, { objects: [organization] })

    assert_false program.errors[:base].empty?, 'expect to collect messages to form object'
  end

  def test_get_target_roles
    assert_equal get_target_roles(nil, nil, nil, users(:f_student)), [RoleConstants::STUDENT_NAME]
    assert_equal get_target_roles(nil, nil, nil, users(:f_mentor)), [RoleConstants::MENTOR_NAME]
    assert_equal get_target_roles(nil, fetch_role(:albers, :student).name, nil, nil), [RoleConstants::STUDENT_NAME]
  end

  def test_render_more_less
    text = 'long long text'
    set_response_text render_more_less(text, 12)
    assert_select 'span', :text => "long lon... show more »"

    set_response_text render_more_less(text, 20)
    assert_select 'span', :text => "long long text"

    text = '<br>long long text</br>'
    set_response_text render_more_less(text, 12)
    assert_select 'span', :text => "long lon... show more »"
    set_response_text render_more_less(text, 14)
    assert_select 'span', :text => "long long text"
  end

  def test_render_more_less_with_html_lingering_tag
    text = '<a href="http://en.wikipedia.org/wiki/Harry_Potter_and_the_Chamber_of_Secrets">Harry Potter and the Chamber of Secrets</a>'
    set_response_text render_more_less(text, 12)
    assert_select 'span', :text => "Harry Po... show more »"

    set_response_text render_more_less(text, 130)
    assert_select 'span', :text => "Harry Potter and the Chamber of Secrets"
  end

  def test_render_more_less_rows
    rows = ['publication', 'experience', 'education', 'second education', 'second experience', 'second publication']
    res = render_more_less_rows(rows)
    assert_match /publication<br\/>experience<br\/>education/, res
    assert_match /show 3 more/, res

    res = render_more_less_rows(rows, 2)
    assert_match /publication<br\/>experience/, res
    assert_match /show 3 more/, res

    res = render_more_less_rows(['publication', 'experience', 'education'])
    assert_match /publication<br\/>experience<br\/>education/, res
    assert_no_match(/show 0 more/, res)
  end

  def test_day_options_for_select
    assert_equal [["Day", ""]] + (1..31).to_a, day_options_for_select
  end

  def test_month_options_for_select
    assert_equal [["Month", ""],["Jan", 1],["Feb", 2],["Mar", 3],["Apr", 4],["May", 5],["Jun", 6],["Jul", 7],["Aug", 8],["Sep", 9],["Oct", 10],["Nov", 11],["Dec", 12]], month_options_for_select
  end

  def test_year_options_for_select
    assert_equal [["Year", ""]] + ProfileConstants.valid_years, year_options_for_select
  end

  def test_get_detailed_list_toggle_buttons
    toggle_bar = get_detailed_list_toggle_buttons("http://test_detailed.chronus.com", "http://test_list.chronus.com", false)

    set_response_text toggle_bar
    assert_select "div#toggle_bar.hidden-sm.hidden-xs" do
      assert_select "a.btn.active" do
        assert_select "a[data-click='http://test_detailed.chronus.com']"
      end
      assert_select "a.btn" do
        assert_select "a[data-click='http://test_list.chronus.com']"
      end
    end
  end

  def test_display_member_name
    assert_equal members(:f_student).name(:name_only => true), display_member_name(members(:f_student))
    assert_equal members(:f_mentor).name(:name_only => true), display_member_name(members(:f_mentor))
    assert_equal members(:f_admin).name(:name_only => true), display_member_name(members(:f_admin))
  end

  def test_preserve_new_line
    content = "Carrie Mathison \n Homeland"
    assert_equal "<p>Carrie Mathison \n<br /> Homeland</p>", preserve_new_line(content)
    content = "Carrie Mathison \n\n Homeland"
    assert_equal "<p>Carrie Mathison </p>\n\n<p> Homeland</p>", preserve_new_line(content)
    content = "Carrie Mathison \n\n Homeland \n http://www.google.com"
    assert_equal "<p>Carrie Mathison </p>\n\n<p> Homeland \n<br /> http://www.google.com</p>", preserve_new_line(content)
  end

  def test_wizard_wrapper
    @@skip_local_render = true
    headers = {
      "A" => { label: "Label A", url: "http://chronus.com", link_options: { class: "link_a_class" } },
      "B" => { label: "Label B" },
      "C" => { label: "Label C" }
    }
    content = wizard_wrapper(headers, "B", { disable_unselected: true }, true ) do
      content_tag(:span, "Tab Content")
    end
    set_response_text(content)
    assert_select "div.ibox.wizard_view"
    assert_select "div.ibox" do
      assert_select "span", text: "Tab Content"
    end

    content = wizard_wrapper(headers, "B", { disable_unselected: true }, false ) do
      content_tag(:span, "Tab Content")
    end
    set_response_text(content)
    assert_no_select "div.ibox.wizard_view"
    assert_select "div.ibox" do
      assert_select "span", text: "Tab Content"
    end
  end

  def test_wizard_headers
    @@skip_local_render = true
    headers = {
      "A" => { label: "Label A", url: "http://chronus.com", link_options: { class: "link_a_class" } },
      "B" => { label: "Label B" },
      "C" => { label: "Label C" }
    }
    content = wizard_headers(headers, "B", { disable_unselected: true } ) do
      content_tag(:span, "Tab Content")
    end
    set_response_text(content)
    assert_select "div.ibox.wizard_view" do
      assert_select "div.tabs-container" do
        assert_select "ul.nav.nav-tabs" do
          assert_select "li.disabled", count: 2
          assert_select "li.active", count: 1
          assert_select "li.disabled" do
            assert_select "a.link_a_class[href=?]", "http://chronus.com", text: "1.Label A"
            assert_select "a[href=?]", "javascript:void(0)", text: "3.Label C"
          end
          assert_select "li.active" do
            assert_select "a[href=?]", "javascript:void(0)", text: "2.Label B"
          end
        end
      end
    end
    assert_select "div.ibox" do
      assert_select "span", text: "Tab Content"
    end

    content = wizard_headers(headers, "C") do
      content_tag(:span, "New Tab Content")
    end
    set_response_text(content)
    assert_select "div.ibox.wizard_view" do
      assert_select "div.tabs-container" do
        assert_select "ul.nav.nav-tabs" do
          assert_no_select "li.disabled"
          assert_select "li.active", count: 1
          assert_select "li" do
            assert_select "a.link_a_class[href=?]", "http://chronus.com", text: "1.Label A"
            assert_select "a[href=?]", "javascript:void(0)", text: "2.Label B"
          end
          assert_select "li.active" do
            assert_select "a[href=?]", "javascript:void(0)", text: "3.Label C"
          end
        end
      end
    end
    assert_select "div.ibox" do
      assert_select "span", text: "New Tab Content"
    end
  end

  def test_simple_wizard
    content_1 = to_html(simple_wizard(['Hi']))
    assert_select content_1, "ul" do
      assert_select "li", :count => 1
      assert_select "li.bg-dark", :count => 1 do
        assert_select "span", :text => "Hi"
      end
    end

    content_2 = to_html(simple_wizard(['Hi', 'Bye'], 2))
    assert_select content_2, "ul" do
      assert_select "li", :count => 2
      assert_select "li.bg-dark", :count => 1 do
        assert_select "span", :text => "Bye"
      end
    end

    content_3 = to_html(simple_wizard(['Hi', 'Bye', 'Hello'], 2))
    assert_select content_3, "ul" do
      assert_select "li", :count => 3
      assert_select "li.bg-dark", :count => 1 do
        assert_select "span", :text => "Bye"
      end
    end
  end

  def test_get_program_listing_options
    @current_organization = programs(:org_primary)
    programs = Program.first(2)

    @current_organization.stubs("active?").returns(:false)
    self.stubs(:logged_in_organization?).returns(false)
    assert_equal_hash({}, get_program_listing_options)

    self.stubs(:logged_in_organization?).returns(true)
    self.stubs(:wob_member).returns(members(:f_mentor))
    self.stubs(:get_active_member_programs).returns(programs)
    expected_hash = {
      multiple_programs: programs,
      member_has_many_active_programs: true,
      list_style: "list-group-item no-borders",
      list_class: "text-default"
    }
    assert_equal_hash(expected_hash, get_program_listing_options)

    programs = [programs(:albers)]
    self.stubs(:get_active_member_programs).returns(programs)
    expected_hash = {
      multiple_programs: programs,
      member_has_many_active_programs: false,
      list_style: "list-group-item no-borders",
      list_class: "text-default"
    }
    assert_equal_hash(expected_hash, get_program_listing_options)
  end

  def test_alert_badge
    content_1 = to_html(alert_badge(nil))
    assert_select content_1, "span.badge.badge-not-started", :text => "0"

    content_2 = to_html(alert_badge(0))
    assert_select content_2, "span.badge.badge-not-started", :text => "0"

    content_3 = to_html(alert_badge(1))
    assert_select content_3, "span.badge.badge-danger", :text => "1"
  end

  def test_owner_content_for_user_name
    proposer = users(:f_mentor_pbe)
    program = programs(:pbe)
    group = create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    group.reload
    assert_equal [], group.owners
    group.make_proposer_owner!

    assert_equal " (Owner)", owner_content_for_user_name(group, proposer)
    assert_equal "", owner_content_for_user_name(group, users(:f_mentor))
    assert_equal "", owner_content_for_user_name(groups(:mygroup), users(:f_mentor))
    #non admins should not see (owner) text
    @current_user = users(:f_mentor)
    assert_equal "", owner_content_for_user_name(group, proposer)

    #non admin but owner should see (owner) text
    @current_user = users(:f_mentor_pbe)
    assert_equal " (Owner)", owner_content_for_user_name(group, proposer)
  end

  def test_render_action_for_dropdown_button_for_id_presence_in_disabled_links
    # disabled links in dropdown will have id attribute if passed in the options
    action = {:disabled => true, :id => "test_id", :label => "test_label", :icon => "test_icon"}
    assert_match("id=\"test_id\"", render_action_for_dropdown_button(action))
  end

  def test_flash_msg_for_not_allowing_mentoring_requests
    program = programs(:albers)
    assert_blank program.allow_mentoring_requests_message
    assert_equal "The track super admin does not allow you to send any requests.", flash_msg_for_not_allowing_mentoring_requests(program)
    program.update_attribute(:allow_mentoring_requests_message, "Custom message for not allowing mentoring requests")
    assert_equal "Custom message for not allowing mentoring requests", flash_msg_for_not_allowing_mentoring_requests(program)
  end

  def test_get_demo_program_url
    assert_equal "#{DEMO_URL_SUBDOMAIN}.#{DEFAULT_DOMAIN_NAME}", get_demo_program_url
  end

  def test_get_role_description_and_edit_options
    current_user_is :f_admin
    current_organization_is :org_primary
    program = programs(:albers)
    role = program.get_roles(RoleConstants::MENTOR_NAME)[0]
    role.description = "Mentor Role Description"
    role.save!
    content = get_role_description_and_edit_options(@current_organization, role, RoleConstants.program_roles_mapping(program, roles: [role]))
    assert_match "Mentor Role Description", content[0]
    assert_match "<a class=\"strong ie-nowrap\" id=\"role_description_edit_mentor\" onclick=\"ProgramSettings.roleDescriptionEdit(&#39;mentor&#39;)\" href=\"javascript:void(0)\"", content[1]
    assert_match "Edit Description</a>", content[1]
  end

  def test_get_role_description_and_edit_options_empty
    current_user_is :f_admin
    current_organization_is :org_primary
    program = programs(:albers)
    role = program.get_roles(RoleConstants::InviteRolePermission::RoleName::USER_NAME)[0]
    content = get_role_description_and_edit_options(@current_organization, role, RoleConstants.program_roles_mapping(program, roles: [role]))
    assert_nil content[0]
  end

  def test_path_eligibility_rules
    current_user_is :f_admin
    program = programs(:albers)
    role = program.roles.find_by(name: "mentor")
    assert_equal "/admin_views/new.js?is_org_view=true&role=#{role.id}", path_eligibility_rules(role)
    admin_view = AdminView.create!(:program => programs(:org_primary), role: role, :title => "New View", :filter_params => AdminView.convert_to_yaml({
      :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
    }))
    role.reload
    assert_equal "/admin_views/#{admin_view.id}/edit.js?editable=true&is_org_view=true&role=#{role.id}", path_eligibility_rules(role)
  end


  def test_get_programs_and_portals_select_box
    organization = programs(:org_nch)
    current_organization_is organization
    #Fetch programs when career dev feature is enable
    ProgramsListingService.fetch_programs(self, organization) do |all_programs|
      all_programs.ordered.includes(:translations)
    end

    select_box = get_programs_and_portals_select_box(self)

    assert_match "Career Development Program", select_box
    assert_match "NCH Mentoring Program", select_box
    assert_match "Primary Career Portal", select_box
    assert_no_match Regexp.new("All Programs"), select_box

    #Fetch programs with all programs flag is true
    ProgramsListingService.fetch_programs(self, organization) do |all_programs|
      all_programs.ordered.includes(:translations)
    end

    select_box = get_programs_and_portals_select_box(self, include_all_programs: true)
    assert_match "All Programs", select_box
    assert_match "Career Development Program", select_box
    assert_match "NCH Mentoring Program", select_box
    assert_match "Primary Career Portal", select_box

    #Fetch programs when feature is disable
    disable_career_development_feature(organization)

    ProgramsListingService.fetch_programs(self, organization) do |all_programs|
      all_programs.ordered.includes(:translations)
    end

    select_box = get_programs_and_portals_select_box(self)

    assert_match "NCH Mentoring Program", select_box
    assert_no_match Regexp.new("Career Development Program"), select_box
    assert_no_match Regexp.new("All Programs"), select_box
    assert_no_match Regexp.new("Primary Career Portal"), select_box

    ProgramsListingService.fetch_programs(self, organization) do |all_programs|
      all_programs.ordered.includes(:translations)
    end

    select_box = get_programs_and_portals_select_box(self, include_all_programs: true)
    assert_match "NCH Mentoring Program", select_box
    assert_match "All Programs", select_box
    assert_no_match Regexp.new("Primary Career Portal"), select_box
    assert_no_match Regexp.new("Career Development Program"), select_box
  end

  def test_get_member_active_programs
    #For mentoring organization
    member = members(:f_admin)
    organization =  programs(:org_primary)
    all_programs = ProgramsListingService.get_applicable_programs(organization)

    assert_equal member.active_programs.size, 4
    all_member_programs = [programs(:albers), programs(:nwen), programs(:moderated_program), programs(:pbe)]
    assert_equal all_member_programs.collect(&:id), get_active_member_programs(member, organization).collect(&:id)


    #Active programs
    program = programs(:albers)

    organization.reload
    user = member.user_in_program(program)
    user.destroy
    member.reload

    all_programs = ProgramsListingService.get_applicable_programs(organization)
    assert_equal member.active_programs.size, 3
    all_member_programs = [programs(:nwen), programs(:moderated_program), programs(:pbe)]
    assert_equal all_member_programs.collect(&:id), get_active_member_programs(member, organization).collect(&:id)

    #the order of the programs
    program = programs(:nwen)
    program.position = 5000;
    program.save!
    program.reload

    program = programs(:moderated_program)
    program.position = 1000;
    program.save!
    program.reload

    organization.reload
    all_programs = ProgramsListingService.get_applicable_programs(organization)
    assert_equal member.active_programs.size, 3
    all_member_programs = [programs(:pbe), programs(:moderated_program), programs(:nwen)]
    assert_equal all_member_programs.collect(&:id), get_active_member_programs(member, organization).collect(&:id)
  end

  def test_get_member_active_programs_for_career_development_programs
    member = members(:nch_admin)
    organization = programs(:org_nch)
    all_programs = ProgramsListingService.get_applicable_programs(organization)

    assert_equal member.active_programs.size, 2
    all_member_programs = [programs(:primary_portal), programs(:nch_mentoring)]
    assert_equal all_member_programs.collect(&:id), get_active_member_programs(member, organization).collect(&:id)

    #the order of the programs
    program = programs(:primary_portal)
    program.position = 5000;
    program.save!
    program.reload

    program = programs(:nch_mentoring)
    program.position = 1000;
    program.save!
    program.reload

    organization.reload
    all_programs = ProgramsListingService.get_applicable_programs(organization)
    assert_equal member.active_programs.size, 2
    all_member_programs = [programs(:primary_portal), programs(:nch_mentoring)]
    assert_equal all_member_programs.collect(&:id), get_active_member_programs(member, organization).collect(&:id)

    #Feature disable
    organization.enable_disable_feature(FeatureName::CAREER_DEVELOPMENT, false)
    organization.reload

    all_programs = ProgramsListingService.get_applicable_programs(organization)
    assert_equal member.active_programs.size, 2
    all_member_programs = [programs(:nch_mentoring)]
    assert_equal all_member_programs.collect(&:id), get_active_member_programs(member, organization).collect(&:id)

    #Active programs
    organization.enable_disable_feature(FeatureName::CAREER_DEVELOPMENT, true)
    program = programs(:nch_mentoring)

    organization.reload
    user = member.user_in_program(program)
    user.destroy
    member.reload

    all_programs = ProgramsListingService.get_applicable_programs(organization)
    assert_equal member.active_programs.size, 1
    all_member_programs = [programs(:primary_portal)]
    assert_equal all_member_programs.collect(&:id), get_active_member_programs(member, organization).collect(&:id)

  end

  def _Program
    "Program"
  end

  def _Programs
    "Programs"
  end

  def test_get_urls_for_attachments
    org = programs(:org_primary)
    second_locale = :"fr-CA"
    ProgramAsset.find_or_create_by(program_id: org.id)
    asset = org.program_asset
    asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    asset.save!
    paths = get_urls_for_attachments(asset, "banner", second_locale)
    assert_match /test_pic.png/, paths[0]
    assert_nil paths[1]
    GlobalizationUtils.run_in_locale(second_locale) do
      asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
      asset.save!
    end
    paths = get_urls_for_attachments(asset, "banner", second_locale)
    assert_match /test_pic.png/, paths[0]
    assert_match /test_pic.png/, paths[1]
  end

  def test_hidden_on_mobile
    assert_equal "hidden-xs hidden-sm", hidden_on_mobile
  end

  def test_hidden_on_mobile
    assert_equal "hidden-xs hidden-sm", hidden_on_mobile
  end

  def test_hidden_above_tab
    assert_equal "hidden-lg", hidden_above_tab
  end

  def test_hidden_on_and_below_tab
    assert_equal "hidden-sm hidden-xs hidden-md", hidden_on_and_below_tab
  end

  def test_android_app_store_link
    assert_equal "https://play.google.com/store/apps/details?id=com.chronus.mentorp&referrer=utm_source%3D#{programs(:org_primary).url}%26utm_medium%3Doverview_page", android_app_store_link(programs(:org_primary), CordovaHelper::AndroidAppStoreSource::OVERVIEW_PAGE)

    assert_equal "https://play.google.com/store/apps/details?id=com.chronus.mentorp", android_app_store_link(nil, nil)
  end

  def test_hidden_on_web
    assert_equal "hidden-lg hidden-md", hidden_on_web
  end

  def test_vertical_separator
    assert_equal "<span class=\"text-muted p-l-xxs p-r-xxs\">|<\/span>", vertical_separator
  end

  def test_circle_separator
    assert_match /<small><small><i class=\"fa fa-circle text-muted p-l-xxs p-r-xxs.*\"><\/i><\/small><\/small>/, circle_separator
  end

  def test_display_stats
    set_response_text(display_stats(1, "Users", { element_id: "element_1", icon_class: "fa fa-users" } ))
    assert_select "h1", class: "no-margins", id: "element_1" do
      1
    end
    assert_select "div", class: "small" do
      assert_select "i", class: "fa fa-users"
      "Users"
    end

    set_response_text(display_stats(1, "Users", { element_id: "element_1", icon_class: "fa fa-users", only_value_container: true } ))
    assert_select "h1", class: "no-margins", id: "element_1" do
      1
    end
    assert_no_select "div"

    set_response_text(display_stats(1, "Users", { element_id: "element_1", icon_class: "fa fa-users", only_value_container: false, in_listing: true } ))
    assert_select "span", class: "views-number font-bold", id: "element_1" do
      1
    end
    assert_select "div", class: "small" do
      assert_select "i", class: "fa fa-users"
      "Users"
    end
  end

  def test_render_tips_in_sidepane
    assert_equal render(partial: "common/sidepane_assets_pane"), render_tips_in_sidepane(["tip1", "tip2"])
  end

  def test_toggle_button
    options = { class: "cjs_element", id: "element_1", method: "post", data: { data_attr: 1 }, get_page_action_hash: true, handle_html_data_attr: true, toggle_class: { active: "act", inactive: "inact" } }
    action_hash = toggle_button(qa_questions_path, { inactive: "Like", active: "Unlike" }, false, options)
    assert action_hash[:label] == "Like"
    assert_nil action_hash[:class]
    assert action_hash[:btn_class_name] == "cjs_element inact"
    assert action_hash[:id] == "element_1"
    assert action_hash[:method] == "post"
    assert action_hash[:data][:url] == qa_questions_path
    assert action_hash[:data][:replace_content] == "Unlike"
    assert action_hash[:data][:data_attr] == 1
    assert action_hash[:data][:toggle_class] == "act inact"

    content = toggle_button(qa_questions_path, { inactive: "Like", active: "Unlike" }, true, options.merge!(get_page_action_hash: false))
    assert_select_helper_function "a[class=\"cjs_element act\"][data-click=\"javascript:void(0)\"][data-data-attr=\"1\"][data-method=\"post\"][data-replace-content=\"Like\"][data-toggle-class=\"act inact\"][data-url=\"/qa_questions\"][href=\"javascript:void(0)\"][id=\"element_1\"][rel=\"nofollow\"]", content, {text: "Unlike"}
  end

  def test_append_text_to_icon
    assert_equal "<i class=\"fa fa-users fa-fw m-r-xs\"></i>Users", append_text_to_icon("fa fa-users", "Users")
    assert_equal "<i class=\"fa fa-users fa-fw m-r-xs\"></i>", append_text_to_icon("fa fa-users")
    assert_equal "<a href=\"/mobile_v2/home/verify_organization\"><i class=\"fa fa-angle-left fa-fw m-r-xs\" icon_path=\"/mobile_v2/home/verify_organization\"></i></a>", append_text_to_icon("fa fa-angle-left", "", {:icon_path => mobile_v2_verify_organization_path})
    set_response_text(append_text_to_icon("fa fa-angle-left", "", {:icon_path => mobile_v2_verify_organization_path}))
    assert_select('a[href=?]', "/mobile_v2/home/verify_organization")
  end

  def _Career_Development
    "Career Development"
  end

  def test_ibox
    @@skip_local_render = true
    output = ibox do
      content_tag(:span, "Ibox Content Text")
    end
    assert_match /div class="ibox/, output
    assert_match /div.*class="ibox-content.*Ibox Content Text/m, output
    assert_no_match /div.*class="ibox-title/, output
    assert_no_match /div class="ibox-footer/, output

    output = ibox("header title",
                  :ibox_class => "class1",
                  :ibox_id => "iboxid",
                  :ibox_header_id => "headerid",
                  :title_class => "titleclass",
                  :icon_class => "fa fa-info",
                  :icon_container_class => "fa-circle",
                  :right_links_class => "rightlink",
                  :show_collapse_link => true,
                  :show_close_link => true,
                  :additional_right_links => content_tag(:span, "link"),
                  :ibox_content_id => "contentid",
                  :content_class => "content_class",
                  :footer => "footer content"
                  )  do
      content_tag(:span, "Ibox changed content")
    end
    assert_match /div class="ibox class1.*id=iboxid/, output
    assert_match /div.*id=contentid.*class="ibox-content clearfix content_class.*Ibox changed content/m, output
    assert_match /div.*id=headerid.*class="ibox-title table-bordered clearfix titleclass.*h5.*fa-circle.*fa-info.*header title/m, output
    assert_match /div.*class="ibox-tools.*rightlink.*a.*class="collapse-link.*class="close-link.*span.*link/m, output
    assert_match /div class="ibox-footer.*footer content/m, output
  end

  def test_panel
    @@skip_local_render = true
    content = panel "Panel Title" do
      content_tag(:span, "Panel Body Text")
    end
    set_response_text(content)
    assert_select "div.panel" do
      assert_select "div.panel-heading" do
        assert_select "div.h5.panel-title", text: "Panel Title"
      end
      assert_select "div.panel-body" do
        assert_select "span", text: "Panel Body Text"
      end
    end
    assert_no_select("a")
    assert_no_select("panel-footer")

    content = panel "Panel Title V2",
                panel_class: "panel-default", panel_id: "panel-id",
                collapsible: true,
                panel_heading_class: "panel-header", panel_heading_id: "panel-header-id",
                icon_class: "fa-icon",
                panel_body_wrapper_class: "collapse", panel_body_wrapper_id: "panel-body-wrapper-id",
                panel_body_class: "panel-body-class", panel_body_id: "panel-body-id",
                panel_footer_class: "panel-footer-class", panel_footer_id: "panel-footer-id",
                footer: content_tag(:div, "Footer") do
                  content_tag(:span, "New Panel Content")
              end
    set_response_text(content)
    assert_select "div.panel.panel-default#panel-id" do
      assert_select "a[data-target='#panel-body-wrapper-id']" do
        assert_select "div.panel-heading.panel-header#panel-header-id" do
          assert_select "i.fa-chevron-down"
          assert_select "div.h5.panel-title", text: "Panel Title V2" do
            assert_select "i.fa-icon"
          end
        end
      end
      assert_select "div.collapse#panel-body-wrapper-id" do
        assert_select "div.panel-body.panel-body-class#panel-body-id" do
          assert_select "span", text: "New Panel Content"
        end
      end
      assert_select "div.panel-footer.panel-footer-class#panel-footer-id" do
        assert_select "div", text: "Footer"
      end
    end
  end

  def test_modal_popup_v3
    @@skip_local_render = true
    output = modal_v3_popup "Popup Title" do
      content_tag(:span, "content")
    end

    assert_match /div class="modal-header/, output
    assert_match /<h4 class="modal-title">/, output
    assert_match /Popup Title/, output
    assert_match /<div class=\"modal-body clearfix \">/, output
    assert_match /content/, output
    output = modal_v3_popup "Popup Title", :additional_class =>"additionalclass" do
      content_tag(:span, "content")
    end
    assert_match /div class="modal-header/, output
  end

  def test_modal_container
    @@skip_local_render = true
    assert_nil modal_container("Title") do
      content_tag(:span, "content")
    end

    output = modal_container(nil, modal_id: "modal_id", :no_modal_header => true) do
      content_tag(:span, "content")
    end
    assert_match /<div class=\\\"modal fade/, output
    assert_match /<div class=\\\"modal-dialog/, output
    assert_match /<div class=\\\"modal-content/, output
    assert_match /<div class=\\\"modal-body.*span.*content/m, output
    assert_match /jQuery\(".modal#modal_id"\).remove\(\)/, output
    assert_match /jQuery\("body"\).append/, output
    assert_no_match(/<div class=\\\"modal-footer/, output)
    assert_no_match(/div class=\\\"modal-header/, output)

    output = modal_container "Modal title",
      :modal_class => "modalclass",
      :modal_id => "modalid",
      :modal_dialog_class => "dialogclass",
      :modal_content_class => "contentclass",
      :modal_title_id => "titleid",
      :icon_class => "fa fa-info",
      :icon_container_class => "fa fa-circle",
      :modal_body_class => "bodyclass",
      :modal_footer_content => "footercontent" do
      content_tag(:span, "content")
    end
    assert_match /<div class=\\\"modal fade modalclass.* id=\\\"modalid/, output
    assert_match /<div class=\\\"modal-dialog dialogclass/, output
    assert_match /<div class=\\\"modal-content contentclass/, output
    assert_match /<div class=\\\"modal-body clearfix bodyclass.*span.*content/m, output
    assert_match /<div class=\\\"modal-footer.*footercontent/m, output
    assert_match /modal-header/, output
    assert_match /Modal title/, output
    assert_match /jQuery\(".modal#modalid"\).remove\(\)/, output
    assert_match /jQuery\("body"\).append/, output
  end

  def test_get_icon_content
    assert_equal "<i class=\"fa fa-info fa-fw m-r-xs\"></i>", get_icon_content("fa fa-info")
    assert_equal "<span class=\"fa-stack fa-lg fa-fw m-r-xs \"><i class=\"fa fa-circle fa-stack-2x\"></i><i class=\"fa fa-info fa-stack-1x fa-inverse\"></i></span>", get_icon_content("fa fa-info", :container_class => "fa-circle")
    assert_equal "<span class=\"fa-stack fa-lg fa-fw m-r-xs stackclass\"><i class=\"fa fa-circle fa-stack-2x\"></i><i class=\"fa fa-info fa-stack-1x fa-inverse\"></i></span>", get_icon_content("fa fa-info", :container_class => "fa-circle", :stack_class => "stackclass")
    assert_equal "<span class=\"fa-stack fa-lg fa-fw m-r-xs \" rel=\"tooltip\" title=\"tooltip\"><i class=\"fa fa-calendar fa-small fa-stack-1x\"></i><i class=\"fa fa-ban fa-stack-2x \"></i></span>", get_icon_content("fa fa-ban", container_class: "fa-calendar", container_stack_class: "fa-small fa-stack-1x", icon_stack_class: "fa-stack-2x", invert: "", rel: 'tooltip', title: "tooltip")
  end

  def test_input_group
    output = input_group(:class => "additional class") do
      content_tag(:span, "content text")
    end

    assert_equal "<div class=\"additional class input-group m-b-sm\"><span>content text</span></div>", output
  end

  def test_top_bar_in_listing
    @@skip_local_render = true

    collection = (1..10).to_a.paginate(per_page: 5)
    extreme_contents = { left_most_content: content_tag(:h6, "Left Content"), right_most_content: content_tag(:h5, "Right Content") }
    sort_info = [
      { field: "name", order: "asc", label: "Name A-Z" },
      { field: "name", order: "desc", label: "Name Z-A" }
    ]

    assert_equal "", top_bar_in_listing

    set_response_text top_bar_in_listing({}, { show: true })
    assert_select "div.listing_top_bar.hidden-lg.hidden-md"

    set_response_text top_bar_in_listing({}, { show: true }, {}, extreme_contents)
    assert_no_select "div.listing_top_bar.hidden-lg.hidden-md"
    assert_select "div.listing_top_bar" do
      assert_select "h6", text: "Left Content"
      assert_select "h5", text: "Right Content"
    end

    content = top_bar_in_listing( { collection: collection }, { show: true }, { sort_url: users_path, sort_field: "name", sort_order: "asc", sort_info: sort_info }, extreme_contents)
    assert_select_helper_function_block "div.listing_top_bar", content do
      assert_select "h6", text: "Left Content"
      # per_page_info - left aligned
      assert_select "div.cur_page_info.pull-left" do
        assert_select "span.hidden-xs.hidden-sm", text: "Showing"
        assert_select "b", text: "1 - 5"
        assert_select "b", text: "10"
      end
      #filter_icon - right aligned
      assert_select "div.hidden-lg.hidden-md.pull-right" do
        assert_select "a.btn[data-toggle=offcanvasright]", text: "Filters" do
          assert_select "i.fa-filter"
        end
      end
      assert_select "h5", text: "Right Content"
      #sort_options - right aligned
      assert_select "div.hidden-xs.hidden-sm.pull-right" do
        assert_select "select[onchange=\"submitSortForm(this.value, false)\"]" do
          assert_select "option[value='name,asc'][selected=selected]", text: "Name A-Z"
          assert_select "option[value='name,desc']", text: "Name Z-A"
        end
      end
      assert_select "div.hidden-lg.hidden-md.pull-right" do
        assert_select "a.btn[data-target='#sort_by_modal']", text: "SORT" do
          assert_select "i.fa-sort-amount-asc"
        end
      end
      assert_select "form[action='/users'].hide" do
        assert_select "input#sort_field[type=hidden]"
        assert_select "input#sort_order[type=hidden]"
      end

      assert_match /<div class=\\\"modal fade cui-non-full-page-modal\\\" id=\\\"sort_by_modal\\\"/, content
      assert_match /<a onclick=\\\"jQuery\(&#39;#sort_by_modal&#39;\).modal\(&#39;hide&#39;\); submitSortForm\(&#39;name,asc&#39;, false\)\\\" class=\\\"list-group-item gray-bg font-bold\\\" href=\\\"javascript:void\(0\)\\\">Name A-Z/, content
      assert_match /<a onclick=\\\"jQuery\(&#39;#sort_by_modal&#39;\).modal\(&#39;hide&#39;\); submitSortForm\(&#39;name,desc&#39;, false\)\\\" class=\\\"list-group-item \\\" href=\\\"javascript:void\(0\)\\\">Name Z-A/, content
    end
  end

  def test_bottom_bar_in_listing
    assert_equal "", bottom_bar_in_listing

    collection = (1..60).to_a.paginate(per_page: 10)
    content = bottom_bar_in_listing( { collection: collection, params: { controller: "users" } }, { page_url: users_path, current_number: 10, use_ajax: true } )
    set_response_text(content)
    # pagination in web - left aligned
    assert_select "div.clearfix" do
      assert_select "div.hidden-xs.hidden-sm.pull-left" do
        assert_select "ul.pagination" do
          assert_select "li.disabled" do
            assert_select "span.previous_page" do
              assert_select "i.fa-angle-left"
            end
          end
          assert_select "li.active" do
            assert_select "span.current", text: "1"
          end
          # Five pages in web
          assert_select "li" do
            assert_select "a", text: "2"
            assert_select "a", text: "3"
            assert_select "a", text: "4"
            assert_select "a", text: "5"
            assert_select "a", text: "6", count: 0
            assert_select "a.next_page"
          end
        end
      end

      # pagination in mobile - left aligned
      assert_select "div.hidden-lg.hidden-md.pull-left" do
        assert_select "ul.pagination" do
          assert_select "li.disabled" do
            assert_select "span.previous_page" do
              assert_select "i.fa-angle-left"
            end
          end
          assert_select "li.active" do
            assert_select "span.current", text: "1"
          end
          # Three pages in mobile
          assert_select "li" do
            assert_select "a", text: "2"
            assert_select "a", text: "3"
            assert_select "a", text: "4", count: 0
            assert_select "a.next_page"
          end
        end
      end

      # per_page_option - right aligned
      assert_select "div.pull-right" do
        assert_select "div.items_per_page" do
          assert_select "select[onchange='submitPerPageSelectorFormAjax(this.value)']" do
            assert_select "option[selected=selected]", text: "10"
            assert_select "option[value='20']", text: "20"
            assert_select "option[value='30']", text: "30"
            assert_select "option[value='40']", text: "40"
          end
        end
      end
      assert_select "div.pull-right", text: "Show"
    end
  end

  def test_sort_options_v3_ajax
    sort_info = [
      { field: "name", order: "asc", label: "Name A-Z" },
      { field: "name", order: "desc", label: "Name Z-A" }
    ]
    web_content, mobile_content, form = sort_options_v3(users_path, "name", "asc", sort_info, use_ajax: true)

    assert_match /select.* onchange=\"submitSortFormAjax\(this.value, false\)/, web_content
    assert_match /option selected=\"selected\" value=\"name,asc\">Name A-Z/, web_content
    assert_match /option value=\"name,desc\">Name Z-A/, web_content

    assert_match /div class=\"list-group/, mobile_content
    # selected
    assert_match /<a onclick=\"jQuery\(&#39;#sort_by_modal&#39;\).modal\(&#39;hide&#39;\); submitSortFormAjax\(&#39;name,asc&#39;, false\)\" class=\"list-group-item gray-bg font-bold\" href=\"javascript:void\(0\)\">Name A-Z/, mobile_content
    assert_match /i class=\"fa fa-check-circle/, mobile_content
    assert_match /<a onclick=\"jQuery\(&#39;#sort_by_modal&#39;\).modal\(&#39;hide&#39;\); submitSortFormAjax\(&#39;name,desc&#39;, false\)\" class=\"list-group-item \" href=\"javascript:void\(0\)\">Name Z-A/, mobile_content

    assert_match /form action=\"\/users\" method=\"get\" id=\"sort_form\" class=\"hide\">/, form
    assert_match /input type=\"hidden\" name=\"sort\" id=\"sort_field\"/, form
    assert_match /input type=\"hidden\" name=\"order\" id=\"sort_order\"/, form
  end

  def test_sort_options_v3_non_ajax
    sort_info = [
      { field: "name", order: "asc", label: "Name A-Z" },
      { field: "name", order: "desc", label: "Name Z-A" }
    ]
    web_content, mobile_content, form = sort_options_v3(users_path, "name", "asc", sort_info, is_groups_page: true)

    assert_match /select.* onchange=\"submitSortForm\(this.value, true\)/, web_content
    assert_match /option selected=\"selected\" value=\"name,asc\">Name A-Z/, web_content
    assert_match /option value=\"name,desc\">Name Z-A/, web_content

    assert_match /div class=\"list-group/, mobile_content
    # selected
    assert_match /<a onclick=\"jQuery\(&#39;#sort_by_modal&#39;\).modal\(&#39;hide&#39;\); submitSortForm\(&#39;name,asc&#39;, true\)\" class=\"list-group-item gray-bg font-bold\" href=\"javascript:void\(0\)\">Name A-Z/, mobile_content
    assert_match /i class=\"fa fa-check-circle/, mobile_content
    assert_match /<a onclick=\"jQuery\(&#39;#sort_by_modal&#39;\).modal\(&#39;hide&#39;\); submitSortForm\(&#39;name,desc&#39;, true\)\" class=\"list-group-item \" href=\"javascript:void\(0\)\">Name Z-A/, mobile_content

    assert_match /form action=\"\/users\" method=\"get\" id=\"sort_form\" class=\"hide\">/, form
    assert_match /input type=\"hidden\" name=\"sort\" id=\"sort_field\"/, form
    assert_match /input type=\"hidden\" name=\"order\" id=\"sort_order\"/, form
  end

  def test_sort_options_v3_on_select_function
    sort_info = [
      { field: "name", order: "asc", label: "Name A-Z" },
      { field: "name", order: "desc", label: "Name Z-A" }
    ]
    web_content, mobile_content, form = sort_options_v3(users_path, "name", "asc", sort_info, is_groups_page: true, on_select_function: "someFunction")
    assert_match /select.* onchange=\"someFunction\(this.value, true\)/, web_content
    assert_match "someFunction(&#39;name,asc&#39;, true)", mobile_content
    assert_match "someFunction(&#39;name,desc&#39;, true)", mobile_content
  end

  def test_collapsible_content_panel
    @@skip_local_render = true
    SecureRandom.stubs(:hex).returns("random")
    content = collapsible_content("Title", [], false,
      render_panel: true,
      additional_header_class: "p-sm",
      class: "filter_item",
      icon_class: "fa-icon",
      pane_content_class: "p-t-0") do
        content_tag(:span, "Collapsible Content")
      end
    set_response_text(content)
    assert_select "div.panel.filter_item" do
      assert_select "a[data-target='#collapsible_random_content']" do
        assert_select "div.panel-heading.p-sm#collapsible_random_header" do
          assert_select "i.fa-chevron-up"
          assert_select "div.h5.panel-title", text: "Title" do
            assert_select "i.fa-icon"
          end
        end
      end
      assert_select "div.collapse.in#collapsible_random_content" do
        assert_select "div.panel-body.p-t-0" do
          assert_select "span", text: "Collapsible Content"
        end
      end
    end
  end

  def test_collapsible_content_ibox
    @@skip_local_render = true
    SecureRandom.stubs(:hex).returns("random")
    content = collapsible_content("Title", [], false,
      additional_header_class: "p-sm",
      class: "filter_item",
      icon_class: "fa-icon",
      pane_content_class: "p-t-0", header_content: "Title", hide_header_title: true) do
        content_tag(:span, "Collapsible Content")
      end
    set_response_text(content)


    assert_select "div.ibox.filter_item" do
      assert_select "div.ibox-title#collapsible_random_header" do
        assert_select "a.collapse-link" do
            assert_select "i.fa-chevron-up"
        end
        assert_select "div.ibox-title-content", text: "Title"
      end
      assert_select "div.ibox-content#collapsible_random_content" do
        assert_select "span", text: "Collapsible Content"
      end
    end
  end

  def test_filter_links
    filters_info = [
      { label: "A", value: "value_a", count: 2, url: "http://chronus.com" },
      { label: "B", value: "value_b", url: "http://google.com" },
      { label: "C", value: "value_c", url: "javascript:void(0)" }
    ]

    content = filter_links("Show", "value_b", filters_info, false, { class: "my_class", id: "my_id" } )
    set_response_text(content)
    assert_select "div.my_class.filter_links#my_id" do
      assert_select "div.font-bold", text: "Show:"
      assert_select "a[href=?]", "http://chronus.com", text: "A (2)"
      assert_select "a[href=?]", "javascript:void(0)", count: 2
      assert_select "a.active", count: 1
      assert_select "a.active", text: "B"
      assert_select "a", text: "C"
    end
  end

  def test_filter_container_wrapper
    @@skip_local_render = true
    filter_content = content_tag(:span, "Filter Content")
    output = filter_container_wrapper do
      content_tag(:span, "Filter Content")
    end
    assert_equal filter_content, output
    assert_nil @filters_in_sidebar
    assert_nil @sidebar_footer_content

    mobile_footer_actions = { see_n_results: { results_count: 2, class: "see-results" }, reset_filters: { js: "javascript:void(0)" } }
    output = filter_container_wrapper(mobile_footer_actions) do
      content_tag(:span, "Filter Content")
    end
    set_response_text(output)
    assert_select "div.filter_pane.m-b-xl#filter_pane" do
      assert_select "div.ibox" do
        assert_select "div.ibox-content" do
          assert_select "div.panel-group.no-margins" do
            assert_select "span", text: "Filter Content"
          end
        end
      end
    end

    assert @filters_in_sidebar
    set_response_text(@sidebar_footer_content)
    assert_select "div.col-xs-6.text-left" do
      assert_select "a[href].see-results#cjs_see_n_results", text: "See 2 Results" do
        assert_select "i.fa-chevron-left"
      end
    end
    assert_select "div.col-xs-6.text-right" do
      assert_select "a[href]#cjs_reset_all_filters", text: "Reset all" do
        assert_select "i.fa-refresh"
      end
    end
  end

  def test_construct_input_group
    content = construct_input_group do
      text_field_tag "name"
    end
    assert_equal "<div class=\"input-group \"><input type=\"text\" name=\"name\" id=\"name\" /></div>", content

    left = { type: "addon", class: "left", icon_class: "fa-icon" }
    right = { type: "btn", class: "right", content: "Go", btn_options: { class: "btn-sm", onclick: "javascript:void(0)" } }
    content = construct_input_group(left, right, { input_group_class: "group-input" }) do
      text_field_tag "name"
    end
    set_response_text(content)
    assert_select "div.input-group.group-input" do
      assert_select "span.input-group-addon.left" do
        assert_select "i.fa-icon"
      end
      assert_select "input#name"
      assert_select "span.input-group-btn.right" do
        assert_select "button.btn-sm[onclick]", text: "Go"
      end
    end
  end

  def test_labels_container
    labels_array = [
      { label_class: "label-success", content: "Success", options: { id: "label1_id" } },
      [ { label_class: "label-danger", content: "Alert" }, nil ]
    ]
    content = labels_container(labels_array, { tag: :span, class: "wrapper-class" })
    set_response_text(content)
    assert_select "span.wrapper-class" do
      assert_select "span.label.inline.label-success#label1_id", text: "Success"
      assert_select "span.label.inline.label-danger", text: "Alert"
    end
  end

  def test_link_to_wrapper
    content = content_tag(:span, "Content")
    output = link_to_wrapper(false) do
      content
    end
    assert_equal content, output

    output = link_to_wrapper(true, url: users_path, class: "link") do
      content
    end
    set_response_text(output)
    assert_select "a.link[href='/users']" do
      assert_select "span", "Content"
    end

    output = link_to_wrapper(true, js: "javascript:void(0)", class: "link") do
      content
    end
    set_response_text(output)
    assert_select "a.link[onclick]" do
      assert_select "span", "Content"
    end
  end

  def test_render_label_inline
    content = render_label_inline( { label_class: "label-success", content: "Content", options: { id: "label_id" } } )
    set_response_text(content)
    assert_select "span.label.inline.label-success#label_id", text: "Content"
  end

  def test_set_screen_reader_only_content
    content = set_screen_reader_only_content("ARIA")
    assert_equal "<span class=\"sr-only \">ARIA<\/span>", content

    content = set_screen_reader_only_content("ARIA", additional_class: "additional_class")
    assert_equal "<span class=\"sr-only additional_class\">ARIA<\/span>", content
  end

  def test_get_device_based_sr_only_content
    assert_equal "<span class=\"hidden-xs\">test_content</span><span class=\"sr-only visible-xs\">test_content</span>", get_device_based_sr_only_content("test_content")
  end

  def test_choices_wrapper
    content = choices_wrapper("Example Text", class: "example-class") { "dummy_content" }
    assert_equal "<div class=\"example-class\" role=\"group\" aria-label=\"Example Text\">dummy_content</div>", content
  end

  def test_construct_daterange_picker
    # if presets dont include 'custom'
    assert_nil construct_daterange_picker("daterange[param]", {}, presets: [DateRangePresets::NEXT_7_DAYS])

    content = construct_daterange_picker("daterange[param]", {}, min_date: Date.current, date_format: "MMMM dd, yyyy", right_addon: { type: "btn", content: "Go" }, additional_input_fields: [content_tag(:div, "additional text 1", class: "cjs_additional_input_field_1"), content_tag(:span, "additional text 2", class: "cjs_additional_input_field_2")] )
    set_response_text(content)
    assert_select "div.cjs_daterange_picker" do
      assert_select "div.form-group" do
        assert_select "label.sr-only", text: "Date Range Options"
        assert_select "select.cjs_daterange_picker_presets[data-ignore='true']" do
          assert_select "option", count: 6
          assert_select "option[value='today']", text: "Today"
          assert_select "option[value='last_7_days']", text: "Last 7 days"
          assert_select "option[value='month_to_date']", text: "Month to date"
          assert_select "option[value='year_to_date']", text: "Year to date"
          assert_select "option[value='last_month']", text: "Last Month"
          assert_select "option[value='custom'][selected='selected']", text: "Custom"
        end
      end
      assert_select "div.cjs_additional_input_field_1", text: "additional text 1"
      assert_select "span.cjs_additional_input_field_2", text: "additional text 2"
      assert_select "div.input-group", count: 2 do
        assert_select "span.input-group-addon", count: 2 do
          assert_select "i.fa-calendar", count: 2
        end
        assert_select "label.sr-only", text: "From"
        assert_select "label.sr-only", text: "To"
        assert_select "input.cjs_daterange_picker_start[placeholder='From'][autocomplete='off'][data-date-picker='true'][data-date-range='start'][data-min-date=\"#{DateTime.localize(Date.current, format: :full_display_no_time)}\"][data-ignore='true'][data-wrapper-class=''][value=''][data-rand-id]"
        assert_select "input.cjs_daterange_picker_end[placeholder='To'][autocomplete='off'][data-date-picker='true'][data-date-range='end'][data-min-date=\"#{DateTime.localize(Date.current, format: :full_display_no_time)}\"][data-ignore='true'][data-wrapper-class=''][value=''][data-rand-id]"
        assert_select "span.input-group-btn", count: 1 do
          assert_select "button", text: "Go"
        end
      end
      assert_select "label.hide", text: "Date Range"
      assert_select "input.cjs_daterange_picker_value.hide[value=''][name='daterange[param]'][data-date-format='MMMM dd, yyyy']"
      assert_select "script"
    end
  end

  def test_construct_daterange_picker_with_presets
    self.stubs(:wob_member).returns(members(:f_mentor))
    self.expects(:current_program).at_least(0).returns(programs(:albers))
    content = construct_daterange_picker("daterange[param]", { start: Date.current, end: (Date.current + 1.day) }, presets: [DateRangePresets::CUSTOM, DateRangePresets::LAST_MONTH, DateRangePresets::PROGRAM_TO_DATE])
    set_response_text(content)
    assert_select "div.cjs_daterange_picker" do
      assert_select "div.form-group" do
        assert_select "label.sr-only", text: "Date Range Options"
        assert_select "select.cjs_daterange_picker_presets[data-ignore='true'][data-current-date='#{DateTime.localize(Date.current.in_time_zone(wob_member.get_valid_time_zone), format: :date_range)}'][data-program-start-date='#{DateTime.localize(programs(:albers).created_at, format: :date_range)}']" do
          assert_select "option", count: 3
          assert_select "option[value='program_to_date']", text: "Program start to date"
          assert_select "option[value='last_month']", text: "Last Month"
          assert_select "option[value='custom'][selected='selected']", text: "Custom"
        end
      end
      assert_select "div.input-group", count: 2 do
        assert_select "span.input-group-addon", count: 2 do
          assert_select "i.fa-calendar", count: 2
        end
        assert_select "label.sr-only", text: "From"
        assert_select "label.sr-only", text: "To"
        assert_select "input.cjs_daterange_picker_start[placeholder='From'][autocomplete='off'][data-date-picker='true'][data-date-range='start'][data-max-date=\"#{DateTime.localize(Date.current + 1.day, format: :full_display_no_time)}\"][data-ignore='true'][data-wrapper-class=''][value=\"#{DateTime.localize(Date.current, format: :full_display_no_time)}\"][data-rand-id]"
        assert_select "input.cjs_daterange_picker_end[placeholder='To'][autocomplete='off'][data-date-picker='true'][data-date-range='end'][data-min-date=\"#{DateTime.localize(Date.current, format: :full_display_no_time)}\"][data-ignore='true'][data-wrapper-class=''][value=\"#{DateTime.localize(Date.current + 1.day, format: :full_display_no_time)}\"][data-rand-id]"
        assert_no_select "span.input-group-btn"
      end
      assert_select "label.hide", text: "Date Range"
      assert_select "input.cjs_daterange_picker_value.hide[data-date-format='MM/dd/yyyy'][value=\"#{DateTime.localize(Date.current, format: :date_range)} - #{DateTime.localize(Date.current + 1.day, format: :date_range)}\"][data-date-format='MM/dd/yyyy'][name='daterange[param]']"
      assert_select "script"
    end
  end

  def test_construct_daterange_picker_only_custom
    content = construct_daterange_picker("daterange[param]", {}, presets: [DateRangePresets::CUSTOM], input_size_class: "input-sm", hidden_field_attrs: { label: "Sent between", class: "cjs_class", id: "cjs_id" })
    set_response_text(content)
    assert_select "div.cjs_daterange_picker" do
      assert_no_select "select"
      assert_select "div.input-group", count: 2 do
        assert_select "span.input-group-addon", count: 2 do
          assert_select "i.fa-calendar", count: 2
        end
        assert_select "label.sr-only", text: "From"
        assert_select "label.sr-only", text: "To"
        assert_select "input.cjs_daterange_picker_start[placeholder='From'][autocomplete='off'][data-date-picker='true'][data-date-range='start'][data-ignore='true'][data-wrapper-class='input-sm'][value=''][data-rand-id]"
        assert_select "input.cjs_daterange_picker_end[placeholder='To'][autocomplete='off'][data-date-picker='true'][data-date-range='end'][data-ignore='true'][data-wrapper-class='input-sm'][value=''][data-rand-id]"
      end
      assert_select "label.hide", text: "Sent between"
      assert_select "input#cjs_id.cjs_class.cjs_daterange_picker_value.hide[value=''][name='daterange[param]'][data-date-format='MM/dd/yyyy']"
      assert_select "script"
    end
  end

  def test_render_comments_button_group
    buttons = [
      { type: 'btn', class: 'btn btn-primary', icon: "fa fa-paper-plane-o", content: "display_string.Comment".translate },
      { type: 'link', url: "javascript:void(0)", class: "btn btn-white cjs_comment_form_cancel", icon:"fa fa-times", content: "display_string.Cancel".translate },
      { type: 'file', id: "comment_attachment", name: "comment[attachment]", class: "quick_file" , wrapper_html: { class: "col-sm-6  cjs-attachment no-margins no-padding col-xs-3"}
      }]
    output = render_comments_button_group(buttons)
    assert_select_helper_function "button.btn.btn-primary.pull-right", output, data_disable_with: "<span class=\"hidden-xs\"><i class=\"fa fa-paper-plane-o fa-fw m-r-xs\"></i>Comment</span><span class=\"visible-xs\"><i class=\"fa fa-paper-plane-o no-margins fa-fw m-r-xs\"></i></span><span class=\"sr-only \">Comment</span>"
    assert_select_helper_function_block "a.btn.btn-white.pull-right", output do
      assert_select "span.hidden-xs", text:"Cancel"  do
        assert_select "i.fa.fa-times"
      end
      assert_select "span.visible-xs", html:"<i class=\"fa fa-times no-margins fa-fw m-r-xs\"><\/i>"  do
        assert_select "i.fa.fa-times"
      end
      assert_select "span.sr-only", text: "Cancel"
    end
    assert_select_helper_function_block "div.cjs-attachment", output do
      assert_select "input.quick_file", ""
    end
  end

  def test_map_kendo_date_format
    assert_equal :full_display_no_time, map_kendo_date_format("MMMM dd, yyyy")
    assert_equal :date_range, map_kendo_date_format("MM/dd/yyyy")
  end

  def test_date_picker_options
    min_date = "February 11, 2015".to_date
    max_date = "February 12, 2016".to_date
    options = { min_date: min_date, max_date: max_date, date_range: "end", unnecessary: true, wrapper_class: "input-sm", disable_date_picker: true }
    date_picker_options = date_picker_options(options)
    assert_equal "February 11, 2015", date_picker_options[:min_date]
    assert_equal "February 12, 2016", date_picker_options[:max_date]
    assert_equal "end", date_picker_options[:date_range]
    assert_equal "input-sm", date_picker_options[:wrapper_class]
    assert date_picker_options[:disable_date_picker]
    assert date_picker_options[:rand_id]
    assert_nil date_picker_options[:unnecessary]

    GlobalizationUtils.run_in_locale("fr-CA") do
      date_picker_options = date_picker_options(options)
    end
    assert_equal "February 11, 2015", date_picker_options[:min_date]
    assert_equal "February 12, 2016", date_picker_options[:max_date]
    assert_equal "end", date_picker_options[:date_range]
    assert_equal "input-sm", date_picker_options[:wrapper_class]
    assert date_picker_options[:disable_date_picker]
    assert date_picker_options[:rand_id]
    assert_nil date_picker_options[:unnecessary]
  end

  def test_horizontal_or_separator
    content = horizontal_or_separator("margin-class")
    assert_match /margin-class/, content
    assert_match /OR/, content
  end

  def test_get_tnc_privacy_policy_urls
    urls = get_tnc_privacy_policy_urls
    terms_url = urls[:terms]
    privacy_policy_url = urls[:privacy_policy]
    cookies_url = urls[:cookies]
    assert_match /class=\"cjs_external_url\"/, terms_url
    assert_match /class=\"cjs_external_url\"/, privacy_policy_url
    assert_match /class=\"cjs_external_url\"/, cookies_url
  end

  def test_viewport_meta_tag
    self.expects(:mobile_device?).returns(true)
    assert_equal "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\" />", viewport_meta_tag
    self.expects(:mobile_device?).returns(false)
    assert_equal "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />", viewport_meta_tag
  end

  def test_populate_feedback_id
    program = programs(:albers)
    assert populate_feedback_id({}, program)
    meeting = meetings(:f_mentor_mkr_student)
    assert populate_feedback_id({meeting_id: meeting.id}, program)
    assert_false populate_feedback_id({meeting_id: 0}, program)
  end

  def test_is_android_app
    request = stub
    self.stubs(:request).returns(request)
    # android app, but does not contain Chronus useragent
    useragent = "Android SDK 1.5r3: Mozilla/5.0 (Linux; U; Android 1.5; de-; sdk Build/CUPCAKE) AppleWebkit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1"
    browser = Browser.new(useragent)
    assert browser.platform.android?
    self.expects(:browser).once.returns(browser)
    request.expects(:user_agent).twice.returns(useragent)
    assert_false is_android_app?
    # Not an android app, but contain Chronus useragent
    useragent = "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H141 Chronusandroid"
    browser = Browser.new(useragent)
    assert_false browser.platform.android?
    self.expects(:browser).once.returns(browser)
    request.expects(:user_agent).never
    assert_false is_android_app?
    # Android app and contains Chronus useragent
    useragent = "Android SDK 1.5r3: Mozilla/5.0 (Linux; U; Android 1.5; de-; sdk Build/CUPCAKE) AppleWebkit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1 Chronusandroid"
    browser = Browser.new(useragent)
    assert browser.platform.android?
    self.expects(:browser).twice.returns(browser)
    request.expects(:user_agent).twice.returns(useragent)
    assert is_android_app?
    assert_equal "cjs_android_download_files", mobile_app_class_for_download_files
  end

  def test_get_traffic_origin
    request = stub
    self.stubs(:request).returns(request)
    # For android browser
    useragent = "Mozilla/5.0 (Linux; U; Android 8.1; en-us; Nexus S Build/JRO03E) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"
    browser = Browser.new(useragent)
    self.stubs(:browser).returns(browser)
    request.stubs(:user_agent).returns(useragent)
    assert_false mobile_app?
    assert_equal 'mobile_browser', get_traffic_origin
    # For ios browser
    useragent = "Mozilla/5.0 (iPhone; U; CPU iPhone OS 11_0 like Mac OS X; en-us) AppleWebKit/532.9 (KHTML, like Gecko) Version/4.0.5 Mobile/8A293 Safari/6531.22.7"
    browser = Browser.new(useragent)
    self.stubs(:browser).returns(browser)
    assert_false mobile_app?
    assert_equal 'mobile_browser', get_traffic_origin
    # For Android app
    useragent = "Android SDK 1.5r3: Mozilla/5.0 (Linux; U; Android 1.5; de-; sdk Build/CUPCAKE) AppleWebkit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1 Chronusandroid"
    browser = Browser.new(useragent)
    self.stubs(:browser).returns(browser)
    request.stubs(:user_agent).returns(useragent)
    assert mobile_app?
    assert_equal 'mobile_app', get_traffic_origin
    # For Ios App
    useragent = "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H141"
    browser = Browser.new(useragent)
    self.stubs(:browser).returns(browser)
    assert mobile_app?
    assert_equal 'mobile_app', get_traffic_origin
  end

  def test_is_iab
    request = stub
    self.stubs(:request).returns(request)
    # android app, but does not contain Chronus useragent
    useragent = "Android SDK 1.5r3: Mozilla/5.0 (Linux; U; Android 1.5; de-; sdk Build/CUPCAKE) AppleWebkit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1"
    browser = Browser.new(useragent)
    assert browser.platform.android?
    self.expects(:browser).twice.returns(browser)
    request.expects(:user_agent).times(4).returns(useragent)
    assert_false is_android_app?
    assert_false is_iab?
    # Not an android app, but contain Chronus useragent
    useragent = "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H141 ChronusandroidIAB"
    browser = Browser.new(useragent)
    assert_false browser.platform.android?
    self.expects(:browser).twice.returns(browser)
    request.expects(:user_agent).never
    assert_false is_android_app?
    assert_false is_iab?
    # Android app and contains Chronus useragent
    useragent = "Android SDK 1.5r3: Mozilla/5.0 (Linux; U; Android 1.5; de-; sdk Build/CUPCAKE) AppleWebkit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1 Chronusandroid"
    browser = Browser.new(useragent)
    assert browser.platform.android?
    self.expects(:browser).times(3).returns(browser)
    request.expects(:user_agent).times(5).returns(useragent)
    assert is_android_app?
    assert_false is_iab?
    assert_equal "cjs_android_download_files", mobile_app_class_for_download_files
    # Android app and contains Chronus useragent
    useragent = "Android SDK 1.5r3: Mozilla/5.0 (Linux; U; Android 1.5; de-; sdk Build/CUPCAKE) AppleWebkit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1 ChronusandroidIAB"
    browser = Browser.new(useragent)
    assert browser.platform.android?
    self.expects(:browser).times(3).returns(browser)
    request.expects(:user_agent).times(5).returns(useragent)
    assert is_android_app?
    assert is_iab?
    assert_equal "cjs_android_download_files", mobile_app_class_for_download_files
  end

  def test_is_kitkat_app
    request = stub
    self.stubs(:request).returns(request)

    useragent = "Android SDK 1.5r3: Mozilla/5.0 (Linux; U; Android 1.5; de-; sdk Build/CUPCAKE) AppleWebkit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1 Chronusandroid"
    browser = Browser.new(useragent)
    assert browser.platform.android?
    self.expects(:browser).twice.returns(browser)
    request.expects(:user_agent).twice.returns(useragent)
    assert_false is_kitkat_app?

    useragent = "Android SDK 1.5r3: Mozilla/5.0 (Linux; U; Android 4.4.2; de-; sdk Build/CUPCAKE) AppleWebkit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1 Chronusandroid"
    browser = Browser.new(useragent)
    assert browser.platform.android?
    self.expects(:browser).twice.returns(browser)
    request.expects(:user_agent).twice.returns(useragent)
    assert is_kitkat_app?

    useragent = "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H141 Chronusandroid"
    browser = Browser.new(useragent)
    assert_false browser.platform.android?
    self.expects(:browser).once.returns(browser)
    request.expects(:user_agent).never
    assert_false is_kitkat_app?
  end

  def test_is_ios_app
    # webview's useragent
    useragent = "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H141"
    browser = Browser.new(useragent)
    self.expects(:browser).twice.returns(browser)
    assert is_ios_app?
    assert_equal "cjs_external_link", mobile_app_class_for_download_files

    # Safari's useragent
    useragent = "Mozilla/5.0 (iPad; CPU OS 9_0 like Mac OS X) AppleWebKit/601.1.17 (KHTML, like Gecko) Version/8.0 Mobile/13A175 Safari/600.1.4"
    browser = Browser.new(useragent)
    self.expects(:browser).once.returns(browser)
    assert_false is_ios_app?
  end

  def test_ios_browser
    # is_ios_app is false
    useragent = "Mozilla/5.0 (iPhone; U; CPU iPhone OS 11_0 like Mac OS X; en-us) AppleWebKit/532.9 (KHTML, like Gecko) Version/4.0.5 Mobile/8A293 Safari/6531.22.7"
    browser = Browser.new(useragent)
    self.expects(:browser).twice.returns(browser)
    assert ios_browser?

    # is_ios_app is true
    # "Safari" will not be present in useragent for ios webview
    useragent = "Mozilla/5.0 (iPhone; U; CPU iPhone OS 11_0 like Mac OS X; en-us) AppleWebKit/532.9 (KHTML, like Gecko) Version/4.0.5 Mobile/8A293"
    browser = Browser.new(useragent)
    self.expects(:browser).twice.returns(browser)
    assert_false ios_browser?
  end

  def test_android_browser
    request = stub
    self.stubs(:request).returns(request)
    # is_android_app is false
    useragent = "Mozilla/5.0 (Linux; U; Android 8.1; en-us; Nexus S Build/JRO03E) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"
    browser = Browser.new(useragent)
    self.expects(:browser).twice.returns(browser)
    request.expects(:user_agent).twice.returns(useragent)
    assert android_browser?

    # is_android_app is true
    # "Chronusandroid" will be present in useragent for android app
    useragent = "Mozilla/5.0 (Linux; U; Android 8.1; en-us; Nexus S Build/JRO03E) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30 Chronusandroid"
    browser = Browser.new(useragent)
    self.expects(:browser).twice.returns(browser)
    request.expects(:user_agent).twice.returns(useragent)
    assert_false android_browser?
  end

  def test_mobile_browser
    # ios browser
    useragent = "Mozilla/5.0 (iPhone; U; CPU iPhone OS 9_0 like Mac OS X; en-us) AppleWebKit/532.9 (KHTML, like Gecko) Version/4.0.5 Mobile/8A293 Safari/6531.22.7"
    browser = Browser.new(useragent)
    self.expects(:browser).twice.returns(browser)
    assert mobile_browser?

    # android browser
    request = stub
    self.stubs(:request).returns(request)
    useragent = "Mozilla/5.0 (Linux; U; Android 5.1; en-us; Nexus S Build/JRO03E) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"
    browser = Browser.new(useragent)
    self.expects(:browser).times(3).returns(browser)
    request.expects(:user_agent).twice.returns(useragent)
    assert mobile_browser?

    # neither ios nor android
    # android app
    useragent = "Mozilla/5.0 (Linux; U; Android 4.1.1; en-us; Nexus S Build/JRO03E) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30 Chronusandroid"
    browser = Browser.new(useragent)
    self.expects(:browser).times(3).returns(browser)
    request.expects(:user_agent).twice.returns(useragent)
    assert_false mobile_browser?

    # neither ios nor android
    # ios app
    useragent = "Mozilla/5.0 (iPhone; U; CPU iPhone OS #8_0 like Mac OS X; en-us) AppleWebKit/532.9 (KHTML, like Gecko) Version/4.0.5 Mobile/8A293"
    browser = Browser.new(useragent)
    self.expects(:browser).times(3).returns(browser)
    assert_false mobile_browser?
  end

  def test_mobile_platform
    # ios case
    useragent = "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H141"
    browser = Browser.new(useragent)
    self.expects(:browser).once.returns(browser)
    assert_equal MobileDevice::Platform::IOS, mobile_platform

    # android case
    request = stub
    self.stubs(:request).returns(request)
    useragent = "Android SDK 1.5r3: Mozilla/5.0 (Linux; U; Android 1.5; de-; sdk Build/CUPCAKE) AppleWebkit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1 Chronusandroid"
    browser = Browser.new(useragent)
    assert browser.platform.android?
    self.expects(:browser).twice.returns(browser)
    request.expects(:user_agent).twice.returns(useragent)
    assert_equal MobileDevice::Platform::ANDROID, mobile_platform

    # none
    useragent = "Mozilla/5.0 (Linux; U; Android 5.1; en-us; Nexus S Build/JRO03E) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"
    browser = Browser.new(useragent)
    self.expects(:browser).twice.returns(browser)
    request.expects(:user_agent).twice.returns(useragent)
    assert_nil mobile_platform
  end

  def test_password_instructions
    @current_organization = programs(:org_primary)
    auth_config = @current_organization.chronus_auth
    assert_equal "Minimum 6 characters", password_instructions

    auth_config.update_attributes!(password_message: "              ")
    assert_equal "Minimum 6 characters", password_instructions

    auth_config.update_attributes!(password_message: "<div>Password message</div>")
    assert_equal "<div>Password message</div>", password_instructions
    assert password_instructions.html_safe?
  end

  def test_is_external_link_without_organizations
    #current_organization is nil
    assert_false is_external_link?("abc.com")
    assert_false is_external_link?("mentor.localhost.com")
  end

  def test_is_external_link_with_organizations
    #no protocol
    org_host = programs(:org_primary).hostnames.first
    @current_organization = programs(:org_primary)
    assert_false is_external_link?("abc.com")
    assert_false is_external_link?("mentor.localhost.com")
    assert_false is_external_link?(org_host)

    #with protocol
    @current_organization = programs(:org_primary)
    assert is_external_link?("http://abc.com")
    assert_false is_external_link?("http://mentor.localhost.com")
    assert_false is_external_link?(org_host)
  end

  def test_use_browsertab_for_external_link
    @current_organization = programs(:org_primary)
    assert_false use_browsertab_for_external_link?("http://abc.com")
    assert_false use_browsertab_for_external_link?("http://mentor.localhost.com")
    assert_false use_browsertab_for_external_link?(OpenAuthUtils::Configurations::Linkedin::AUTHORIZE_ENDPOINT)
    assert use_browsertab_for_external_link?(OpenAuthUtils::Configurations::Google::AUTHORIZE_ENDPOINT)
    assert use_browsertab_for_external_link?(GoogleOAuthCredential::AUTHORIZE_URL)
    assert use_browsertab_for_external_link?(MicrosoftOAuthCredential::SITE + MicrosoftOAuthCredential::AUTHORIZE_URL)
  end

  def test_bulk_action_users_list
    users = [users(:f_mentor), users(:f_student)]
    users_list = bulk_action_users_list(users)
    assert_equal "Good unique name, student example", users_list
    assert_false users_list.html_safe?
    users_list = bulk_action_users_list(users, render_profile_link: false)
    assert_equal "Good unique name, student example", users_list
    assert_false users_list.html_safe?
    users_list = bulk_action_users_list(users, render_profile_link: true)
    assert_select_helper_function("a[href='/p/albers/members/#{users(:f_mentor).member_id}']", users_list, text: "Good unique name")
    assert_select_helper_function("a[href='/p/albers/members/#{users(:f_student).member_id}']", users_list, text: "student example")
    assert users_list.html_safe?
  end

  def test_bulk_action_members_list
    members = [members(:f_mentor), members(:f_student)]
    members_list = bulk_action_members_list(members)
    assert_equal "Good unique name, student example", members_list
    assert_false members_list.html_safe?
    members_list = bulk_action_members_list(members, render_profile_link: false)
    assert_equal "Good unique name, student example", members_list
    assert_false members_list.html_safe?
    members_list = bulk_action_members_list(members, render_profile_link: true)
    assert_select_helper_function("a[href='/members/#{members(:f_mentor).id}']", members_list, text: "Good unique name")
    assert_select_helper_function("a[href='/members/#{members(:f_student).id}']", members_list, text: "student example")
    assert members_list.html_safe?
  end

  def test_bulk_action_users_or_members_list
    users = [users(:f_mentor), users(:f_student)]
    members = [members(:f_mentor), members(:f_student)]
    viewer_info_hash = [
      { organization_admin: true, program_admin: true },
      { organization_admin: true, program_admin: false },
      { organization_admin: false, program_admin: true },
      { organization_admin: false, program_admin: false },
    ]
    viewer_info_hash.each do |viewer_info|
      self.expects(:bulk_action_users_list).with(users, render_profile_link: viewer_info[:program_admin]).once
      bulk_action_users_or_members_list(users, viewer_info)
    end

    viewer_info_hash.each do |viewer_info|
      self.expects(:bulk_action_members_list).with(members, render_profile_link: viewer_info[:organization_admin]).once
      bulk_action_users_or_members_list(members, viewer_info)
    end
  end

  def test_show_search_box
    user = users(:f_mentor)
    program = user.program
    self.expects(:current_program).at_least(0).returns(program)
    self.expects(:current_user).at_least(0).returns(user)

    self.expects(:program_view?).once.returns(false)
    self.expects(:logged_in_program?).never
    user.expects(:profile_pending?).never
    program.expects(:searchable_classes).never
    assert_false show_search_box?

    self.expects(:program_view?).times(4).returns(true)
    self.expects(:logged_in_program?).once.returns(false)
    assert_false show_search_box?

    self.expects(:logged_in_program?).times(3).returns(true)
    user.expects(:profile_pending?).once.returns(true)
    assert_false show_search_box?

    user.expects(:profile_pending?).times(2).returns(false)
    program.expects(:searchable_classes).once.returns([])
    assert_false show_search_box?

    program.expects(:searchable_classes).once.returns([Article.name])
    assert show_search_box?
  end

  def test_build_dropdown_link
    options = { title: "Dropdown" }
    actions = []
    actions << {
      label: "action 1",
      url: "javascript:void(0)"
    }
    actions << {
      label: "action 2",
      url: "javascript:void(0)"
    }

    self.expects(:render_action_for_dropdown_button).with(actions[0]).once.returns("Rendered Action 1")
    self.expects(:render_action_for_dropdown_button).with(actions[1]).once.returns("Rendered Action 2")
    content = build_dropdown_link(options, actions)
    assert_select_helper_function_block "a[data-toggle='dropdown']", content, text: "Dropdown" do
      assert_select "span.caret"
    end
    assert_select_helper_function_block "ul.dropdown-menu", content do
      assert_select "li", count: 2
      assert_select "li", text: "Rendered Action 1"
      assert_select "li", text: "Rendered Action 2"
    end
  end

  def test_user_media_container
    @current_user = users(:f_admin)
    content = user_media_container(@current_user, "March 8, 2017".to_datetime, content_tag(:span, "Actions user_media_container!")) do
      content_tag(:span, "Inside user_media_container!")
    end
    assert_select_helper_function_block "div.p-sm", content do
      assert_select "span", text: "Actions user_media_container!"
      assert_select "div.media-left" do
        assert_select "span", text: "RENDERING common/member_picture"
      end
      assert_select "div.media-body" do
        assert_select "h4", text: "YouMarch 08, 2017 at 12:00 AM" do
          assert_no_select "a"
          assert_select "span", text: "March 08, 2017 at 12:00 AM"
        end
      end
      assert_select "span", text: "Inside user_media_container!"
    end

    mentor_user = users(:f_mentor)
    content = user_media_container(mentor_user) do
      content_tag(:span, "Inside user_media_container!")
    end
    assert_select_helper_function_block "div.p-sm", content do
      assert_select "div.media-left" do
        assert_select "span", text: "RENDERING common/member_picture"
      end
      assert_select "div.media-body" do
        assert_select "h4", text: "Good unique nameGood unique name" do
          assert_select "a[href='#{member_path(mentor_user)}']", text: "Good unique name"
        end
      end
      assert_select "span", text: "Inside user_media_container!"
    end
  end

  def test_link_or_drop_down_actions
    assert_equal "", link_or_drop_down_actions([])
    action_1 = {label: "Request Connection", disabled: true, tooltip: "Not a match"}
    action_2 = {label: "Request Meeting", disabled: true, tooltip: "Not a match"}

    actions = [action_1]
    self.stubs(:render_action_for_dropdown_button).with(action_1, " ").returns("link")
    assert_equal "link", link_or_drop_down_actions(actions)

    actions = [action_1, action_2]
    options = {dropdown_title: "dropdown"}
    self.stubs(:build_dropdown_filters_without_button).with(options[:dropdown_title], actions, options).returns("link_2")
    assert_equal "link_2", link_or_drop_down_actions(actions, options)
  end

  def test_render_mobile_floating_action_inline
    @@skip_local_render = true
    assert_nil render_mobile_floating_action_inline({})

    options = {
      icon_class: "fa fa-comment",
      sr_text: "Reply",
      additional_class: "test_additional_class"
    }
    content = render_mobile_floating_action_inline(options).squish
    assert_select_helper_function "script", content, text: ' //<![CDATA[ if(jQuery("#cjs-mobile-footer-action").length > 0) { jQuery("#cjs-mobile-footer-action").replaceWith(" <div class=\"cui-mobile-floater-action hidden-lg hidden-md\" id=\"cjs-mobile-footer-action\">\n <a id=\"\" class=\"btn btn-primary btn-lg btn-circle test_additional_class\" title=\"\" href=\"javascript:void(0)\"><i class=\"fa fa-comment\"><\/i><span class=\"sr-only \">Reply<\/span><\/a>\n <\/div>\n"); } else { jQuery("body").append(" <div class=\"cui-mobile-floater-action hidden-lg hidden-md\" id=\"cjs-mobile-footer-action\">\n <a id=\"\" class=\"btn btn-primary btn-lg btn-circle test_additional_class\" title=\"\" href=\"javascript:void(0)\"><i class=\"fa fa-comment\"><\/i><span class=\"sr-only \">Reply<\/span><\/a>\n <\/div>\n"); } //]]> '
  end

  def test_render_logo_or_banner
    program = programs(:albers)
    organization = program.organization
    program_asset = program.create_program_asset
    program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program_asset.banner = fixture_file_upload(File.join('files', 'test_horizontal.jpg'), 'image/jpeg')
    program_asset.save!
    organization_asset = organization.create_program_asset
    organization_asset.banner = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    organization_asset.save!

    assert_select_helper_function "img.logo-or-banner[src='#{program.logo_url}']", render_logo_or_banner(program, class: "logo-or-banner"), alt: "Program Logo"
    assert_select_helper_function "img[src='#{organization.banner_url}']", render_logo_or_banner(organization, size: "100x50"), alt: "Program Banner", width: "100", height: "50"
  end

  def test_render_report_tiles
    @@skip_local_render = true
    current_count = 2
    icon_content = "fa fa-calendar"
    tile_title = "Scheduled"
    tile_text = "Meetings Accepted"

    content = render_report_tiles(current_count, icon_content, tile_title, tile_text)
    assert_select_helper_function_block "div.col-md-3", content do
      assert_select "div.ibox" do
        assert_select "div.ibox-content" do
          assert_select "h4", text: tile_title
          assert_select "div.p-l-0" do
            assert_select "h1.m-b-sm", text: "#{current_count}"
          end
            assert_select "div", text: tile_text
        end
      end
    end

    SecureRandom.stubs(:hex).with(3).returns(4)
    content = render_report_tiles(current_count, icon_content, tile_title, tile_text, {:percentage=>-250, :prev_periods_count=>7}).squish
    assert_select_helper_function "script", content, text: ' //<![CDATA[ jQuery("#percentage_change_caret_4").tooltip({html: true, title: \'<div>7 in the previous period</div>\', placement: "top", container: "#percentage_change_caret_4", delay: { "show" : 500, "hide" : 100 } } );jQuery("#percentage_change_caret_4").on("remove", function () {jQuery("#percentage_change_caret_4 .tooltip").hide().remove();}) //]]> '

    current_count = 2
    icon_content = "fa fa-exclamation-triangle "
    tile_title = "Overdue"
    tile_text = ""
    percentage = -250
    prev_period_count = 7
    content = render_report_tiles(current_count, icon_content, tile_title, tile_text, {:percentage=>percentage, :prev_periods_count=>prev_period_count})
    assert_select_helper_function_block "div.col-md-3", content do
      assert_select "div.ibox" do
        assert_select "div.ibox-content" do
          assert_select "h4", text: tile_title
          assert_select "div.p-l-0" do
            assert_select "h1.m-b-sm", text: "#{current_count}"
            assert_select "div.stat-percent", text: "#{percentage}%" do
              assert_select "i.fa-caret-down"
            end
          end
          assert_select "div", text: tile_text
        end
      end
    end
  end

  def test_listing_page
    collection = programs(:albers).articles
    result = listing_page(collection)
    assert_select_helper_function_block "div.list-group", result do
      assert_select "div.word_break.list-group-item", count: collection.count
    end
  end

  def test_get_match_details_for_display
    user = users(:f_student)
    mentor_user = users(:f_mentor)
    user.expects(:get_match_details_of).with(mentor_user, [], nil).returns([])
    content = get_match_details_for_display(user, mentor_user, [])
    assert_equal ["", 0, 0, 0], content

    user.expects(:get_match_details_of).with(mentor_user, [], nil).returns([{question_text: "xyz", answers:["abc"]}])
    content, tags_count = get_match_details_for_display(user, mentor_user, [])
    assert_select_helper_function "span.label.small.status_icon.m-r-xs", content, text: "abc"
    assert_equal tags_count, 1

    user.expects(:get_match_details_of).with(mentor_user, [], nil).returns([{question_text: "xyz", answers:["abc", "efg"]}])
    content, tags_count = get_match_details_for_display(user, mentor_user, [])
    assert_equal tags_count, 2
    assert_select_helper_function "span.label.small.status_icon.m-r-xs", content, text: "abc"
    assert_select_helper_function "span.label.small.status_icon.m-r-xs", content, text: "efg"
  end

  def test_get_details_content_for_match_details
    assert_equal "", get_details_content_for_match_details("")

    text = get_details_content_for_match_details("abc")
    set_response_text(text)
    assert_select "span.match_details", text: "abc"
  end

  def test_get_ckeditor_type_classes
    assert_nil get_ckeditor_type_classes(nil)
    assert_equal "cjs_ckeditor_dont_register_for_tags_warning", get_ckeditor_type_classes(CampaignManagement::AbstractCampaign.name)
    assert_equal "cjs_ckeditor_dont_register_for_tags_warning cjs_ckeditor_dont_register_for_insecure_content", get_ckeditor_type_classes(MentoringModel::FacilitationTemplate.name)
  end

  def test_render_privacy_policy_para
    content = render_privacy_policy_para("chronus_privacy_policy.chronus_llc.information.content.para_", ["1_1"])
    assert_select_helper_function("div.m-b-sm", content, text: "Chronus collects information from you solely as described in this Privacy Policy. Chronus may collect information from you both online and offline. We may combine information collected from these disparate sources unless we tell you otherwise. Chronus collects three general categories of information from you:")

    assert_blank render_privacy_policy_para("chronus_privacy_policy.chronus_llc.information.content.para_", nil)
  end

  def test_list_privacy_policy_points
    content = list_privacy_policy_points("chronus_privacy_policy.chronus_llc.information.content.subheading_2.point_", [1])
    assert_select_helper_function_block("ul", content) do
      assert_select "li.m-b-xs", text: "the URL of the website you just visited; and"
    end

    assert_blank list_privacy_policy_points("chronus_privacy_policy.chronus_llc.information.content.subheading_2.point_", nil)
  end

  def test_get_data_hash_for_dropzone
    program = programs(:albers)
    data_hash = get_data_hash_for_dropzone(program.id, ProgramAsset::Type::LOGO, file_name: nil, type_id: ProgramAsset::Type::LOGO, uploaded_class: ProgramAsset.name, accepted_types: PICTURE_CONTENT_TYPES, class_list: "p-t-xxs", max_file_size: ProgramAsset::MAX_SIZE[ProgramAsset::Type::LOGO])
    assert_equal "/file_uploads", data_hash[:url]
    assert_equal ({ type_id: ProgramAsset::Type::LOGO, owner_id: program.id, uploaded_class: ProgramAsset.name }), data_hash[:url_params]
    assert_equal PICTURE_CONTENT_TYPES.join(","), data_hash[:accepted_types]
    assert_equal 2.megabytes, data_hash[:max_file_size]
    assert_nil data_hash[:init_file]
    assert_equal "p-t-xxs", data_hash[:class_list]

    data_hash = get_data_hash_for_dropzone(program.id, ProgramAsset::Type::LOGO, file_name: "test_pic.png", type_id: ProgramAsset::Type::LOGO, uploaded_class: ProgramAsset.name, max_file_size: ProgramAsset::MAX_SIZE[ProgramAsset::Type::LOGO])
    assert_equal "test_pic.png", data_hash[:init_file][:name]
    assert_equal "", data_hash[:class_list]
    assert_equal DEFAULT_ALLOWED_FILE_UPLOAD_TYPES.join(","), data_hash[:accepted_types]
  end

  def test_get_page_subtitle
    sub_title_class = "sub_title_class"
    screen_reader_content = "screen_reader_content"
    set_response_text(get_page_subtitle(sub_title_class, screen_reader_content))
    assert_select "span.sub_title_class.pointer", count: 1
    assert_select "span.sr-only", text: screen_reader_content, count: 1

    sub_title_class2 = nil
    screen_reader_content2 = nil
    set_response_text(get_page_subtitle(sub_title_class2, screen_reader_content2))
    assert_select "span.pointer", count: 1
    assert_select "span.sr-only", count: 1
  end

  def test_get_support_link
    content = get_support_link
    assert_select_helper_function "a.cjs_external_link", content, count: 1, text: "Support"
    assert_select_helper_function "i.fa-life-ring", content, count: 0

    content = get_support_link(include_icon: true)
    assert_select_helper_function "a.cjs_external_link", content, count: 1, text: "Support"
    assert_select_helper_function "i.fa-life-ring", content, count: 1
  end

  def test_render_select_all_clear_all
    select_all_options = { id: "select_all_id", class: "cjs_select_all_options" }
    clear_all_options = { id: "clear_all_id", class: "cjs_clear_all_options" }
    options = { select_all_options: select_all_options, clear_all_options: clear_all_options }
    expects(:link_to_function).with("Select all", "select_all_function", select_all_options).returns("select_all_link")
    expects(:vertical_separator).returns("|")
    expects(:link_to_function).with("Clear", "clear_all_function", clear_all_options).returns("clear_link")
    assert_equal "select_all_link|clear_link", render_select_all_clear_all("select_all_function", "clear_all_function", options)
  end

  private

  def get_subtabs_hash
    {
      TabConfiguration::Tab::SubTabKeys::LINKS_LIST => [],
      TabConfiguration::Tab::SubTabKeys::LINK_LABEL_HASH => {},
      TabConfiguration::Tab::SubTabKeys::BADGE_COUNT_HASH => {},
      TabConfiguration::Tab::SubTabKeys::ICON_CLASS_HASH => {},
      TabConfiguration::Tab::SubTabKeys::IS_ACTIVE_HASH => {},
      TabConfiguration::Tab::SubTabKeys::HAS_PARTIAL_HASH => {},
      TabConfiguration::Tab::SubTabKeys::RENDER_PATH_HASH => {}
    }
  end

  def membership_requests_path(opts = {})
    "/membership_requests?view=#{opts[:view]}"
  end

  def current_user
    @current_user || User.first
  end

  def request
    mock(:cookies => @cookies || {})
  end

  def render(options)
    unless @@skip_local_render
      return "<span>RENDERING #{options[:partial]}</span>".html_safe
    else
      super
    end
  end

  def _mentor
    "mentor"
  end

  def _Mentoring
    "Mentoring"
  end

  def _Mentors
    "Mentors"
  end

  def _Mentees
    "Mentees"
  end

  def _mentees
    "students"
  end

  def _program
    "track"
  end

  def _admin
    "super admin"
  end

  def _Meetings
    "Meetings"
  end
end