require_relative './../../test_helper.rb'

class TruncateHelperTest < ActionView::TestCase
  def setup
    super
    helper_setup
  end

  def test_truncate_html_ignores_doc_type
    msg = <<-DOCMSG
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<body bgcolor="#ffffff" text="#000000">
Take this bottle and go fetch me some water please. Another of those mobiles is going bad.
</body>
</html>
DOCMSG
    assert_equal("Take this bottle and go fetch me some...", truncate_html(msg, :max_length => 40))
  end

  def test_truncate_html_with_body_node
    msg = <<-MSG
<html>
<head>
  <meta content="text/html;charset=UTF-8" http-equiv="Content-Type">
  <title></title>
</head>
<body bgcolor="#ffffff" text="#000000">
Dear Mentor,<br>
Vikram is currently setting up his account. The fourth member of our
team is Arun Kumar Arjunan<br>
</body>
</html>
MSG
    assert_equal("Dear Mentor,<br />Vikram is currently...", truncate_html(msg, :max_length => 40, :words => true))
  end

  def test_truncate_html_plain_text
    text = "this is some exmaple test"
    assert_equal("this is...", truncate_html(text, :max_length => 10))
  end

  def test_truncate_html_ordinary_nodes
    text = "<p><b><i>this is some</i> exmaple </b></p> <p>test</p>"
    assert_equal("<p><b><i>this is</i></b></p>...", truncate_html(text, :max_length => 10))
  end
  
  def test_truncate_html_with_html_with_multiple_bodies
    msg = <<-MSG
<html>
<head>
  <meta content="text/html;charset=UTF-8" http-equiv="Content-Type">
  <title></title>
</head>
<body bgcolor="#ffffff" text="#000000">
Dear Mentor,<br>
Vikram is currently setting up his account. The fourth member of our
team is Arun Kumar Arjunan<br>
</body>
</html>

<html>
<head>
  <meta content="text/html;charset=UTF-8" http-equiv="Content-Type">
  <title></title>
</head>
<body bgcolor="#ffffff" text="#000000">
Dear Mentor,<br>
Vikram is currently setting up his account. The fourth member of our
team is Arun Kumar Arjunan<br>
</body>
</html>
MSG
    assert_equal("Dear Mentor,<br />Vikram is currently setti...", truncate_html(msg))
  end
end
