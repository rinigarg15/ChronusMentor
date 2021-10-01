MailerTag.register_tags(:reply_to_tags) do |t|
  t.tag :reply_to_button, :description => Proc.new{'feature.email.tags.reply_to_tags.reply_to_button.description'.translate}, :example => Proc.new{ChronusActionMailer::Base.call_to_action_example('feature.email.tags.reply_to_tags.reply_to_button.reply_text'.translate) } do
    reply_url = @reply_to[0]
    subject = 'feature.email.tags.reply_to_tags.subject'.translate(subject_text: @reply_to_subject)
    call_to_action('feature.email.tags.reply_to_tags.reply_to_button.reply_text'.translate, reply_url, 'button', {mail_to_action: true, subject: subject})
  end
end