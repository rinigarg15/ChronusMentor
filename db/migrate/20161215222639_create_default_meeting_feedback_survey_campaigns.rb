class CreateDefaultMeetingFeedbackSurveyCampaigns< ActiveRecord::Migration[4.2]
  def up
    MeetingFeedbackSurvey.find_each do |survey|
      survey.create_default_campaign
    end
  end

  def down
    # nothing
  end
end