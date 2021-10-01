require_relative './../../test_helper.rb'

class SanitizationsHelperTest < ActionView::TestCase

  def test_format_insecure_content
    original_content = "Hello <script>alert(test)</script>"
    sanitized_content = "Hello "
    assert format_insecure_content(original_content, sanitized_content).html_safe?
    assert_match /diff/, format_insecure_content(original_content, sanitized_content)
    assert_match /del/, format_insecure_content(original_content, sanitized_content)
    assert_match /&lt;script&gt;alert\(test\)&lt;\/script&gt;/, format_insecure_content(original_content, sanitized_content)
  end

end