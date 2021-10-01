require_relative './../../test_helper'

class AppDocumentTest < ActiveSupport::TestCase
  def test_validations
    document = ChronusDocs::AppDocument.new
    document.save
    assert_equal ["can't be blank"], document.errors[:title]
    assert_equal ["can't be blank"], document.errors[:description]
  end

end
