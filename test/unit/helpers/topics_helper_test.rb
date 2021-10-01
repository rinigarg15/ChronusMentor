require_relative './../../test_helper.rb'

class TopicsHelperTest < ActionView::TestCase

  def test_get_topic_actions
    user_1 = users(:f_mentor)
    user_2 = users(:f_student)
    topic = create_topic(user: user_1)

    self.expects(:current_user).at_least(0).returns(user_2)
    assert_equal "", get_topic_actions(topic)

    self.expects(:current_user).at_least(0).returns(user_1)
    content = get_topic_actions(topic, btn_class: "test_btn_class", dropdown_title: "", is_not_primary: true, btn_group_btn_class: "test_btn_group_btn_class")
    assert_select_helper_function_block "div.btn-group.test_btn_class", content do
      assert_select "a.btn.test_btn_group_btn_class[data-toggle='dropdown']"
      assert_select "ul.dropdown-menu" do
        assert_select "li", count: 1 do
          assert_select "a[data-method='delete'][data-confirm='Are you sure you want to delete this conversation?'][href='#{forum_topic_path(topic.forum, topic)}']", text: "Delete"
        end
      end
    end
  end

  def test_formatted_topic_body
    @current_organization = programs(:org_primary)
    topic = create_topic(body: "Text with <br/> <b> link http://www.link.com</b>")
    assert_equal "Text with <br/> <b> link http://www.link.com</b>", formatted_topic_body(topic)

    topic.update_column(:body, "Simple text")
    assert_equal "Simple text", formatted_topic_body(topic)

    topic.update_column(:body, "simple text<script>'random script'</script>")
    assert_equal "simple text<script>'random script'</script>", formatted_topic_body(topic)

    SecuritySetting.any_instance.stubs(:sanitization_version).returns("v1")
    assert_equal "simple text'random script'", formatted_topic_body(topic)
  end

  def test_topic_modal_id
    assert_equal "cjs_new_topic_modal", topic_modal_id("")
  end

  def test_new_topic_action
    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    forum = forums(:common_forum)
    forum.stubs(:can_be_accessed_by?).returns(false)
    assert_nil new_topic_action(forum)

    forum.stubs(:can_be_accessed_by?).returns(true)
    assert_equal_hash( {
      url: "javascript:void(0)",
      data: {
        toggle: "modal",
        target:"#cjs_new_topic_modal"
      },
      label: "<i class=\"fa fa-comment fa-fw m-r-xs\"></i>Start a Conversation"
    }, new_topic_action(forum))


    assert_equal_hash( {
      url: "javascript:void(0)",
      data: {
        toggle: "modal",
        target:"#cjs_new_topic_modal"
      },
      icon_class: "fa fa-plus m-t-xs",
      sr_text: "Start a Conversation"
    }, new_topic_action(forum, true))

    content = new_topic_action(forum, false, true, class: "test_new_topic_action")
    assert_select_helper_function "a[class='test_new_topic_action'][data-toggle='modal'][data-target='#cjs_new_topic_modal']", content, text: "Start a Conversation"
    
    content = new_topic_action(forum, false, true, class: "test_new_topic_action", id: "21")
    assert_select_helper_function "a[class='test_new_topic_action'][data-toggle='modal'][data-target='#cjs_new_topic_modal_21']", content, text: "Start a Conversation"
  end

  def test_topic_link
    topic = create_topic(title: "New Topic")
    assert_select_helper_function "a[href='#{forum_topic_path(topic.forum, topic)}']", topic_link(topic), text: "New Topic"
    assert_select_helper_function "a[data-ajax-url='#{forum_topic_path(topic.forum, topic)}']", topic_link(topic, true), text: "New Topic"
    assert_select_helper_function "a[data-ajax-url='#{forum_topic_path(topic.forum, topic)}'][data-show-title='true']", topic_link(topic, true, show_title: true), text: "New Topic"
    assert_select_helper_function "a[href='#{forum_topic_path(topic.forum, topic)}'][class='test_topic_link']", topic_link(topic, false, class: "test_topic_link"), text: "New Topic"
  end

  def test_render_community_widget_topic_content
    topic = create_topic(title: "New Topic", body: "sample topic content")
    content = render_community_widget_topic_content(topic)
    set_response_text(content)

    assert_select "div.clearfix.height-65.overflowy-ellipsis.break-word-all" do
      assert_select "a.btn-link" do
        assert_select "h4.m-b-xs.maxheight-30.overflowy-ellipsis.h5.no-margins.text-info", text: truncate_html(topic.title, max_length: 65)
      end
      assert_select "div.m-t-xs.inline.m-b-sm" do
        assert_select "span.small.text-muted", text: "#{time_ago_in_words(topic.updated_at)} ago" do
          assert_select "i.fa-clock-o"
        end
      end
    end
    assert_select "div.height-54.break-word-all.overflowy-ellipsis.p-r-xs", text: "sample topic content"
  end

  def test_follow_topic_link
    user_1 = users(:f_student)
    user_2 = users(:f_mentor)
    topic = create_topic(user: user_1)

    self.expects(:current_user).at_least(0).returns(user_1)
    assert_equal_hash( {
      url: "javascript:void(0)",
      label: "<i class=\"fa fa-check fa-fw m-r-xs\"></i>Following",
      class: "cjs_follow_topic_link_#{topic.id} btn btn-primary",
      data: {
        ajax_url: follow_forum_topic_path(topic.forum, topic, subscribe: false, from_topics_listing: false),
        ajax_method: "post",
        ajax_hide_loader: true
      }
    }, follow_topic_link(topic))

    self.expects(:current_user).at_least(0).returns(user_2)
    content = follow_topic_link(topic, true, true)
    assert_select_options = {
      text: "Follow",
      class: "cjs_follow_topic_link_#{topic.id} btn btn-sm btn-white noshadow",
      "data-ajax-url" => follow_forum_topic_path(topic.forum, topic, subscribe: true, from_topics_listing: true),
      "data-ajax-method" => "post",
      "data-ajax-hide-loader" => "true"
    }
    assert_select_helper_function_block "a", content, assert_select_options do
      assert_select "i.fa-plus-square"
    end
  end

  def test_display_group_topic_follow_icon
    user = users(:f_mentor)
    self.expects(:current_user).at_least(0).returns(user)
    topic = create_topic(user: user)
    content = display_group_topic_follow_icon(topic)
    assert_select_helper_function_block "span.cjs_group_topic_follow_icon", content do
      assert_select "i.fa-check-circle", "data-title" => "Following", "data-toggle" => "tooltip"
    end

    topic.unsubscribe_user(user)
    content = display_group_topic_follow_icon(topic)
    assert_select_helper_function_block "span.cjs_group_topic_follow_icon", content do
      assert_no_select "i"
    end
  end
end