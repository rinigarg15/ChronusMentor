MailerTag.register_tags(:meeting_request_status_sender_name_tag) do |t|
  t.tag :meeting_request_status_sender_name, description: Proc.new{'feature.email.tags.meeting_request_tags.meeting_request_status_sender_name_v1'.translate(:meeting => @_meeting_string)}, example: Proc.new{'John Doe'} do
    @sender.name(name_only: true)
  end
end
