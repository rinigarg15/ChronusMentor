module DeploymentModuleHelper
  def retry_when_exception(error_message)
    counter = 0
    begin
      counter += 1
      return yield
    rescue => e
      if counter <= API_RETRY_TIMES
        sleep API_RETRY_INTERVAL
        retry
      else
        puts "ERROR: #{error_message}\nException: #{e.message}".colorize(:red)
        DeploymentHelper.send_developer_email("Error: #{error_message}", "ERROR: #{error_message}\nException: #{e.message}", OPS_EMAIL_ID)
        return false
      end
    end
  end
end
