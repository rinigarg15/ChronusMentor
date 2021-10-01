require_relative "./../../test_helper.rb"
require_relative "./../../../app/helpers/admin_messages_helper"

class AdminMessagesHelperTest < ActionView::TestCase
  include AdminMessagesHelper

  def test_render_system_generated_filter
    content = render_system_generated_filter(false)
    assert_match /Include system generated messages/, content
    assert_no_match /checked/, content
    content = render_system_generated_filter(true)
    assert_match /checked/, content
  end

  def test_get_comment_wrapper_options
    s1 = create_scrap(group: groups(:mygroup))
    reply = s1.build_reply(members(:f_mentor))
    self.stubs(:get_reply_path).returns("/reply")
    comment_options = get_comment_wrapper_options(reply)
    assert_equal "parent_id_#{s1.id}", comment_options[:hidden_fields][:parent_id][:id]
    assert_equal "ref_obj_id_#{s1.id}", comment_options[:hidden_fields][:ref_obj_id][:id]
  end
end