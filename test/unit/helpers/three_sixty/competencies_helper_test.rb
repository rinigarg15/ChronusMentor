require_relative './../../../test_helper.rb'
class ThreeSixty::CompetenciesHelperTest < ActionView::TestCase

  def test_display_three_sixty_competency_description
    assert_nil display_three_sixty_competency_description(three_sixty_competencies(:leadership))
    three_sixty_competencies(:leadership).description = "Some text"

    assert_equal "<script>\n//<![CDATA[\njQuery(\"#competency_heading_title_#{three_sixty_competencies(:leadership).id}\").tooltip({html: true, title: '<div>Some text</div>', placement: \"top\", container: \"#competency_heading_title_#{three_sixty_competencies(:leadership).id}\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\"#competency_heading_title_#{three_sixty_competencies(:leadership).id}\").on(\"remove\", function () {jQuery(\"#competency_heading_title_#{three_sixty_competencies(:leadership).id} .tooltip\").hide().remove();})\n//]]>\n</script>", display_three_sixty_competency_description(three_sixty_competencies(:leadership))
  end

  def test_three_sixty_competency_heading_for_listing
    self.stubs(:display_three_sixty_competency_description).at_least(2).returns("some text")
    html_content = to_html(three_sixty_competency_heading_for_listing(three_sixty_competencies(:leadership), true))
    assert_select html_content, "div#competency_heading_for_listing_#{three_sixty_competencies(:leadership).id}"
    assert_select html_content, "big#competency_heading_title_#{three_sixty_competencies(:leadership).id}", :text => "Leadershipsome text"
    assert_select html_content, "a", :count => 2

    html_content = to_html(three_sixty_competency_heading_for_listing(three_sixty_competencies(:leadership), false))
    assert_select html_content, "div#competency_heading_for_listing_#{three_sixty_competencies(:leadership).id}"
    assert_select html_content, "big#competency_heading_title_#{three_sixty_competencies(:leadership).id}", :text => "Leadershipsome text"
    assert_select html_content, "a", :count => 0
  end

  def test_add_new_three_sixty_competency_questions
    self.stubs(:display_three_sixty_question_new_inline).at_least(1).returns(content_tag(:div, ""))
    html_content = to_html(add_new_three_sixty_competency_questions(three_sixty_competencies(:leadership)))
    assert_select html_content, "div#add_new_three_sixty_competency_container_#{three_sixty_competencies(:leadership).id}", :count => 1
  end

  def test_display_three_sixty_question_new_inline
    options_hash = display_three_sixty_question_new_inline(three_sixty_questions(:leadership_1), three_sixty_competencies(:leadership), false)
    assert_equal "/three_sixty/questions/#{three_sixty_questions(:leadership_1).id}.js", options_hash[:url]
    assert_equal :patch, options_hash[:method]
    assert_equal "new_three_sixty_question_#{three_sixty_competencies(:leadership).id}_#{three_sixty_questions(:leadership_1).id}", options_hash[:html][:id]

    options_hash = display_three_sixty_question_new_inline(three_sixty_competencies(:leadership).questions.new, three_sixty_competencies(:leadership))
    assert_equal "/three_sixty/questions.js", options_hash[:url]
    assert_equal :post, options_hash[:method]
    assert_equal "new_three_sixty_question_#{three_sixty_competencies(:leadership).id}_", options_hash[:html][:id]
  end

  private

  def simple_form_for(obj, options, &block)
    options
  end
end
