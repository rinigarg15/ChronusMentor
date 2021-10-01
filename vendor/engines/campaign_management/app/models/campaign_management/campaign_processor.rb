require "singleton"

class CampaignManagement::CampaignProcessor
  include Singleton

  def start
    start_time = Time.now
    Rails.logger.info "Starting Campaign Processor: #{start_time}"
    Program.active.includes(user_campaigns: :campaign_messages, surveys: :campaign).select("programs.id").each do |program|
      Rails.logger.info "CampaignManagement::CampaignProcessor: processing program ##{program.id}"
      process_user_campaigns(program)
      process_survey_campaigns(program)
    end
    end_time = Time.now
    Rails.logger.info "Finishing Campaign Processor: #{end_time}"
    Rails.logger.info "Time taken for Campaign Processor: #{end_time - start_time}"
  end

  def campaign_using_admin_view(admin_view)
    used_in_campaigns = []
    if admin_view && admin_view.program.is_a?(Program)
      used_in_campaigns = admin_view.program.user_campaigns.select([:id, :trigger_params]).all.select do |campaign|
        campaign.all_admin_view_ids.map(&:to_s).include?(admin_view.id.to_s)
      end
    end
    used_in_campaigns
  end

  private

  def process_user_campaigns(program)
    BlockExecutor.iterate_fail_safe(program.user_campaigns) do |campaign|
      campaign.process!
    end
  end

  def process_survey_campaigns(program)
    BlockExecutor.iterate_fail_safe(program.surveys) do |survey|
      next unless survey.can_have_campaigns?

      survey.campaign.process!
    end
  end
end