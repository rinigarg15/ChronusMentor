require_relative './../../test_helper.rb'

class EsDocumentCountCheckerTest < ActiveSupport::TestCase

  def test_check_and_fix_document_counts
    reindex_documents(deleted: Location.reliable.to_a)
    index_name = Location.index_name

    assert_equal ["Location"], EsDocumentCountChecker.check_and_fix_document_counts({"Location" => index_name}, {count_only: true, for_deployment: true})

    e = assert_raise RuntimeError do
      EsDocumentCountChecker.check_and_fix_document_counts({"Location" => index_name})
    end
    assert_equal "Elasticsearch Document count mismatch is found for Location: #{Location.reliable.count}", e.message
    EsDocumentCountChecker.expects(:check_mismatch_after_delta_exclusion).with(Location, "reliable").returns(false)
    assert_empty EsDocumentCountChecker.check_and_fix_document_counts({"Location" => index_name}, {count_only: true, for_deployment: true, new_index_list: [index_name]})
    reindex_documents(created: Location.reliable.to_a)
    index_name = Location.index_name
    assert_empty EsDocumentCountChecker.check_and_fix_document_counts({"Location" => index_name})
  end
end