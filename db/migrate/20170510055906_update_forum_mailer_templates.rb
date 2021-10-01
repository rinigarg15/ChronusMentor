class UpdateForumMailerTemplates< ActiveRecord::Migration[4.2]
  # 'Topic' has been rephrased as 'Conversation'
  def up
    ChronusMigrate.data_migration do
      update_tags(fetch_forum_mailer_templates, [["{{topic_title}}", "{{conversation_title}}"], ["{{url_topic}}", "{{link_to_conversation}}"]])
    end
  end

  def down
    ChronusMigrate.data_migration do
      update_tags(fetch_forum_mailer_templates, [["{{conversation_title}}", "{{topic_title}}"], ["{{link_to_conversation}}", "{{url_topic}}"]])
    end
  end

  private

  def fetch_forum_mailer_templates
    forum_mailers = ChronusActionMailer::Base.get_descendants.select { |mailer| mailer.mailer_attributes[:subcategory] == EmailCustomization::NewCategories::SubCategories::FORUMS }
    forum_mailer_uids = forum_mailers.collect { |forum_mailer| forum_mailer.mailer_attributes[:uid] }
    Mailer::Template.where(uid: forum_mailer_uids).includes(:translations)
  end

  def update_tags(mailer_templates, tags_update_info)
    mailer_templates.each do |mailer_template|
      mailer_template.translations.each do |translation|
        [:subject, :source].each do |mailer_attr|
          value = translation.send(mailer_attr)
          if value.present?
            tags_update_info.each { |tag_update_info| value.gsub!(*tag_update_info) }
            translation.send("#{mailer_attr}=", value)
          end
        end
        translation.save!
      end
    end
  end
end