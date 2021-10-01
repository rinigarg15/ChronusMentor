module DjSourcePriorityHelper
  # Set the delayed_job priority to be higher for web requests than other requests.
  def set_web_dj_priority
    Delayed::Job.source_priority = DjSourcePriority::WEB
  end

  # Set the delayed_job priority to be higher for bulk requests than api and cron requests.
  def set_bulk_dj_priority
    Delayed::Job.source_priority = DjSourcePriority::BULK
  end

  # Set the delayed_job priority to be higher for api requests than cron requests.
  def set_api_dj_priority
    Delayed::Job.source_priority = DjSourcePriority::API
  end

  def set_cron_dj_priority(high_priority = false)
    Delayed::Job.source_priority = high_priority ? DjSourcePriority::CRON_HIGH : DjSourcePriority::CRON
  end
end