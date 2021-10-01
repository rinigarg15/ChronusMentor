MailerTag.register_tags(:meeting_rescudule_button_tags) do |t|
  t.tag :meeting_reschedule_button, :description => Proc.new{'feature.email.tags.meeting_rescudule_button_tags.meeting_reschedule_button.description'.translate}, :example => Proc.new{'feature.email.tags.meeting_rescudule_button_tags.meeting_reschedule_button.example_html'.translate} do
    render(partial: '/meeting_description_with_action', locals: {meeting: @meeting, member: @member})
  end
end