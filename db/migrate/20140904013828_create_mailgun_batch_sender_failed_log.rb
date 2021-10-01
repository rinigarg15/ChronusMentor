class CreateMailgunBatchSenderFailedLog< ActiveRecord::Migration[4.2]
  def change
  	create_table :mailgun_batch_sender_failed_logs do |t|
      # mediumtext
      t.text 	:params, :limit => 16777215
    end
  end
end
