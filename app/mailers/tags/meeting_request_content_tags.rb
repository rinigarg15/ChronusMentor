MailerTag.register_tags(:meeting_request_content_tags) do |t|
  t.tag :meeting_topic, description: Proc.new{'feature.email.tags.meeting_request_tags.meeting_topic.description'.translate(meeting: @_meeting_string)}, example: Proc.new{'feature.email.tags.meeting_request_tags.meeting_topic.example'.translate} do
    @meeting.topic
  end

  t.tag :meeting_description, :description => Proc.new{'feature.email.tags.meeting_tags.meeting_description.description'.translate}, :example => Proc.new{'feature.email.tags.meeting_tags.meeting_description.example'.translate} do
    @meeting.description.presence || "-"
  end

end