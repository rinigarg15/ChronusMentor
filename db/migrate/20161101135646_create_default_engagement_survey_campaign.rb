class CreateDefaultEngagementSurveyCampaign< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      EngagementSurvey.unscoped.all.each do |survey|
        survey.create_default_campaign(false)
      end
    end
  end

  def down
    # nothing
  end
end
