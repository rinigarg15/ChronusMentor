class AdminViewObserver < ActiveRecord::Observer
  def after_update(admin_view)
    admin_view.delay(queue: DjQueues::HIGH_PRIORITY).refresh_user_ids_cache if admin_view.saved_change_to_filter_params? && admin_view.is_program_view?  && admin_view.admin_view_user_cache.present?
  end

  def after_destroy(admin_view)
    return if admin_view.skip_observer
    used_in_campaigns = CampaignManagement::CampaignProcessor.instance.campaign_using_admin_view(admin_view)
    unless used_in_campaigns.empty?
      CampaignManagement::UserCampaign.where(id: used_in_campaigns.map(&:id)).destroy_all
    end
    admin_view.resource_publications.each do |resource_publication|
      resource_publication.update_attributes(show_in_quick_links: false, admin_view_id: nil)
    end
  end
end
