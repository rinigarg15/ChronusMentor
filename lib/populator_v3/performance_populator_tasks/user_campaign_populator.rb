class UserCampaignPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["campaign_management_enabled?"]
    program_ids = @organization.programs.pluck(:id)
    user_campaigns_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, user_campaigns_hsh)
  end

  def add_user_campaigns(program_ids, count, options = {})
    self.class.benchmark_wrapper "User Campaigns" do
      programs = Program.where(id: program_ids)
      programs.each do |program|
        admin_view_ids = program.admin_views.pluck(:id)
        temp_admin_view_ids = admin_view_ids.dup
        CampaignManagement::UserCampaign.populate count do |campaign|
          title = Populator.words(4..6)
          temp_admin_view_ids = admin_view_ids.dup if temp_admin_view_ids.blank?
          campaign.program_id = program.id
          campaign.state = [CampaignManagement::AbstractCampaign::STATE::ACTIVE, CampaignManagement::AbstractCampaign::STATE::ACTIVE, CampaignManagement::AbstractCampaign::STATE::ACTIVE, CampaignManagement::AbstractCampaign::STATE::ACTIVE, CampaignManagement::AbstractCampaign::STATE::STOPPED].sample
          campaign.trigger_params = YAML.dump(1 => [temp_admin_view_ids.shift])
          campaign.created_at = [Time.now - rand(1..100).days, program.created_at].max

          locales = @translation_locales.dup
          CampaignManagement::AbstractCampaign::Translation.populate @translation_locales.count do |translation|
            translation.cm_campaign_id = campaign.id
            translation.title = DataPopulator.append_locale_to_string(title, locales.last)
            translation.locale = locales.pop
          end
          self.dot
        end
      end
      self.class.display_populated_count(program_ids.size * count, "User Campaigns")
    end
  end

  def remove_user_campaigns(program_ids, count, options = {})
    self.class.benchmark_wrapper "Removing User Campaigns................" do
      user_campaign_ids = CampaignManagement::UserCampaign.where(:program_id => program_ids).select([:id, :program_id]).group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      CampaignManagement::UserCampaign.where(:id => user_campaign_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "User Campaigns")
    end
  end
end