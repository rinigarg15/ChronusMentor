require_relative './../../test_helper.rb'

class DefaultUrlsHelperTest < ActionView::TestCase

  def test_default_url_params
    assert_equal_hash( {
      host: DEFAULT_HOST_NAME,
      subdomain: SECURE_SUBDOMAIN,
      SID_PARAM_NAME => "1234",
      protocol: "http"
    }, default_url_params)

    Rails.application.config.stubs(:force_ssl).returns(true)

    assert_equal_hash( {
      host: DEFAULT_HOST_NAME,
      subdomain: SECURE_SUBDOMAIN,
      SID_PARAM_NAME => "1234",
      protocol: "https"
    }, default_url_params)
  end

  private

  def request
    OpenStruct.new(session_options: { id: "1234" } )
  end
end