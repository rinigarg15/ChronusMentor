require_relative './../../test_helper.rb'

class ChronusSanitizationTest < ActionView::TestCase
  include ChronusSanitization

  def test_chronus_sanitize_with_version_v1
    assert chronus_sanitize("Hello <script>test</script>", sanitization_version: "v1").html_safe?
    assert_equal chronus_sanitize("Hello <script>test</script>", sanitization_version: "v1"), "Hello <script>test</script>"
  end

  def test_chronus_sanitize_with_version_v2
    assert chronus_sanitize("Hello <script>test</script>", sanitization_version: "v2").html_safe?
    assert_equal chronus_sanitize("Hello <script>test</script>", sanitization_version: "v2"), "Hello test"
  end

  def test_chronus_sanitize_while_render_with_version_v1
    assert chronus_sanitize_while_render("Hello <script>test</script>", sanitization_version: "v1").html_safe?
    assert_equal chronus_sanitize_while_render("Hello <script>test</script>", sanitization_version: "v1"), "Hello test"
    assert_equal chronus_sanitize_while_render("Hello <div>test</div>", :sanitization_options => {:tags => ["div"]}, sanitization_version: "v1"), "Hello <div>test</div>"
  end

  def test_chronus_sanitize_while_render_with_version_v2
    assert chronus_sanitize_while_render("Hello <script>test</script>", sanitization_version: "v2").html_safe?
    assert_equal chronus_sanitize_while_render("Hello <script>test</script>", sanitization_version: "v2"), "Hello <script>test</script>"
    assert_equal chronus_sanitize_while_render("Hello <script>test</script>", :sanitization_options => {:tags => "script"}, sanitization_version: "v2"), "Hello <script>test</script>"
  end

  def test_to_sentence_sanitize
    assert to_sentence_sanitize(["Hello <script>test1</script>", "test2"]).html_safe?
    assert_equal "Hello &lt;script&gt;alert(&quot;test&quot;)&lt;/script&gt; and test2", to_sentence_sanitize(["Hello <script>alert(\"test\")</script>", "test2"])
  end

  def test_get_safe_string
    assert get_safe_string.html_safe?
    assert_equal get_safe_string("<br/>"), "<br/>"
    assert_equal get_safe_string("<"), "<"
    assert_raise(RuntimeError) do
      get_safe_string("<div>Hello</div>")
    end
  end

  def test_chr_json_escape
    assert chr_json_escape("<br/>"), "<br\\/>"
    assert chr_json_escape("<script>alert(1)</script>"), "<script>alert(1)<\\/script>"
  end

  def test_highchart_string_sanitize
    assert highchart_string_sanitize("<script>alert('My' + \"& test\")</script>").html_safe?
    assert_equal "&lt;script&gt;alert(\\'My\\' + \\\"\\& test\\\")&lt;/script&gt;", highchart_string_sanitize("<script>alert('My' + \"& test\")</script>")
  end

  def test_chronus_format_text_area
    assert_equal "not formatted \n<br /> text", chronus_format_text_area("not formatted \n text")
  end

  def test_chronus_auto_link
    assert_equal "not formatted \n<br /> text", chronus_auto_link("not formatted \n text")
    set_response_text(chronus_auto_link("https://www.google.com not formatted \n text"))
    assert_select "a[href='https://www.google.com']", text: "https://www.google.com"
    set_response_text(chronus_auto_link("https://www.google.com not formatted \n text", skip_text_formatting: true))
    assert_select "a[href='https://www.google.com']", text: "https://www.google.com"
  end
end
