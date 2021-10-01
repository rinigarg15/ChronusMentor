require_relative './../../../test_helper.rb'

class MailGemOverridesTest < ActiveSupport::TestCase
  def test_mail_gem_transfer_encoding_overrides
    mail = Mail.new
    mail.charset = "UTF-8"
    mail.body = "a" * 999
    assert_match /Content-Transfer-Encoding: quoted-printable/, mail.to_s
    assert_no_match(/7bit/, mail.to_s)

    mail = Mail.new
    mail.charset = "UTF-8"
    mail.body = "a"
    assert_match /Content-Transfer-Encoding: 7bit/, mail.to_s
    assert_no_match(/quoted-printable/, mail.to_s)
  end
end