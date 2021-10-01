require_relative './../../../test_helper.rb'

class CronMonitor::SignalTest < ActiveSupport::TestCase

  def test_trigger
    receiver_const = "123"
    Net::HTTP.expects(:get).with(URI.parse(CronMonitor::Signal::API_PATH + receiver_const)).returns("OK")
    assert_equal "OK", CronMonitor::Signal.new(receiver_const).trigger
  end
end