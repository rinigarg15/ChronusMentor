class FixIncorrectLoggableObjectInJobLogs< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration do
      JobLog.where(ref_obj_type: "ProgramInvitation", loggable_object_type: "ProgramInvitation").update_all(loggable_object_type: "CampaignManagement::ProgramInvitationCampaign")
    end
  end

  def down
    # no down migration
  end
end
