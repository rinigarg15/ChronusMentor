class DisableAutoEmailNotification< ActiveRecord::Migration[4.2]

  REPLY_TO_ADMIN_MESSAGE_NOTIFICATION = "20sr4rms"
  AUTO_EMAIL_NOTIFICATION = "2xw1lphb"

  # Auto email notification - new template for system generated mails like facilitation messages.
  # Disable the new mailer template based on the old template (reply to admin message notification)

  def up
    ActiveRecord::Base.transaction do
      initial_mailer_templates_count = Mailer::Template.count
      disabled_replyto_admin_message_templates = Mailer::Template.where("uid = ? and enabled = ?", REPLY_TO_ADMIN_MESSAGE_NOTIFICATION, false)
      disabled_replyto_admin_message_templates.each do |mailer_template|
        program_or_org = mailer_template.program
        program_or_org.mailer_templates.create!(
          uid: AUTO_EMAIL_NOTIFICATION,
          enabled: false
        )
      end
      raise "Count Mismatch!" if Mailer::Template.count != (initial_mailer_templates_count + disabled_replyto_admin_message_templates.count)
    end
  end

  def down
    Mailer::Template.where("uid = ? and enabled = ?", AUTO_EMAIL_NOTIFICATION, false).destroy_all
  end
end