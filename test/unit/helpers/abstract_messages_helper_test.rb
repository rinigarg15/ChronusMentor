require_relative "./../../test_helper.rb"
require_relative "./../../../app/helpers/abstract_messages_helper"

class AbstractMessagesHelperTest < ActionView::TestCase
  include AutoCompleteMacrosHelper
  include ScrapExtensions

  def setup
    super
    helper_setup
    @current_program = programs(:albers)
  end

  def test_display_message_content
    assert_equal "<div class=\"clearfix\"><p>This is going to be very interesting</p></div>", display_message_content(messages(:first_message))
  end

  def test_message_content_format
    user_to_admin_message = messages(:first_admin_message)
    user_to_admin_message.update_attribute(:content, "this has <strong>bold</strong> content <script>alert('hacked')</script> and \n newline in it")
    assert_equal "this has &lt;strong&gt;bold&lt;/strong&gt; content &lt;script&gt;alert(&#39;hacked&#39;)&lt;/script&gt; and \n<br /> newline in it", message_content_format(user_to_admin_message)

    admin_to_user_message = messages(:first_campaigns_admin_message)
    admin_to_user_message.update_attribute(:content, "this has <strong>bold</strong> content <script>alert('hacked')</script> and \n newline in it")
    assert_equal "this has <strong>bold</strong> content <script>alert('hacked')</script> and \n newline in it", message_content_format(admin_to_user_message)
  end

  def test_messages_tab_title
    assert_equal "<i class=\"fa fa-inbox\"></i><span class=\"m-r-xxs\">Inbox</span><span class=\"cjs_messages_count\">(1)</span>", messages_tab_title(1, MessageConstants::Tabs::INBOX)
    assert_equal "<i class=\"fa fa-inbox\"></i><span class=\"m-r-xxs\">Inbox</span><span class=\"cjs_messages_count\">(1)</span>", messages_tab_title(1, nil)
    assert_equal "<i class=\"fa fa-paper-plane-o\"></i><span class=\"m-r-xxs\">Sent</span><span class=\"cjs_messages_count\">(1)</span>", messages_tab_title(1, MessageConstants::Tabs::SENT)
    assert_equal "<i class=\"fa fa-inbox\"></i><span class=\"m-r-xxs\">Inbox</span><span class=\"cjs_messages_count\">(0)</span>", messages_tab_title(0, MessageConstants::Tabs::INBOX)
  end

  def test_get_from_to_details_from_scrap
    group = groups(:mygroup)
    message = create_scrap(group: group, sender: members(:f_mentor))
    message_2 = create_scrap(group: group, sender: members(:mkr_student))
    message_2.update_attributes!(:parent_id => message.id, :root_id => message.id)

    assert_equal_hash_without_picture ({names: "me, <span class=\"font-600 cjs-from-name\">mkr_student madankumarrajan</span> (2)", unread: true}), get_from_details(message, members(:f_mentor), {:from_scrap => true})
    # with preloaded options
    preload_hash = get_preloaded_scraps_hash(message.root_id, members(:f_mentor))
    assert_equal_hash_without_picture ({names: "me, <span class=\"font-600 cjs-from-name\">mkr_student madankumarrajan</span> (2)", unread: true}), get_from_details(message, members(:f_mentor), {from_scrap: true, preloaded: true, siblings: preload_hash[:siblings_index][message.root_id]}.merge(preload_hash.slice(:viewable_scraps_hash, :unread_scraps_hash, :deleted_scraps_hash)))
  end

  def test_get_from_to_details
    message = create_message(sender: members(:f_mentor), receivers: [members(:arun_albers)])
    message_2 = create_message(sender: members(:arun_albers), receivers: [members(:f_mentor)])
    message_2.update_attribute(:parent_id, message.id)

    assert_equal_hash_without_picture ({names: "me, <span class=\"h5 font-600 m-b-0 m-t-0 cjs-from-name hidden-lg hidden-md\">arun albers</span><span class=\"font-600 cjs-from-name hidden-xs hidden-sm\">arun albers</span> (2)", unread: true}), get_from_details(message, members(:f_mentor), {})
    assert_equal_hash_without_picture ({names: "arun albers (2)", unread: true}), get_to_details(message, members(:f_mentor))
    assert_equal_hash_without_picture ({names: "<span class=\"h5 font-600 m-b-0 m-t-0 cjs-from-name hidden-lg hidden-md\">Good unique name</span><span class=\"font-600 cjs-from-name hidden-xs hidden-sm\">Good unique name</span>, me (2)", unread: true}), get_from_details(message, members(:arun_albers), {})
    assert_equal_hash_without_picture ({names: "Good unique name (2)", unread: true}), get_to_details(message, members(:arun_albers))

    message.mark_as_read!(members(:arun_albers))
    assert_equal_hash_without_picture ({names: "me, <span class=\"h5 font-600 m-b-0 m-t-0 cjs-from-name hidden-lg hidden-md\">arun albers</span><span class=\"font-600 cjs-from-name hidden-xs hidden-sm\">arun albers</span> (2)", unread: true}), get_from_details(message, members(:f_mentor), {})
    assert_equal_hash_without_picture ({names: "arun albers (2)", unread: true}), get_to_details(message, members(:f_mentor))
    assert_equal_hash_without_picture ({names: "Good unique name, me (2)", unread: false}), get_from_details(message, members(:arun_albers), {})
    assert_equal_hash_without_picture ({names: "Good unique name (2)", unread: false}), get_to_details(message, members(:arun_albers))

    message_2.mark_as_read!(members(:f_mentor))
    assert_equal_hash_without_picture ({names: "me, arun albers (2)", unread: false}), get_from_details(message.reload, members(:f_mentor), {})
    assert_equal_hash_without_picture ({names: "arun albers (2)", unread: false}), get_to_details(message, members(:f_mentor))
    assert_equal_hash_without_picture ({names: "Good unique name, me (2)", unread: false}), get_from_details(message, members(:arun_albers), {})
    assert_equal_hash_without_picture ({names: "Good unique name (2)", unread: false}), get_to_details(message, members(:arun_albers))
  end


  def test_get_from_details_media
    message = create_message(sender: members(:f_mentor), receivers: [members(:arun_albers)])
    message_2 = create_message(sender: members(:arun_albers), receivers: [members(:f_mentor)])
    message_2.update_attribute(:parent_id, message.id)
    output_hash = get_from_details(message, members(:arun_albers), {})
    assert_match /image_with_initial_dimensions_tiny/, output_hash[:pictures].first #Initials
    create_profile_picture(message.sender)
    output_hash = get_from_details(message, members(:arun_albers), {})
    assert_match /test_pic.png.*width="21"/, output_hash[:pictures].first # Actual Picture
    assert_equal 2, output_hash[:pictures].size
    members(:arun_albers).destroy!
    output_hash = get_from_details(message.reload, members(:f_mentor), {})
    assert_equal 2, output_hash[:pictures].size
    assert_match /user_small.jpg.*width="21"/, output_hash[:pictures].last # default picture for deleted user
  end

  def test_get_from_to_details_for_admin_message
    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student), members(:f_mentor)])
    message_2 = create_admin_message(sender: members(:f_student))
    message_3 = create_admin_message(sender: members(:f_mentor))
    message_2.update_attribute(:parent_id, message.id)
    message_3.update_attribute(:parent_id, message.id)
    message.mark_as_read!(members(:f_student))
    message.mark_as_read!(members(:f_mentor))
    assert_equal_hash_without_picture ({names: "me .. <span class=\"h5 font-600 m-b-0 m-t-0 cjs-from-name hidden-lg hidden-md\">Good unique name</span><span class=\"font-600 cjs-from-name hidden-xs hidden-sm\">Good unique name</span> (3)", unread: true}), get_from_details(message.reload, members(:f_admin))
    assert_equal_hash_without_picture ({names: "student example, ... (3)", unread: true}), get_to_details(message, members(:f_admin))
    assert_equal_hash_without_picture ({names: "Freakin Admin (Administrator), me (2)", unread: false}), get_from_details(message, members(:f_mentor))
    assert_equal_hash_without_picture ({names: "Administrator (2)", unread: false}), get_to_details(message, members(:f_mentor))
    assert_equal_hash_without_picture ({names: "Freakin Admin (Administrator), me (2)", unread: false}), get_from_details(message, members(:f_student))
    assert_equal_hash_without_picture ({names: "Administrator (2)", unread: false}), get_to_details(message, members(:f_student))
    assert_equal_hash_without_picture ({names: "Freakin Admin (Administrator) .. <span class=\"h5 font-600 m-b-0 m-t-0 cjs-from-name hidden-lg hidden-md\">Good unique name</span><span class=\"font-600 cjs-from-name hidden-xs hidden-sm\">Good unique name</span> (3)", unread: true}), get_from_details(message, members(:ram))
    assert_equal_hash_without_picture ({names: "student example, ... (3)", unread: true}), get_to_details(message, members(:ram))

    message_2.mark_as_read!(members(:f_admin))
    message_3.mark_as_read!(members(:f_admin))
    assert_equal_hash_without_picture ({names: "me .. Good unique name (3)", unread: false}), get_from_details(message.reload, members(:f_admin))
    assert_equal_hash_without_picture ({names: "student example, ... (3)", unread: false}), get_to_details(message, members(:f_admin))
    assert_equal_hash_without_picture ({names: "Freakin Admin (Administrator) .. Good unique name (3)", unread: false}), get_from_details(message, members(:ram))
  end

  def test_get_from_details_for_auto_email
    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student), members(:f_mentor)], auto_email: true)
    assert_equal_hash_without_picture ({names: _Admin, unread: false}), get_from_details(message, members(:f_admin))
    assert_equal_hash_without_picture ({names: _Admin, unread: false}), get_from_details(message, members(:ram))
    assert_equal_hash_without_picture ({names: "<span class=\"h5 font-600 m-b-0 m-t-0 cjs-from-name hidden-lg hidden-md\">#{_Admin}</span><span class=\"font-600 cjs-from-name hidden-xs hidden-sm\">#{_Admin}</span>", unread: true}), get_from_details(message, members(:f_mentor))
  end

  def test_message_from_to_names
    SecureRandom.stubs(:hex).returns(1)
    message = create_message(sender: members(:f_mentor), receivers: [members(:arun_albers)])
    details = message_from_to_names(message, members(:f_mentor))
    assert_equal "Me", details[:from]
    assert_equal link_to_user(members(:arun_albers)), details[:to]
    details = message_from_to_names(message, members(:arun_albers))
    assert_equal link_to_user(members(:f_mentor)), details[:from]
    assert_equal "me", details[:to]
  end

  def test_message_from_to_names_group_scraps
    SecureRandom.stubs(:hex).returns(1)
    message = create_message(sender: members(:f_mentor), receivers: [members(:arun_albers)])
    details = message_from_to_names(message, members(:f_mentor), :skip_to_names => true)
    assert_equal "Me", details[:from]
    assert_equal "", details[:to]
    details = message_from_to_names(message, members(:arun_albers), :skip_to_names => true, no_hovercard: true)
    set_response_text(details[:from])
    assert_select "a[no_hovercard=\"true\"]", text: "Good unique name"
  end

  def test_message_from_to_names_for_admin_message
    SecureRandom.stubs(:hex).returns(1)
    message = create_admin_message(sender: members(:f_mentor))
    details = message_from_to_names(message, members(:f_admin))
    assert_equal link_to_user(members(:f_mentor)), details[:from]
    assert_equal _Admin, details[:to]
    details = message_from_to_names(message, members(:f_mentor))
    assert_equal "Me", details[:from]
    assert_equal _Admin, details[:to]

    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student), members(:f_mentor)])
    details = message_from_to_names(message, members(:f_admin))
    assert_equal "Me", details[:from]
    assert_equal [link_to_user(members(:f_student)), link_to_user(members(:f_mentor))].to_sentence, details[:to]
    details = message_from_to_names(message, members(:f_mentor))
    assert_equal link_to_user(members(:f_admin)), details[:from]
    assert_equal ["me"].to_sentence, details[:to]
    details = message_from_to_names(message, members(:ram))
    assert_equal link_to_user(members(:f_admin)), details[:from]
    assert_equal [link_to_user(members(:f_student)), link_to_user(members(:f_mentor))].to_sentence, details[:to]
  end

  def test_message_from_to_names_for_user_not_present_in_program
    SecureRandom.stubs(:hex).returns(1)
    message = create_scrap(sender: members(:f_mentor), group: groups(:mygroup))
    details = message_from_to_names(message, members(:mkr_student))
    assert_equal link_to_user(members(:f_mentor)), details[:from]
    assert_equal "me", details[:to]

    Scrap.any_instance.stubs(:sender_user).returns(nil)
    details = message_from_to_names(message, members(:mkr_student))
    assert_equal message.sender.name(:name_only => true), details[:from]
    assert_equal "me", details[:to]
    details = message_from_to_names(message, members(:f_mentor))
    assert_equal "Me", details[:from]
    assert_equal link_to_user(members(:mkr_student)), details[:to]

    details = message_from_to_names(message, members(:mkr_student))
    assert_equal message.sender.name(:name_only => true), details[:from]
    assert_equal "me", details[:to]
    details = message_from_to_names(message, members(:f_mentor))
    assert_equal "Me", details[:from]
    assert_equal link_to_user(members(:mkr_student)), details[:to]

    message.message_receivers.delete_all
    details = message_from_to_names(message, members(:f_mentor))
    assert_equal "Me", details[:from]
    assert_equal "Removed User", details[:to]
  end

  def test_message_from_to_names_to_unloggedin_users
    SecureRandom.stubs(:hex).returns(1)
    message = create_admin_message(sender_name: "UnloggedIn", sender_email: "unloggedin@example.com")
    details = message_from_to_names(message, members(:f_admin))
    assert_equal "UnloggedIn &lt;<a href=\"mailto:unloggedin@example.com\">unloggedin@example.com</a>&gt;", details[:from]
    assert_equal _Admin, details[:to]

    message = create_admin_message(sender: members(:f_admin), receiver_name: "UnloggedIn", receiver_email: "unloggedin@example.com")
    details = message_from_to_names(message, members(:f_admin))
    assert_equal "Me", details[:from]
    assert_equal "UnloggedIn &lt;<a href=\"mailto:unloggedin@example.com\">unloggedin@example.com</a>&gt;", details[:to]
    details = message_from_to_names(message, members(:ram))
    assert_equal link_to_user(members(:f_admin)), details[:from]
    assert_equal "UnloggedIn &lt;<a href=\"mailto:unloggedin@example.com\">unloggedin@example.com</a>&gt;", details[:to]
  end

  def test_show_more_receivers_link
    message = create_admin_message(sender: members(:f_admin), receivers: programs(:org_primary).members.first(11), program: programs(:org_primary))
    content = message_from_to_names(message, members(:f_admin))
    assert_equal "Me", content[:from]
    assert_select_helper_function "script", content[:to], text: "\n//<![CDATA[\nMessages.showMoreReceivers('/abstract_messages/#{message.id}/show_receivers.js', #{message.id});\n//]]>\n"
  end

  def test_display_message_receivers_with_limits
    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_mentor), members(:f_student)], program: programs(:org_primary))
    SecureRandom.stubs(:hex).returns(1)
    mentor_link = link_to_user(members(:f_mentor))
    student_link = link_to_user(members(:f_student))
    # Admin sending a bulk message is equivalent to 'bcc' for end-users.
    assert_equal_unordered [mentor_link], display_message_receivers(message, members(:f_admin), false, 1)
    assert_equal_unordered [mentor_link, student_link], display_message_receivers(message, members(:f_admin), false, 2)
    assert_equal_unordered ["me"], display_message_receivers(message, members(:f_mentor), true, 1)
    assert_equal_unordered ["me"], display_message_receivers(message, members(:f_mentor), true, 2)
    assert_equal_unordered ["me"], display_message_receivers(message, members(:f_student), true, 3)
  end

  def test_display_message_receivers_for_sender_and_receiver_in_different_program
    message = create_admin_message(sender: members(:moderated_admin), receivers: [members(:moderated_student)], program: programs(:moderated_program))

    message_receiver = members(:moderated_student)

    assert_equal ["#{message_receiver.name(:name_only => true)} &lt;<a href=\"mailto:#{message_receiver.email}\">#{message_receiver.email}</a>&gt;"], display_message_receivers(message, members(:f_student), false, 1)
    assert_equal ["me"], display_message_receivers(message, members(:moderated_student), false, 1)
  end

  def test_display_message_receivers_for_scraps_when_sender_and_receiver_in_different_program
    message = create_scrap(sender: members(:f_mentor), group: groups(:mygroup))

    assert_equal [members(:mkr_student).name(:name_only => true)], display_message_receivers(message, members(:moderated_admin), false, 1)
  end

  def test_get_message_path
    message = Message.first
    admin_message = AdminMessage.first
    scrap = Scrap.first
    assert_equal message_path(message, filters_params: {tab: 1}, is_inbox: true), get_message_path(message, true, {tab: 1})
    assert_equal admin_message_path(admin_message, filters_params: {tab: 1}, is_inbox: false, from_inbox: true), get_message_path(admin_message, false, {tab: 1})
    assert_equal scrap_path(scrap, filters_params: {tab: 1}, root: scrap.ref_obj.program.root, is_inbox: true, from_inbox: true), get_message_path(scrap, true, {tab: 1})
  end

  def test_get_reply_path
    message = Message.first
    admin_message = AdminMessage.first
    scrap = Scrap.first
    message_reply = message.build_reply(message.sender)
    admin_message_reply = admin_message.build_reply(admin_message.sender)
    scrap_reply = scrap.build_reply(scrap.sender)
    assert_equal messages_path, get_reply_path(message_reply, true)
    assert_equal admin_messages_path(:root => admin_message_reply.program.root, :from_inbox => true), get_reply_path(admin_message_reply, true)
    assert_equal scraps_path(:from_inbox => true), get_reply_path(scrap_reply, true)
    assert_equal scraps_path(format: :js), get_reply_path(scrap_reply, false)
  end

  def test_display_profile_pic
    message = messages(:first_message)
    assert_equal "<div id=\"\" class=\"image_with_initial inline image_with_initial_dimensions_small profile-picture-cream_and_grey profile-font-styles img-circle m-b-xs\" title=\"Mentor Studenter\">MS</div>", display_profile_pic(message)
    assert_match /image_with_initial_dimensions_tiny/, display_profile_pic(message, :override_size => :tiny)
    assert_no_match /image_with_initial_dimensions_small/, display_profile_pic(message, :override_size => :tiny)
    create_profile_picture(message.sender)

    assert_select_helper_function "img[alt='Test pic']", display_profile_pic(message)
    assert_select_helper_function "img[height='21']", display_profile_pic(message, :size => "21x21")
    assert_select_helper_function "img[width='21']", display_profile_pic(message, :size => "21x21")
  end

  def test_collapsible_message_users_filters
    @messages_presenter = Messages::MessagesPresenter.new(members(:f_admin), programs(:org_primary), search_filters: {sender: 'sender'})
    filter = MessagesFilterService.new({sender: 'sender'})
    content = collapsible_message_users_filters
    assert_match /MessageSearch.initializeMemberFilters/, content
    assert_match /MessageSearch.applyFilters()/, content
    assert_match /\/members\/auto_complete_for_name_or_email\.json/, content
    content = collapsible_message_users_filters(true)
    assert_match /MessageSearch.initializeMemberFilters/, content
    assert_match /MessageSearch.applyFilters()/, content
    assert_select_helper_function_block "div.input-group", content do
      assert_select "input#search_filters_sender.form-control"
    end
  end

  def test_get_message_url_for_notification
    # Message case
    assert_equal "http://primary.#{DEFAULT_HOST_NAME}/messages/#{messages(:first_message).id}?is_inbox=true", AbstractMessagesHelper.get_message_url_for_notification(messages(:first_message), messages(:first_message).program, {host: DEFAULT_HOST_NAME})
    # AdminMessage case
    assert_equal "http://primary.#{DEFAULT_HOST_NAME}/admin_messages/#{messages(:third_admin_message).parent_id}?is_inbox=true", AbstractMessagesHelper.get_message_url_for_notification(messages(:third_admin_message), messages(:third_admin_message).program.organization, {host: DEFAULT_HOST_NAME})
    # Other Message type
    assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/groups/#{groups(:mygroup).id}/scraps", AbstractMessagesHelper.get_message_url_for_notification(messages(:mygroup_mentor_1), messages(:mygroup_mentor_1).program.organization, {host: DEFAULT_HOST_NAME})
    # meeting message case
    message = create_scrap(:group => meetings(:f_mentor_mkr_student))
    assert message.is_meeting_message?
    assert_equal message.ref_obj, meetings(:f_mentor_mkr_student)
    assert_match "http://primary.#{DEFAULT_HOST_NAME}/p/albers/meetings/#{meetings(:f_mentor_mkr_student).id}/scraps?current_occurrence_time=", AbstractMessagesHelper.get_message_url_for_notification(message, message.program.organization, {host: DEFAULT_HOST_NAME})
  end

  def test_preview_leaf_message_in_listing
    message = messages(:first_message)
    message.update_attribute(:content, "<b>help text &nbsp;<b><a href='https://www.chronus.com'> chronus </a>")
    assert_equal "help text   chronus ", preview_leaf_message_in_listing(message)
  end

  def test_get_reply_delete_buttons
    message = messages(:first_message)
    other_options = {}
    reply_path = "jQuery('#new_admin_message_#{message.id }').show();jQuery('#message_content_#{message.id }').focus();jQueryScrollTo('#new_admin_message_#{message.id } form', false)"
    other_options[:reply_action] = reply_path
    other_options[:delete_action] = url_for(message)
    confirmation_message = "common_text.confirmation.sure_to_delete_this".translate(title: "feature.messaging.content.message".translate)

    viewing_member = users(:f_mentor)
    set_response_text(get_reply_delete_buttons(message, viewing_member, {}, other_options))
    assert_select "a.cjs_delete_link"
    assert_select "a.cjs_reply_link"
    assert_select "a[data-click=\"#{reply_path}\"]"
    assert_select "a[href=\"#{url_for(message)}\"]"
    assert_select "a[data-confirm=\"#{confirmation_message}\"]"

    viewing_member = message.sender
    set_response_text(get_reply_delete_buttons(message, viewing_member, {}, other_options))
    assert_select "a.cjs_delete_link", count: 0
    assert_select "a.cjs_reply_link"
  end

  private

  def _Admin
    "Administrator"
  end

  def assert_equal_hash_without_picture(expected_val, actual_val)
    actual_val.delete(:pictures)
    assert_equal_hash expected_val, actual_val
  end
end