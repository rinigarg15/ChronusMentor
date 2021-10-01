class UserCampaignMessagePopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["campaign_management_enabled?"]
    user_campaign_ids = @program.user_campaigns.pluck(:id)
    user_campaign_messages_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, user_campaign_ids)
    process_patch(user_campaign_ids, user_campaign_messages_hsh)
  end

  def add_user_campaign_messages(user_campaign_ids, count, options = {})
    self.class.benchmark_wrapper "User Campaign Messages" do
      program = options[:program]
      admin_user_ids = program.admin_users.active.pluck(:id)
      temp_admin_user_ids = admin_user_ids.dup
      user_campaigns = CampaignManagement::UserCampaign.where(id: user_campaign_ids).to_a
      temp_user_campaigns = user_campaigns * count
      CampaignManagement::UserCampaignMessage.populate(user_campaign_ids.size * count, :per_query => 10_000) do |cm_message|
        temp_admin_user_ids = admin_user_ids.dup if temp_admin_user_ids.blank?
        user_campaign = temp_user_campaigns.shift
        cm_message.campaign_id = user_campaign.id
        cm_message.sender_id = temp_admin_user_ids.shift
        cm_message.duration = rand(0..180)
        cm_message.created_at = [Time.now - rand(1..100).days, user_campaign.created_at].max
        cm_message.user_jobs_created = 1
        Mailer::Template.populate 1 do |mailer_template|
          source = Populator.sentences(2..4)
          subject = Populator.words(5..10)

          mailer_template.program_id = program.id
          mailer_template.campaign_message_id = cm_message.id
          mailer_template.uid = Populator.words(5..10)
          mailer_template.enabled = [true, true, true, true, false].sample
          mailer_template.created_at = [Time.now - rand(1..100).days, cm_message.created_at].max

          locales = @translation_locales.dup
          Mailer::Template::Translation.populate @translation_locales.count do |translation|
            translation.mailer_template_id = mailer_template.id
            translation.source = DataPopulator.append_locale_to_string(source, locales.last)
            translation.subject = DataPopulator.append_locale_to_string(subject, locales.last)
            translation.locale = locales.pop
          end
        end
        self.dot
      end
      self.class.display_populated_count(user_campaign_ids.size * count, "User Campaign Messages")
    end
  end

  def remove_user_campaign_messages(user_campaign_ids, count, options = {})
    self.class.benchmark_wrapper "Removing User Campaign Messages................" do
      user_campaign_message_ids = CampaignManagement::UserCampaignMessage.where(:campaign_id => user_campaign_ids).select([:id, :campaign_id]).group_by(&:campaign_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      CampaignManagement::UserCampaignMessage.where(:id => user_campaign_message_ids).destroy_all
      self.class.display_deleted_count(user_campaign_ids.size * count, "User Campaign Messages")
    end
  end
end