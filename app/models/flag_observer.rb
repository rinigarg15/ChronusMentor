class FlagObserver < ActiveRecord::Observer

  def after_create(flag)
    # send mail to admin
    Flag.delay.send_content_flagged_admin_notification(flag.id, JobLog.generate_uuid)
  end
end