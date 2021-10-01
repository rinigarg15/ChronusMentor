require_relative './../../../test_helper.rb'

class ExconOverridesTest < ActiveSupport::TestCase
  def test_excon_socket_connect_override
    assert_gem_version "excon", "0.54.0", "'excon' gem version seems to be mismatching, please remove this test case and the associated override (in file 'excon_overrides.rb') if they are not applicable anymore"
  end
end