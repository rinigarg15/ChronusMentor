require_relative './../../test_helper.rb'

class SecuritySettingServiceTest < ActiveSupport::TestCase
  def test_parse_params
    params = [
      { from: '127.0.0.1', to: '' },
      { from: '', to: '' },
      { from: '192.168.0.1', to: '192.168.0.225' },
      { from: 'example.com', to: '' }
    ]
    assert_equal '127.0.0.1,192.168.0.1:192.168.0.225,example.com', SecuritySettingService.parse_params(params)
  end
end
