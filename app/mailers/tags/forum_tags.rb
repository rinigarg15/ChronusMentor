MailerTag.register_tags(:forum_tags) do |t|
  t.tag :initiator_name, description: Proc.new { "email_translations.forum_topic_notification.tags.initiator_name.description".translate }, example: Proc.new { "feature.email.tags.mentor_name.example".translate } do
    @topic.user.name
  end

  t.tag :reply_to_conversation_button, description: Proc.new { "email_translations.forum_topic_notification.tags.reply_to_conversation_button.description".translate }, example: Proc.new { ChronusActionMailer::Base.call_to_action_example("email_translations.forum_topic_notification.reply_to_conversation".translate) } do
    reply_url = @forum.is_group_forum? ? forum_url(@forum, topic_id: @topic.id, subdomain: @organization.subdomain) : forum_topic_url(@topic.forum, @topic, subdomain: @organization.subdomain)
    call_to_action("email_translations.forum_topic_notification.reply_to_conversation".translate, reply_url)
  end

  t.tag :link_to_initiator, description: Proc.new { "email_translations.forum_topic_notification.tags.link_to_initiator.description".translate }, example: Proc.new { "http://www.chronus.com" } do
    user_url(@topic.user, subdomain: @organization.subdomain, root: @program.root)
  end

  t.tag :forum_name, description: Proc.new { "feature.email.tags.forum_tags.forum_name.description".translate }, example: Proc.new { |program| "email_translations.forum_notification.tags.forum_name.example_v1".translate(role: program.get_first_role_term(:term)) } do
    @topic.forum.name
  end

  t.tag :conversation_title, description: Proc.new { "feature.email.tags.forum_tags.conversation_title.description".translate }, example: Proc.new { "feature.email.tags.forum_tags.conversation_title.example".translate } do
    @topic.title
  end

  t.tag :link_to_conversation, description: Proc.new { "feature.email.tags.forum_tags.link_to_conversation.description".translate }, example: Proc.new { "http://www.chronus.com" } do
    forum_topic_url(@topic.forum, @topic, subdomain: @organization.subdomain)
  end
end