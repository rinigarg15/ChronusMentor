require_relative './../test_helper'

class CampaignMessageJobProcessorTest < ActiveSupport::TestCase

  def test_bulk_send_should_create_personalized_messages_and_update_the_records_accordingly_in_case_of_success
    CampaignManagement::UserCampaignMessageJob.any_instance.expects(:create_personalized_message).times(8).returns({})
    CampaignManagement::CampaignMessageJobProcessor.process
    assert_equal 0, cm_campaigns(:active_campaign_1).jobs.count
  end

  def test_bulk_send_should_only_use_active_programs
    jobs = [cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_admin), cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_student),
      cm_campaign_message_jobs(:pending_active_campaign_message_2_job_for_admin), cm_campaign_message_jobs(:pending_active_campaign_message_2_job_for_student),
      cm_campaign_message_jobs(:pending_active_campaign_message_3_job_for_admin), cm_campaign_message_jobs(:pending_active_campaign_message_3_job_for_student),
      cm_campaign_message_jobs(:pending_active_campaign_message_4_job_for_admin), cm_campaign_message_jobs(:pending_active_campaign_message_4_job_for_student)]
    CampaignManagement::CampaignMessageJobProcessor.expects(:bulk_send_campaign_messages).with(jobs).once.returns(nil)
    CampaignManagement::CampaignMessageJobProcessor.process

    org = programs(:albers).organization
    org.active = false
    org.save!

    CampaignManagement::CampaignMessageJobProcessor.expects(:bulk_send_campaign_messages).with([]).once.returns(nil)
    CampaignManagement::CampaignMessageJobProcessor.process
  end

  def test_zza_bulk_send_handle_failure_cases_of_personalized_messages
    campaign_message = cm_campaign_messages(:campaign_message_1)
    jobs = campaign_message.jobs
    student_job = cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_student)

    student_job.user.destroy
    CampaignManagement::CampaignMessageJobProcessor.send(:bulk_send_campaign_messages, jobs)
    student_job.reload
    assert_equal 1, campaign_message.jobs.count
    assert student_job.failed
  end

  def test_user_campaign_mails_footer
    CampaignManagement::UserCampaignMessageJob.last.create_personalized_message
    email = ActionMailer::Base.deliveries.last
    email_content = ActionController::Base.helpers.strip_tags(get_html_part_from(email)).squish
    assert_equal 0, email_content.scan(/This is an automated email/).size
    assert_equal 1, email_content.scan(/Contact Administrator for any questions./).size
  end

  def test_duplicate_message_jobs_handled
    dup = cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_admin).dup
    dup.save(validate: false)

    jobs_with_duplicate = [cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_admin), dup, cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_student),
      cm_campaign_message_jobs(:pending_active_campaign_message_2_job_for_admin), cm_campaign_message_jobs(:pending_active_campaign_message_2_job_for_student),
      cm_campaign_message_jobs(:pending_active_campaign_message_3_job_for_admin), cm_campaign_message_jobs(:pending_active_campaign_message_3_job_for_student),
      cm_campaign_message_jobs(:pending_active_campaign_message_4_job_for_admin), cm_campaign_message_jobs(:pending_active_campaign_message_4_job_for_student)]

    Airbrake.expects(:notify).with("Duplicate Jobs encountered while processing campaign message jobs").times(1)
    jobs_without_duplicate = jobs_with_duplicate - [dup]
    jobs_without_duplicate_actual = CampaignManagement::CampaignMessageJobProcessor.remove_duplicate_pending_jobs(jobs_with_duplicate)
    assert_equal 8, jobs_without_duplicate_actual.count
    assert_equal jobs_without_duplicate, jobs_without_duplicate_actual
  end
end