class RemoveUrlInviteTagFromUserCampaignMailerTemplates< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      user_campaign_message_ids = CampaignManagement::UserCampaignMessage.pluck(:id)
      mailer_template_ids = Mailer::Template.where(campaign_message_id: user_campaign_message_ids).pluck(:id)
      mailer_template_translations = Mailer::Template::Translation.where(mailer_template_id: mailer_template_ids).where("source LIKE '%{{url_invite}}%'")
      mailer_template_id_new_source_hash = {}

      mailer_template_translations.find_each do |mailer_template_translation|
        source = mailer_template_translation.source
        source.gsub!("{{url_invite}}", "{{url_signup}}")
        mailer_template_translation.update_column(:source, source)
        mailer_template_id_new_source_hash[mailer_template_translation.mailer_template_id] ||= source
      end

      mailer_templates = Mailer::Template.where(id: mailer_template_id_new_source_hash.keys)
      mailer_template_id_new_source_hash.each_pair do |mailer_template_id, new_source|
        mailer_template = mailer_templates.find { |mailer_template| mailer_template.id == mailer_template_id }
        mailer_template.update_column(:source, new_source)
      end
    end
  end

  def down
  end
end
