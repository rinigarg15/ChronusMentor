class DropTableMailgunBatchSenderFailedLog< ActiveRecord::Migration[4.2]
  def change
    drop_table :mailgun_batch_sender_failed_logs
  end
end
