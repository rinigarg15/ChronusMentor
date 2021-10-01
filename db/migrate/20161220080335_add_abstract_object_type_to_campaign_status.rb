class AddAbstractObjectTypeToCampaignStatus< ActiveRecord::Migration[4.2]
  def up
    add_column :cm_campaign_statuses, :abstract_object_type, :string
    CampaignManagement::SurveyCampaignStatus.update_all(:abstract_object_type => MentoringModel::Task.name)
    CampaignManagement::UserCampaignStatus.update_all(:abstract_object_type => User.name)
    CampaignManagement::ProgramInvitationCampaignStatus.update_all(:abstract_object_type => ProgramInvitation.name)

    add_column :cm_campaign_message_jobs, :abstract_object_type, :string
    CampaignManagement::SurveyCampaignMessageJob.update_all(:abstract_object_type => MentoringModel::Task.name)
    CampaignManagement::UserCampaignMessageJob.update_all(:abstract_object_type => User.name)
    CampaignManagement::ProgramInvitationCampaignMessageJob.update_all(:abstract_object_type => ProgramInvitation.name)
  end

  def down
    remove_column :cm_campaign_statuses, :abstract_object_type
    remove_column :cm_campaign_message_jobs, :abstract_object_type
  end
end
