class CleanUpMailerTemplateSource< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Mailer::Template.where(source: "Hi {{receiver_first_name}},<br/><br/>We would like to hear about your {{customized_meeting_term}} - {{topic_of_meeting}} with {{partner_name}}. Please take a moment to provide us feedback - your input is important to us. We've kept it brief since we know life gets busy.<br/>{{feedback_survey_button}}<br/>We thank you for your valuable feedback. Did you know you can capture the {{customized_meeting_term}} notes, followups and resource attachments from your <a href=\'{{meeting_area_url}}\' target=\'_blank\'>{{customized_meeting_term}} area</a>?</br></br>If you have rescheduled the {{customized_meeting_term}}, please <a href=\'{{meeting_reschedule_url}}\' target=\'_blank\'>click here</a> to update the {{customized_meeting_term}} time.").each do |mt|
      	mt.update_attributes!(source: "Hi {{receiver_first_name}},<br/><br/>We would like to hear about your {{customized_meeting_term}} - {{topic_of_meeting}} with {{partner_name}}. Please take a moment to provide us feedback - your input is important to us. We've kept it brief since we know life gets busy.<br/>{{feedback_survey_button}}<br/>We thank you for your valuable feedback. Did you know you can capture the {{customized_meeting_term}} notes, followups and resource attachments from your <a href=\'{{meeting_area_url}}\' target=\'_blank\'>{{customized_meeting_term}} area</a>?<br/><br/>If you have rescheduled the {{customized_meeting_term}}, please <a href=\'{{meeting_reschedule_url}}\' target=\'_blank\'>click here</a> to update the {{customized_meeting_term}} time.")
      end
      Mailer::Template.where(source: "Hi {{receiver_first_name}},<br/><br/>We are still waiting for your feedback for the {{customized_meeting_term}}, {{topic_of_meeting}} with {{partner_name}}. Your input ensures we continue to provide the best experience possible for you and the users in the program. We promise it only takes a moment of your time.<br/><br/>{{feedback_survey_button}}<br/></br>If you have rescheduled the {{customized_meeting_term}}, please <a href=\'{{meeting_reschedule_url}}\' target=\'_blank\'>click here</a> to update the {{customized_meeting_term}} time.").each do |mt|
      	mt.update_attributes!(source: "Hi {{receiver_first_name}},<br/><br/>We are still waiting for your feedback for the {{customized_meeting_term}}, {{topic_of_meeting}} with {{partner_name}}. Your input ensures we continue to provide the best experience possible for you and the users in the program. We promise it only takes a moment of your time.<br/><br/>{{feedback_survey_button}}<br/><br/>If you have rescheduled the {{customized_meeting_term}}, please <a href=\'{{meeting_reschedule_url}}\' target=\'_blank\'>click here</a> to update the {{customized_meeting_term}} time.")
      end
    end
  end

  def down
  #Do nothing
  end
end
