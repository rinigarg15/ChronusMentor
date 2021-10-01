require_relative './../../test_helper.rb'

class CloudLogsTest < ActiveSupport::TestCase
  def setup
    super
    stubbed_cloudwatchlogs = Aws::CloudWatchLogs::Client.new(stub_responses: true)
    Aws::CloudWatchLogs::Client.stubs(:new).returns(stubbed_cloudwatchlogs)
    Aws::CloudWatchLogs::Types::DescribeLogStreamsResponse.any_instance.stubs(:log_streams).returns([Aws::CloudWatchLogs::Types::LogStream.new])
    @log_group_name = "test_log_group"
    @log_stream_name = "test_log_stream"
    @test_stream = CloudLogs.new(@log_group_name, @log_stream_name, {default_limit: 10})
  end

  def test_push_logs_after_limit
    @test_stream.expects(:push_logs)
    11.times {|i| @test_stream.log(i) }
  end

  def test_push_logs
    Timecop.freeze(Time.now) do
      @test_stream.log("text")
      logs = [{timestamp: DateTime.now.strftime('%Q'), message: "text"}]
      # Rescue should work only for five times. 
      Aws::CloudWatchLogs::Client.any_instance.expects(:put_log_events).raises(Aws::CloudWatchLogs::Errors::InvalidSequenceTokenException.new("sequence_error", "invalid sequence token")).times(5)
      @test_stream.push_logs
      Aws::CloudWatchLogs::Client.any_instance.expects(:put_log_events).with({ log_group_name: @log_group_name, log_stream_name: @log_stream_name, log_events: logs, sequence_token: nil })
      @test_stream.push_logs
    end
  end

  def test_pull_logs
    Aws::CloudWatchLogs::Client.any_instance.expects(:get_log_events).with({ log_group_name: @log_group_name, log_stream_name: @log_stream_name, start_from_head: true, limit: 10, next_token: nil }).returns(Aws::CloudWatchLogs::Types::GetLogEventsResponse.new).times(2)
    # Stub to emulate pulling logs twice
    Aws::CloudWatchLogs::Types::GetLogEventsResponse.any_instance.stubs(:events).returns([1],[])
    @test_stream.log("text")
    assert_empty @test_stream.pull_logs
  end

  def test_create_delete_log_streams
    Aws::CloudWatchLogs::Client.any_instance.expects(:create_log_stream).with({ log_group_name: @log_group_name, log_stream_name: @log_stream_name})
    test_stream = CloudLogs.new(@log_group_name, @log_stream_name, {default_limit: 10})
    Aws::CloudWatchLogs::Client.any_instance.expects(:create_log_stream).raises(Aws::CloudWatchLogs::Errors::ResourceAlreadyExistsException.new("error", "already exists"))
    test_stream = CloudLogs.new(@log_group_name, @log_stream_name, {default_limit: 10})
    Aws::CloudWatchLogs::Client.any_instance.expects(:delete_log_stream).with({ log_group_name: @log_group_name, log_stream_name: @log_stream_name})
    test_stream.delete_log_stream
    Aws::CloudWatchLogs::Client.any_instance.expects(:delete_log_stream).raises(Aws::CloudWatchLogs::Errors::ResourceNotFoundException.new("error", "not found"))
    test_stream.delete_log_stream
  end
end