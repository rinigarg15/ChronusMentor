namespace :single_time do

  #usage: bundle exec rake single_time:cleanup_campaign_stats_for_duplicate_emails CAMPAIGN_ID=9544 CAMPAIGN_MESSAGE_ID=17767
  desc "Cleanup campaign stats for duplicate emails sent"
  task cleanup_campaign_stats_for_duplicate_emails: :environment do
    Common::RakeModule::Utils.execute_task do
      campaign_message = CampaignManagement::UserCampaign.find(ENV['CAMPAIGN_ID'].to_i).campaign_messages.find(ENV['CAMPAIGN_MESSAGE_ID'].to_i)
      raise "Campaign Message not found" unless campaign_message.present?

      all_email_ids  = campaign_message.emails.pluck(:id)
      all_dup_message_receivers = AbstractMessageReceiver.where(message_id: all_email_ids).group_by(&:member_id).select{|member_id, msgs| msgs.size > 1 }

      all_dup_messages = AbstractMessage.where(id: all_dup_message_receivers.values.flatten.collect(&:message_id)).index_by(&:id)

      cleaned_up_message_ids = []
      email_event_log_hash = CampaignManagement::EmailEventLog.where(message_id: all_dup_messages.keys, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, event_type: [0, 1]).group_by(&:message_id)

      all_dup_message_receivers.each do |member_id, msg_receivers|
        consider_analytics_clean = false
        message_id_toclean = if email_event_log_hash[msg_receivers[0].message_id] && email_event_log_hash[msg_receivers[1].message_id]
                                consider_analytics_clean = true
                                first_message_event_logs_size = email_event_log_hash[msg_receivers[0].message_id].collect(&:event_type).uniq.size
                                second_message_event_logs_size = email_event_log_hash[msg_receivers[1].message_id].collect(&:event_type).uniq.size
                                if second_message_event_logs_size < 2 && first_message_event_logs_size == 2
                                  msg_receivers[1].message_id
                                else
                                  msg_receivers[0].message_id
                                end
                             elsif email_event_log_hash[msg_receivers[0].message_id]
                                msg_receivers[1].message_id
                             elsif email_event_log_hash[msg_receivers[1].message_id]
                                msg_receivers[0].message_id
                             else
                                msg_receivers[0].message_id
                             end
        message = all_dup_messages[message_id_toclean]
        if consider_analytics_clean.present?
          key = CampaignManagement::AbstractCampaignMessage.get_analytics_summary_key(message.created_at)
          event_types = email_event_log_hash[message_id_toclean].collect(&:event_type).uniq
          event_types.each do |e_type|
            campaign_analytics_entry = campaign_message.campaign_message_analyticss.where(year_month: key, event_type: e_type).first
            if campaign_analytics_entry
              campaign_analytics_entry.with_lock do
                campaign_analytics_entry.event_count -= 1
                campaign_analytics_entry.save!
              end
            end
          end
          email_event_log_hash[message.id].each(&:delete)
        end
        message.update_columns(campaign_message_id: nil, skip_delta_indexing: true)
        cleaned_up_message_ids << message.id
      end

      Common::RakeModule::Utils.print_success_messages("Campaign Message reference is cleaned up following admin message ids: #{cleaned_up_message_ids}")
    end
  end

end