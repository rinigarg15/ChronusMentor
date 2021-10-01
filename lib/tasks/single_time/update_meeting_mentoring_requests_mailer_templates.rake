# JIRA Ticket: https://chronus.atlassian.net/browse/AP-18031
# More Info : Update Meeting and Mentoring Requests Declined/Auto-closed email sources and subjects

namespace :single_time do
desc 'update_meeting_mentoring_requests_mailer_templates'
  task :update_meeting_mentoring_requests_mailer_templates => :environment do
    ActiveRecord::Base.transaction do
      templates = Mailer::Template.where(uid: [MentorRequestRejected.mailer_attributes[:uid], MentorRequestExpiredToSender.mailer_attributes[:uid], MeetingRequestExpiredNotificationToSender.mailer_attributes[:uid], MeetingRequestStatusDeclinedNotificationNonCalendar.mailer_attributes[:uid], MeetingRequestStatusDeclinedNotification.mailer_attributes[:uid]]).includes(:translations, program: [:translations, organization: [:translations, :default_program_domain]])

      previous_subjects = { MentorRequestRejected.mailer_attributes[:uid] => "email_translations.mentor_request_rejected.subject_v3", MentorRequestExpiredToSender.mailer_attributes[:uid] => "email_translations.mentor_request_expired_to_sender.subject_v1", MeetingRequestExpiredNotificationToSender.mailer_attributes[:uid] => "email_translations.meeting_request_expired_notification_to_sender.subject_v1", MeetingRequestStatusDeclinedNotificationNonCalendar.mailer_attributes[:uid] => "email_translations.meeting_request_status_declined_notification_non_calendar.subject_v2", MeetingRequestStatusDeclinedNotification.mailer_attributes[:uid] => "email_translations.meeting_request_status_declined_notification.subject_v2"}
      
      previous_sources = { MentorRequestRejected.mailer_attributes[:uid] => "email_translations.mentor_request_rejected.content_v3_html", MentorRequestExpiredToSender.mailer_attributes[:uid] => "email_translations.mentor_request_expired_to_sender.content_v1_html", MeetingRequestExpiredNotificationToSender.mailer_attributes[:uid] => "email_translations.meeting_request_expired_notification_to_sender.content_v1_html", MeetingRequestStatusDeclinedNotificationNonCalendar.mailer_attributes[:uid] => "email_translations.meeting_request_status_declined_notification_non_calendar.content_v4_html", MeetingRequestStatusDeclinedNotification.mailer_attributes[:uid] => "email_translations.meeting_request_status_declined_notification.content_v6_html"}

      templates.each do |t|
        t.translations.each do |translation|
          locale = translation.locale
          uid = t.uid
          if translation.source.present?
            GlobalizationUtils.run_in_locale(locale) do
              translation_source = MailerTemplatesHelper.handle_space_quotes_in_mail_content(translation.source)
              previous_source = MailerTemplatesHelper.handle_space_quotes_in_mail_content(previous_sources[uid].translate(locale: locale))
              translation.update_column(:source, nil) if translation_source == previous_source
            end
          end
          if translation.subject.present?
            GlobalizationUtils.run_in_locale(locale) do
              translation_subject = MailerTemplatesHelper.handle_space_quotes_in_mail_content(translation.subject) 
              previous_subject = MailerTemplatesHelper.handle_space_quotes_in_mail_content(previous_subjects[uid].translate(locale: locale))
              translation.update_column(:subject, nil) if translation_subject == previous_subject
            end
          end
        end
      end
    end
  end
end