jbuilder_responder(json, local_assigns) do
  attachments_hash = @scraps_hash[:messages_attachments]
  last_created_at_hash = @scraps_hash[:messages_last_created_at]
  scraps_index = @scraps_hash[:messages_index]
  latest_scraps = @scraps_hash[:latest_messages]

  json.scraps do
    json.array! latest_scraps do |scrap|
      scrap = scraps_index[scrap.root_id]
      json.extract! scrap, :id, :subject, :content, :type
      json.created_at last_created_at_hash[scrap.root_id]
      json.unread  scrap.tree_contains_unread_for_member?(@current_member)
      json.thread_count    scrap.thread_members_and_size(@current_member)[:size]
      json.has_attachment attachments_hash[scrap.root_id]
      json.from from_details(scrap, @current_member)
      json.member_picture_url generate_member_url(scrap.sender, size: :small)
    end
  end

  json.total_scraps_count @total_scraps_count
  json.group_name @group.name
end
