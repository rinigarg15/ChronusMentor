include ChronusS3Utils

MailerTag.register_tags(:calendar_ics_attachment_tag) do |t|
  t.tag :url_program_event_request_calendar_attachment, :description => Proc.new{'feature.email.tags.meeting_request_tags.meeting_request_calendar_attachment'.translate}, :example => Proc.new{"https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/files/20140321091645_sample_event.ics"} do
    file_path = "/tmp/" + S3Helper.embed_timestamp("#{SecureRandom.hex(3)}_#{TEMP_FILE_NAME}")
    File.open(file_path, 'w') { |file| file.write(@attachment) }
    S3Helper.transfer(file_path, PROGRAM_EVENT_ICS_S3_PREFIX, APP_CONFIG[:chronus_mentor_common_bucket], {:content_type => ICS_CONTENT_TYPE, :url_expires => 7.days}).html_safe
  end
end