require_relative './../../test_helper.rb'

class CommentsHelperTest < ActionView::TestCase

  def test_comments_container
    content = comments_container((1..10).to_a, comments_container_options)
    assert_select_helper_function_block "div.cjs_comments_container#custom_comments_container", content do
      assert_select "a.cjs_view_less_comments_link.hide", text: "View less comments"
      assert_select "a.cjs_view_all_comments_link", text: "View all comments" do
        assert_select "span.cjs_view_all_comments_label"
      end
      assert_no_select "div.p-m"
      assert_no_select "div.cjs_all_comments"
      assert_select "div.cjs_less_comments.p-l-m.p-r-m.p-t-m" do
        assert_select "span", text: "Rendering comment", count: 5
      end
      assert_select "span", text: "Rendering new_comment", count: 1
    end

    content = comments_container((1..3).to_a, comments_container_options)
    assert_select_helper_function_block "div.cjs_comments_container#custom_comments_container", content do
      assert_no_select "a.cjs_view_all_comments_link"
      assert_no_select "a.cjs_view_less_comments_link"
      assert_no_select "div.p-m"
      assert_no_select "div.cjs_less_comments"
      assert_select "div.cjs_all_comments.p-l-m.p-r-m.p-t-m" do
        assert_select "span", text: "Rendering comment", count: 3
      end
      assert_select "span", text: "Rendering new_comment", count: 1
    end

    options = comments_container_options
    options[:new_comment_partial] = nil
    options[:no_bottom_padding] = false
    content = comments_container((1..3).to_a, options)
    assert_select_helper_function_block "div.cjs_comments_container#custom_comments_container", content do
      assert_no_select "a.cjs_view_all_comments_link"
      assert_no_select "a.cjs_view_less_comments_link"
      assert_no_select "div.cjs_less_comments"
      assert_select "div.p-m.cjs_all_comments" do
        assert_select "span", text: "Rendering comment", count: 3
      end
      assert_no_select "span", text: "Rendering new_comment"
    end
  end

  def test_build_comments_list
    options = comments_container_options.pick(:comment_partial, :comment_partial_key, :comment_partial_locals, :new_comment_partial, :no_bottom_padding)
    content = build_comments_list((1..3).to_a, false, options)
    assert_select_helper_function_block "div.p-l-m.p-r-m.p-t-m.cjs_all_comments", content do
      assert_select "span", text: "Rendering comment", count: 3
    end

    options = comments_container_options.pick(:comment_partial, :comment_partial_key, :comment_partial_locals)
    content = build_comments_list((1..5).to_a, true, options)
    assert_select_helper_function_block "div.cjs_less_comments.p-m", content do
      assert_select "span", text: "Rendering comment", count: 5
    end
  end

  private

  def render(options)
    return "<span>Rendering #{options[:partial]}</span>".html_safe
  end

  def comments_container_options
    return {
      comment_partial: "comment",
      comment_partial_key: :comment,
      comment_partial_locals: {},
      no_bottom_padding: true,
      new_comment_partial: "new_comment",
      new_comment_partial_locals: {},
      container_id: "custom_comments_container",
      view_all_options: {
        label: "View all comments",
        url: "javascript:void(0)",
        additional_class: "cjs_additional_class"
      }
    }
  end
end