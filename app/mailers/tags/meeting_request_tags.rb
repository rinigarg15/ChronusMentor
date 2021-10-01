MailerTag.register_tags(:meeting_request_tags) do |t|
  t.tag :meeting_request_creator_name, description: Proc.new{'feature.email.tags.meeting_request_tags.meeting_request_creator_name_v1'.translate(:meeting => @_meeting_string)}, example: Proc.new{'John Peter'} do
    @meeting_request.student.name(name_only: true)
  end

  t.tag :meeting_request_recepient_name, description: Proc.new{'feature.email.tags.meeting_request_tags.meeting_request_recepient_name_v1'.translate(:meeting => @_meeting_string)}, example: Proc.new{'Jane Smith'} do
    @meeting_request.mentor.name(name_only: true)
  end

  t.tag :mentee_name, :description => Proc.new{'feature.email.tags.meeting_tags.mentee_name.description'.translate}, :example => Proc.new{'feature.email.tags.meeting_tags.mentee_name.example'.translate} do
    @meeting_request.student.name(:name_only => true)
  end

  t.tag :mentor_name, :description => Proc.new{'feature.email.tags.meeting_tags.mentor_name.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example'.translate} do
    @meeting_request.mentor.name
  end
  
end