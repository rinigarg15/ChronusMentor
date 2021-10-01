jbuilder_responder(json, local_assigns) do
  json.announcement do
    json.extract! @announcement, :id, :title, :body, :updated_at
    json.recipients @announcement.recipient_roles_str
    if @announcement.attachment?
      json.attachment do
        json.file_name @announcement.attachment_file_name
        json.url @announcement.attachment.url
      end
    end
  end
end