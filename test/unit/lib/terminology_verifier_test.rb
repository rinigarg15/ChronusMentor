require_relative './../../test_helper.rb'
require_relative './../../../lib/ChronusTerminologyVerifier/terminology_verifier.rb'

class TerminologyVerifierTest < ActiveSupport::TestCase

  def test_catch_terms_not_customized_good_yaml
    assert_equal ({}), MissingCustomTerms.catch_terms_not_customized("/test/fixtures/files/terminology_testfiles/good_yaml/*.en.yaml")
  end

  def test_catch_terms_not_customized_bad_yaml
    result_hash = MissingCustomTerms.catch_terms_not_customized("/test/fixtures/files/terminology_testfiles/bad_yaml/*.en.yaml")
    result_hash.each do |key, value|
      if key.end_with?("test_1.en.yaml")
        assert_equal value["en.feature.group.action.help_text"], "You have selected a mentor request."
        assert_equal value["en.feature.group.action.mentoring_session"], "Mentoring Session"
        assert_equal value["en.feature.group.action.show_past_meetings"], "Show Past Meeting ()"
        assert_equal value["en.feature.group.content.create_success_v1_html"], "The  has been successfully published.  to view the resource."
        assert_equal value["en.feature.group.content.request_meeting_v2_html"], "Requesting Meeting &raquo;"
        assert_equal value["en.feature.group.label.select_all"], "Select all mentoring connections to perform an action"
        assert_nil value["en.feature.group.content.request_meeting_html"]
      else
        assert_equal value["en.feature.group.action.mentoring_area"], "Mentoring Session"
        assert_equal value["en.feature.group.content.mentoring_area"], "Mentoring Session"
        assert_nil key["en.feature.group.action.a_mentee_name"]
      end
    end
  end

end
