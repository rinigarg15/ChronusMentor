class CleanupPolymorphicAssociationEntries< ActiveRecord::Migration[4.2]
  def up
    drop_table :member_notifications

    ChronusMigrate.data_migration(has_downtime: false) do
      VulnerableContentLog.where(ref_obj_type: ["MentoringTemplate::Milestone", "FacilitateUser", "FacilitationMessage"]).delete_all
      RoleReference.where(ref_obj_type: ["ProfileSummaryField", "Handbook", "FacilitationMessage"]).delete_all
      FacilitationDeliveryLog.where(facilitation_delivery_loggable_type: ["FacilitationMessage", "FacilitateUser"]).delete_all
      Subscription.where(ref_obj_type: "forum").update_all(ref_obj_type: "Forum")
      PendingNotification.where(ref_obj_type: "Task").delete_all
      profile_answers = ProfileAnswer.where(ref_obj_type: "MembershipRequest")
      profile_answer_ids = profile_answers.pluck(:id)
      Education.where(profile_answer_id: profile_answer_ids).delete_all
      Experience.where(profile_answer_id: profile_answer_ids).delete_all
      Manager.where(profile_answer_id: profile_answer_ids).delete_all
      Publication.where(profile_answer_id: profile_answer_ids).delete_all
      profile_answers.delete_all
    end
  end

  def down
    # do nothing
  end
end
