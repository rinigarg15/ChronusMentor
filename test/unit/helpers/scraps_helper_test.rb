require_relative './../../test_helper.rb'
require_relative './../../../app/helpers/scraps_helper'

class ScrapsHelperTest < ActionView::TestCase
  def test_get_scrap_reply_delete_buttons
  	scrap = create_scrap(
    	:group => groups(:mygroup),
    	:subject => "hello",
    	:content => "This is a content")

    str = get_scrap_reply_delete_buttons(scrap, scrap.sender)
    assert_match //, str

    set_response_text(get_scrap_reply_delete_buttons(scrap, scrap.receivers.first))

    assert_select "a.cjs_reply_link" do
      assert_select "i.fa-reply"
    end
    assert_select "div" do
      assert_select "a.cjs_delete_link" do
        assert_select "i.fa-trash"
      end
      assert_select "ul.dropdown-menu" do
        assert_select "li" do
          assert_select "a.cjs_delete_link", {:text => "Delete"}
        end
      end
    end
  end

  def test_get_scrap_reply_delete_buttons_delete_only
    scrap = create_scrap(
      :group => groups(:mygroup),
      :subject => "hello",
      :content => "This is a content")

    scrap.expects(:can_be_replied?).returns(false)
    set_response_text(get_scrap_reply_delete_buttons(scrap, scrap.receivers.first))

    assert_select "a.cjs_delete_link" do
      assert_select "i.fa-trash"
    end
  end

  def test_get_scrap_reply_delete_buttons_reply_only
    scrap = create_scrap(
      :group => groups(:mygroup),
      :subject => "hello",
      :content => "This is a content")

    scrap.expects(:can_be_deleted?).returns(false)
    set_response_text(get_scrap_reply_delete_buttons(scrap, scrap.receivers.first))

    assert_select "a.cjs_reply_link" do
      assert_select "i.fa-reply"
    end
  end

  def test_get_scrap_header_content
    self.expects(:wob_member).at_least(0).returns(members(:psg_mentor1))
    scrap = create_scrap(:group => groups(:multi_group), :sender => members(:psg_mentor1))
    scrap2 = create_scrap(:group => groups(:multi_group), :sender => members(:psg_mentor2))
    scrap2.update_attributes(parent_id: scrap.id, root_id: scrap.id)

    # One div and two images
    output = get_scrap_header_content(scrap)
    assert_match /media-collage.*image_with_initial_dimensions_tiny.*image_with_initial_dimensions_tiny/m, output
    assert_no_match /media-collage.*media-collage/m, output

    scrap3 = create_scrap(:group => groups(:multi_group), :sender => members(:psg_student1))
    scrap3.update_attributes(parent_id: scrap.id, root_id: scrap.id)
    scrap4 = create_scrap(:group => groups(:multi_group), :sender => members(:psg_student2))
    scrap4.update_attributes(parent_id: scrap.id, root_id: scrap.id)

    # two divs and four images
    output = get_scrap_header_content(scrap.reload)
    assert_match /media-collage.*image_with_initial_dimensions_tiny.*image_with_initial_dimensions_tiny.*media-collage.*image_with_initial_dimensions_tiny.*image_with_initial_dimensions_tiny/m, output

    scrap5 = create_scrap(:group => groups(:multi_group), :sender => members(:psg_student3))
    scrap5.update_attributes(parent_id: scrap.id, root_id: scrap.id)

    # two divs and 3 images and one metanumber (5) image
    output = get_scrap_header_content(scrap.reload)
    assert_match /media-collage.*image_with_initial_dimensions_tiny.*image_with_initial_dimensions_tiny.*media-collage.*image_with_initial_dimensions_tiny.*fa-stack.*5/m, output
  end

  def test_get_unread_scraps_count_label
    member = members(:f_admin)
    group = groups(:mygroup)
    member.expects(:scrap_inbox_unread_count).with(group).returns(0)
    assert_nil get_unread_scraps_count_label(member, group)

    member.expects(:scrap_inbox_unread_count).twice.with(group).returns(9)
    label_content = get_unread_scraps_count_label(member, group)
    assert_select_helper_function "span.cjs_unread_scraps_count.cui_count_label", label_content, text: "9", count: 1
    assert_select_helper_function "span.pull-right", label_content, count: 0

    label_content = get_unread_scraps_count_label(member, group, true)
    assert_select_helper_function "span.cjs_unread_scraps_count.pull-right", label_content, text: "9", count: 1
    assert_select_helper_function "span.cui_count_label", label_content, text: "9", count: 0

    member.expects(:scrap_inbox_unread_count).never
    label_content = get_unread_scraps_count_label(member, group, true, badge_count: 5)
    assert_select_helper_function "span.cjs_unread_scraps_count.pull-right", label_content, text: "5", count: 1
    assert_select_helper_function "span.cui_count_label", label_content, text: "5", count: 0
  end
end