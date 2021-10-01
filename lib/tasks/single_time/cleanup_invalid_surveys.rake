namespace :single_time do
  #usage: bundle exec rake single_time:cleanup_invalid_surveys
  desc "Surveys for which campaign ref_obj is not present, assign them default campaigns"
  task cleanup_invalid_surveys: :environment do
    invalid_survey_ids = Survey.pluck('id') - CampaignManagement::AbstractCampaign.joins("INNER JOIN surveys on cm_campaigns.ref_obj_id  = surveys.id").pluck('cm_campaigns.ref_obj_id')
    Survey.where(id: invalid_survey_ids, type: [Survey::Type::ENGAGEMENT, Survey::Type::MEETING_FEEDBACK]).each do |survey|
      survey.create_default_campaign
    end
    puts "Campaign assignment done!"
  end
end
