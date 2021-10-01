require_relative './../../test_helper.rb'

class PostsHelperTest < ActionView::TestCase
  include FlagsHelper

  def setup
    @topic = create_topic
    super
  end

  def test_get_post_moderation_actions
    post = create_post(topic: @topic, published: false)
    content = get_post_moderation_actions(post, true)
    assert_select_helper_function_block "div.btn-group", content do
      assert_select "a.btn-primary[href='#{moderate_publish_forum_topic_post_path(@topic.forum, @topic, post, publish: true)}']", text: "Publish"
      assert_select "ul.dropdown-menu" do
        assert_select "li", count: 1
        assert_select "li" do
          assert_select "a[data-click]", text: "Decline"
        end
      end
    end

    content = get_post_moderation_actions(post, false, btn_class: "test_btn_class", responsive_primary_btn_class: "col-xs-10", responsive_caret_class: "col-xs-2")
    assert_select_helper_function_block "div.btn-group.test_btn_class", content do
      assert_select "a.col-xs-10.btn-primary[href='#{moderate_publish_forum_topic_post_path(@topic.forum, @topic, post, publish: true)}']", text: "Publish"
      assert_select "a.col-xs-2[data-toggle='dropdown']"
      assert_select "ul.dropdown-menu" do
        assert_select "li", count: 1
        assert_select "li" do
          assert_select "a[data-click]", text: "Decline"
        end
      end
    end

    post.update_attribute(:published, true)
    assert_nil get_post_moderation_actions(post, true)
  end

  def test_get_actions_for_published_post
    user_1 = users(:f_mentor)
    user_2 = users(:f_student)
    post = create_post(topic: @topic, published: false, user: user_1)

    self.expects(:current_user).at_least(0).returns(user_2)
    self.expects(:current_program).at_least(0).returns(post.program)
    assert_nil get_actions_for_published_post(post)

    post.update_attributes(published: true)
    post.stubs(:can_be_deleted?).returns(false)
    Forum.any_instance.stubs(:allow_flagging?).returns(false)
    assert_equal "", get_actions_for_published_post(post)

    post.stubs(:can_be_deleted?).returns(true)
    content = get_actions_for_published_post(post, btn_class: "test_btn_class", dropdown_title: "", is_not_primary: true, btn_group_btn_class: "test_btn_group_btn_class")
    assert_select_helper_function_block "div.btn-group.test_btn_class", content do
      assert_select "a.test_btn_group_btn_class[data-toggle='dropdown']"
      assert_select "ul.dropdown-menu" do
        assert_select "li", count: 1
        assert_select "li" do
          assert_select "a[data-confirm='Are you sure you want to delete this post?'][data-ajax-url='#{forum_topic_post_path(@topic.forum, @topic, post)}'][data-ajax-method='delete']", text: "Delete"
        end
      end
    end
    assert_no_match(/btn-primary/, content)
    assert_no_match(/Report Content/, content)

    Forum.any_instance.stubs(:allow_flagging?).returns(true)
    content = get_actions_for_published_post(post, btn_class: "test_btn_class", dropdown_title: "", is_not_primary: true, btn_group_btn_class: "test_btn_group_btn_class")
    assert_select_helper_function_block "div.btn-group.test_btn_class", content do
      assert_select "a.test_btn_group_btn_class[data-toggle='dropdown']"
      assert_select "ul.dropdown-menu" do
        assert_select "li", count: 2
        assert_select "li" do
          assert_select "a[data-confirm='Are you sure you want to delete this post?'][data-ajax-url='#{forum_topic_post_path(@topic.forum, @topic, post)}'][data-ajax-method='delete']", text: "Delete"
          assert_select "a", text: "Report Content"
        end
      end
    end
  end

  def test_formatted_post_body
    post = create_post(topic: @topic, body: "Text with <br/> <b> link http://www.link.com</b>")
    assert_equal "Text with   link http://www.link.com", formatted_post_body(post)

    post.update_column(:body, "Simple\ntext")
    assert_equal "Simple<br/>text", formatted_post_body(post)

    post.update_column(:body, "simple text<script>'random script'</script>")
    assert_equal "simple text", formatted_post_body(post)
  end

  def test_post_html_id
    post = create_post(topic: @topic)
    assert_equal "post_#{post.id}", post_html_id(post)
  end

  def test_post_modal_id
    assert_equal "cjs_new_post_modal", post_modal_id
  end

  def test_post_comments_container_id
    post = create_post(topic: @topic)
    assert_equal "cjs_post_comments_#{post.id}", post_comments_container_id(post)
  end

  def test_new_post_action
    @topic.stubs(:can_be_accessed_by?).returns(false)
    assert_nil new_post_action(@topic)

    @topic.stubs(:can_be_accessed_by?).returns(true)
    assert_equal_hash( {
      url: "javascript:void(0)",
      data: {
        toggle: "modal",
        target: "#cjs_new_post_modal"
      },
      icon_class: "fa fa-comment",
      sr_text: "Reply to this conversation"
    }, new_post_action(@topic, true))

    content = new_post_action(@topic, false, class: "test_new_post_action")
    assert_select_helper_function "a.test_new_post_action[data-toggle='modal'][data-target='#cjs_new_post_modal']", content, text: "Reply to this conversation"
  end

  def test_post_comments_container
    self.expects(:current_program).at_least(0).returns(programs(:albers))
    self.expects(:current_user).at_least(0).returns(users(:f_admin))

    post = create_post(topic: @topic, published: false)
    assert_nil post_comments_container(post)

    options = {
      comment_partial: "topics/post_content",
      comment_partial_key: :post,
      comment_partial_locals: { is_root: false },
      no_bottom_padding: true
    }
    self.expects(:build_comments_list).with([], false, options).once
    post.update_attribute(:published, true)
    post_comments_container(post, true)

    create_post(topic: @topic, ancestry: post.id)
    create_post(topic: @topic, ancestry: post.id, published: false)
    self.expects(:build_comments_list).with(post.children, false, options).once
    self.expects(:view_all_comments_label).with(2, 1).once.returns("View all 2 comments (1 unmoderated)")
    post_comments_container(post, true)

    options.merge!(
      no_bottom_padding: false,
      new_comment_partial: "topics/post_reply_form",
      new_comment_partial_locals: { root: post },
      container_id: "cjs_post_comments_#{post.id}",
      view_all_options: {
        label: "View all 2 comments (1 unmoderated)",
        url: fetch_all_comments_forum_topic_path(@topic, forum_id: @topic.forum_id, root_id: post.id)
      }
    )
    self.expects(:comments_container).with(post.children, options).once
    post_comments_container(post)

    self.expects(:current_user).at_least(0).returns(users(:f_mentor))
    self.expects(:view_all_comments_label).with(1, 0).once.returns("View all 1 comments")
    post.stubs(:can_be_accessed_by?).returns(false)
    options[:new_comment_partial] = nil
    options[:new_comment_partial_locals] = nil
    options[:view_all_options][:label] = "View all 1 comments"
    self.expects(:comments_container).with(post.children.published, options).once
    post_comments_container(post)
  end

  def test_view_all_comments_label
    content = view_all_comments_label(100, 0)
    assert_select_helper_function "span", content, count: 1
    assert_select_helper_function "span", content, text: "View all 100 comments"

    content = view_all_comments_label(100, 10)
    assert_select_helper_function "span", content, count: 2
    assert_select_helper_function "span", content, text: "View all 100 comments"
    assert_select_helper_function "span.text-danger", content, text: "(10 unmoderated)"
  end
end