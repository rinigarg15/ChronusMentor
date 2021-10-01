MailerTag.register_tags(:message_tags) do |t|
  t.tag :message_subject, :description => Proc.new{'feature.email.tags.message_tags.message_subject.description'.translate}, :example => Proc.new{'feature.email.tags.message_tags.message_subject.example'.translate} do
    @message.subject
  end

  t.tag :sender_name, :description => Proc.new{'feature.email.tags.message_tags.sender_name.description'.translate}, :example => Proc.new{"Jane Doe"} do
    @message.sender.present? ? @message.sender.name : @message.sender_name
  end

  t.tag :url_sender_profile, :description => Proc.new{'feature.email.tags.message_tags.url_sender_profile.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
    member_url(@message.sender_id, :subdomain => @organization.subdomain)
  end

  t.tag :url_reply, :description => Proc.new{'feature.email.tags.message_tags.url_reply.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
    message_url(@message.get_root, :subdomain => @organization.subdomain, :reply => true, :is_inbox => true)
  end

  t.tag :url_message, :description => Proc.new{'feature.email.tags.message_tags.url_message.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
    message_url(@message.get_root, :subdomain => @organization.subdomain, :is_inbox => true)
  end

  t.tag :message_content, :description => Proc.new{'feature.email.tags.message_tags.message_content.description'.translate}, :example => Proc.new{'feature.email.tags.message_tags.message_content.example'.translate} do
    wrap_and_break(@message.content)
  end
end