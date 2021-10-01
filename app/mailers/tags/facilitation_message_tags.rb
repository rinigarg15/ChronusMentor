include CommonTags
MailerTag.register_tags(:facilitation_message_tags) do |t|
  t.get_common_user_tags
  t.get_common_organization_tags
  t.get_common_group_tags
end