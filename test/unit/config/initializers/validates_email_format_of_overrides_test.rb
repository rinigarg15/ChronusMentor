require_relative './../../../test_helper.rb'

class ValidatesEmailFormatOfOverridesTest < ActiveSupport::TestCase
  def test_caching
    ValidatesEmailFormatOf.stubs(:email_domain_validity_cache).returns({"gmail.com" => false, "somethingthatdoesntexist10001.com" => true})
    assert ValidatesEmailFormatOf::validate_email_format("test@somethingthatdoesntexist10001.com", check_mx: true).nil?
    assert_false ValidatesEmailFormatOf::validate_email_format("test@gmail.com", check_mx: true).nil?

    assert_false ValidatesEmailFormatOf::validate_email_format("test@somethingthatdoesntexist10002.com", check_mx: true).nil?
    assert ValidatesEmailFormatOf::validate_email_format("test@chronus.com", check_mx: true).nil?

    assert_false ValidatesEmailFormatOf.email_domain_validity_cache["somethingthatdoesntexist10002.com"]
    assert ValidatesEmailFormatOf.email_domain_validity_cache["chronus.com"]

    assert_nil ValidatesEmailFormatOf.email_domain_validity_cache["anythingnotlookedup.com"]
  end
end