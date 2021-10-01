require_relative './../../test_helper.rb'

class QaQuestionsHelperTest < ActionView::TestCase
  
  def test_render_community_widget_qa_question_content
    qa_question = qa_questions(:why)
    content = render_community_widget_qa_question_content(qa_question)
    set_response_text(content)

    assert_select "div.clearfix.height-65.overflowy-ellipsis.break-word-all" do
      assert_select "a.btn-link" do
        assert_select "h4.m-b-xs.maxheight-30.overflowy-ellipsis.h5.no-margins.text-info", text: truncate_html(qa_question.summary, max_length: 65)
      end
      assert_select "div.m-t-xs.inline.m-b-sm" do
        assert_select "span.small.text-muted", text: "#{time_ago_in_words(qa_question.updated_at)} ago" do
          assert_select "i.fa-clock-o"
        end
      end
    end
    assert_select "div.height-54.break-word-all.overflowy-ellipsis.p-r-xs", text: qa_question.description
  end
  
end