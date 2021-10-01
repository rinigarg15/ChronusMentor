require_relative '../test_helper'

class MatchingDocumentTest < ActiveSupport::TestCase
  def test_matching_document
    matching_document = MatchingDocument.new
    assert_false matching_document.valid?
    assert_equal ["can't be blank"], matching_document.errors.messages[:program_id]
    assert_equal ["can't be blank"], matching_document.errors.messages[:record_id]

    program = Program.first
    user = program.users.last
    matching_document.program_id = program.id
    matching_document.record_id = user.id
    assert matching_document.valid?

    matching_document.save!
    doc_id = matching_document.id

    assert_equal true, matching_document.data_fields_by_name.empty?
    assert_equal 0, matching_document.hit_count
    assert_equal 0, matching_document.score
    assert_equal false, matching_document.not_match

    data_field = { "a" => 2, "b" => [3, false] }
    matching_document.data_fields = data_field
    matching_document.save!
    assert_equal data_field, MatchingDocument.where(:id => doc_id).first.data_fields

    assert_false User.first.matching_documents.nil?
    assert_false Program.first.matching_documents.nil?
  end
end