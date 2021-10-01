class CloudLogs
  DEFAULT_LIMIT = 500
  SPLITTER = "---"

  def initialize(log_group_name, log_stream_name, options = {})
    if (Rails.env.development? || Rails.env.test?)
      aws_options = {access_key_id: ENV["S3_KEY"], secret_access_key: ENV["S3_SECRET"]}
    else
      aws_options = {region: AWS_ES_OPTIONS[:es_region]}
    end    
    @cloud_watch = Aws::CloudWatchLogs::Client.new(aws_options)
    @log_group_name = log_group_name
    @log_stream_name = log_stream_name
    @next_sequence_token = nil
    @logs = []
    @default_limit = options[:default_limit].presence || DEFAULT_LIMIT
    create_log_stream_if_not_exist
  end

  def log(text, options = {})
    options = {timestamp: DateTime.now.strftime('%Q'), message: text.to_s}.merge(options)
    @logs << options
    push_logs if @logs.size > @default_limit
    options
  end

  def push_logs
    return if @logs.empty?
    begin
      retries ||= 0
      get_next_sequence_token
      @cloud_watch.put_log_events({ log_group_name: @log_group_name, log_stream_name: @log_stream_name, log_events: @logs, sequence_token: @next_sequence_token })
      @logs = []
    rescue Aws::CloudWatchLogs::Errors::InvalidSequenceTokenException, Aws::CloudWatchLogs::Errors::DataAlreadyAcceptedException => e
      # This exception might occur as we are pushing logs simultaneously across djs.
      retry if (retries += 1) < 5
    end
  end

  def pull_logs
    logs = []
    next_token = nil
    loop do
      resp = @cloud_watch.get_log_events({ log_group_name: @log_group_name, log_stream_name: @log_stream_name, start_from_head: true, limit: @default_limit, next_token: next_token })
      break if resp.events.blank?
      logs << resp.events.collect(&:message)
      next_token = resp.next_forward_token
    end
    logs.flatten
  end

  def delete_log_stream
    @cloud_watch.delete_log_stream({log_group_name: @log_group_name, log_stream_name: @log_stream_name })
  rescue => e
    say "Log stream could not be deleted - #{e.message}"
  end

  private
  def create_log_stream_if_not_exist
    @cloud_watch.create_log_stream({ log_group_name: @log_group_name, log_stream_name: @log_stream_name })
  rescue Aws::CloudWatchLogs::Errors::ResourceAlreadyExistsException => e
    say "LogStream is already present"
  end

  def get_next_sequence_token
    resp = @cloud_watch.describe_log_streams({ log_group_name: @log_group_name, log_stream_name_prefix: @log_stream_name})
    @next_sequence_token = resp.try(:log_streams).try(:first).try(:upload_sequence_token)
  end

  def say(text)
    puts "#{text}"
    Delayed::Worker.logger.info "SFTP log - #{text}"
  end
end