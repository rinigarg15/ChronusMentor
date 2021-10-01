class SpeedupCmProgramInvitations < ActiveRecord::Migration[4.2]

  def up
    # checks
    type_values = ActiveRecord::Base.connection.execute("SELECT `cm_campaign_statuses`.`type` FROM `cm_campaign_statuses`").to_a.flatten.uniq
    type_values += ActiveRecord::Base.connection.execute("SELECT `cm_campaign_message_jobs`.`type` FROM `cm_campaign_message_jobs`").to_a.flatten.uniq
    type_values.each { |type| raise "Cannot convert to string, '#{type}' is more than #{UTF8MB4_VARCHAR_LIMIT} chars" if type.size > UTF8MB4_VARCHAR_LIMIT }

    # ready for migration
    change_column :cm_campaign_statuses, :type, :string, limit: UTF8MB4_VARCHAR_LIMIT
    change_column :cm_campaign_message_jobs, :type, :string, limit: UTF8MB4_VARCHAR_LIMIT
    add_index :cm_campaign_statuses, [:type, :campaign_id], name: :cm_campaign_statuses_type_campaign_id
    add_index :cm_campaign_statuses, [:type, :campaign_id, :abstract_object_id], name: :cm_campaign_statuses_type_campaign_id_abs_obj_id
    add_index :cm_campaign_message_jobs, [:campaign_message_id, :abstract_object_id], name: :cm_campaign_message_jobs_campaign_message_id_abstract_object_id
    add_index :cm_campaign_message_jobs, [:type, :abstract_object_id, :campaign_message_id, :failed], name: :cm_campaign_message_jobs_type_absobj_id_cm_id_failed
  end

  def down
    remove_index :cm_campaign_statuses, name: :cm_campaign_statuses_type_campaign_id
    remove_index :cm_campaign_statuses, name: :cm_campaign_statuses_type_campaign_id_abs_obj_id
    remove_index :cm_campaign_message_jobs, name: :cm_campaign_message_jobs_campaign_message_id_abstract_object_id
    remove_index :cm_campaign_message_jobs, name: :cm_campaign_message_jobs_type_absobj_id_cm_id_failed
    change_column :cm_campaign_statuses, :type, :text
    change_column :cm_campaign_message_jobs, :type, :text
  end
end
