require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/flags_helper"

class FlagsHelperTest < ActionView::TestCase

  def setup
    super
    @content_owner_user = users(:f_admin)
    @flagger = users(:f_mentor)
    @program = programs(:albers)
    @organization = @program.organization
    @current_organization = @organization
    @article = articles(:economy)
    @article_flag = create_flag(content: @article, user: @flagger)
  end

  def test_popup_link_to_flag_content_nil_cases
    self.expects(:current_program).at_least(0).returns(nil)
    assert_equal "", popup_link_to_flag_content(@article)

    @program.enable_feature(FeatureName::FLAGGING, false)
    self.expects(:current_program).at_least(0).returns(@program)
    assert_equal "", popup_link_to_flag_content(@article)

    @program.enable_feature(FeatureName::FLAGGING, true)
    self.expects(:current_program).at_least(0).returns(@program)
    @article.update_attribute(:author_id, members(:f_mentor).id)
    self.expects(:current_user).at_least(0).returns(users(:f_mentor))
    assert_equal "", popup_link_to_flag_content(@article)
  end

  def test_popup_link_to_flag_content_grey_flag
    self.expects(:current_program).at_least(0).returns(@program)
    self.expects(:current_user).at_least(0).returns(users(:f_student))
    @current_organization.expects(:flagging_enabled?).at_least(0).returns(true)
    link = popup_link_to_flag_content(@article)
    assert_match /grey_flag/, link
    assert_match /Report Content/, link
    assert_match /\/flags\/new\?content_id=#{@article.id}\&amp\;content_type=Article/, link

    link = popup_link_to_flag_content(@article, get_hash: true)
    assert_equal "<i class=\"fa fa-flag  fa-fw m-r-xs\"></i><span class=\"\">Report Content</span>", link[:label]
    assert_equal "jQueryShowQtip('#centered_content', 600, '/flags/new?content_id=#{@article.id}&content_type=Article', '', {draggable: true , modal: true});", link[:js]
    assert_equal "cjs_grey_flag ", link[:class]
  end

  def test_popup_link_to_flag_content_red_flag_non_admin
    self.expects(:current_program).at_least(0).returns(@program)
    self.expects(:current_user).at_least(0).returns(@flagger)
    @current_organization.expects(:flagging_enabled?).at_least(0).returns(true)
    link = popup_link_to_flag_content(@article)
    assert_match /red_flag/, link
    assert_match /Reported/, link
    assert_match /href=\"javascript:void\(0\)\"/, link

    link = popup_link_to_flag_content(@article, get_hash: true)
    assert_equal "<i class=\"fa fa-flag text-danger  fa-fw m-r-xs\"></i><span class=\"\">Reported</span>", link[:label]
    assert_equal "javascript:void(0)", link[:js]
    assert_equal"cjs_red_flag btn-link disabled ", link[:class]
  end

  def test_popup_link_to_flag_content_red_flag_admin
    self.expects(:current_program).at_least(0).returns(@program)
    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    @current_organization.expects(:flagging_enabled?).at_least(0).returns(true)
    link = popup_link_to_flag_content(@article)
    assert_match /red_flag/, link
    assert_match /Resolve/, link
    assert_match /\/flags\/content_related\?content_id\=#{@article.id}\&amp\;content_type=Article/, link

    link = popup_link_to_flag_content(@article, get_hash: true, label_name_class: "labelclass")
    assert_equal "<i class=\"fa fa-flag text-danger  fa-fw m-r-xs\"></i><span class=\"labelclass\">Resolve</span>", link[:label]
    assert_equal "jQueryShowQtip('#centered_content', 600, '/flags/content_related?content_id=#{@article.id}&content_type=Article', '', {modal: true, draggable: true});", link[:js]
    assert_equal"cjs_red_flag ", link[:class]
  end

  def test_flag_status_text
    flag = create_flag
    mapped_data = [[Flag::Status::UNRESOLVED, 'Unresolved'], [Flag::Status::DELETED, 'Deleted'], [Flag::Status::EDITED, 'Edited'], [Flag::Status::ALLOWED, 'Allowed']]
    mapped_data.each do |data|
      flag.status = data[0]
      assert_equal data[1], flag_status_text(flag)
    end
  end

  def test_flag_content_preview
    self.expects(:current_program).at_least(0).returns(@program)
    preview = flag_content_preview(@article_flag)
    assert_match /#{@article.title}/, preview
    assert_match /Freakin Admin \(Administrator\)/, preview
  end

  def test_flag_actions
    actions = flag_actions(@article_flag)
    assert actions.match(/Delete/)
    assert actions.match(/Ignore/)
  end
end