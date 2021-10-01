require_relative './../test_helper'

class SurveyCampaignTest < ActiveSupport::TestCase
  def test_belongs_o_survey
    campaign = CampaignManagement::SurveyCampaign.first
  end

  def test_belongs_to_program
    campaign = CampaignManagement::SurveyCampaign.first
  end

  def test_has_many_campaign_messages
    campaign = CampaignManagement::SurveyCampaign.first
    assert_equal 2, campaign.campaign_messages.count
    assert_difference "CampaignManagement::SurveyCampaignMessage.count", -2 do
      campaign.destroy
    end
  end

  def test_has_many_statuses
    survey = surveys(:two)
    campaign = survey.campaign
    create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 10.days)
    assert_equal 0, campaign.statuses.count

    campaign.process!
    assert_equal 1, campaign.reload.statuses.count
  end

  def test_has_many_campaign_message_analyticss
    survey = surveys(:two)
    campaign = survey.campaign
    campaign_message = campaign.campaign_messages.first
    assert_equal 0, campaign.campaign_message_analyticss.count
    campaign_message.campaign_message_analyticss.create!(year_month: '200401', event_type: CampaignManagement::EmailEventLog::Type::OPENED)
    assert_equal 1, campaign.reload.campaign_message_analyticss.count
  end

  def test_has_many_jobs
    survey = surveys(:two)
    campaign = survey.campaign
    create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 2.days)
    assert_equal 0, campaign.jobs.count

    campaign.process!
    assert_equal 2, campaign.reload.jobs.count
  end

  def test_email_template_association
    campaign = CampaignManagement::SurveyCampaign.first
    assert_equal_unordered campaign.campaign_messages.collect(&:email_template), campaign.email_templates
  end

  def test_has_many_emails
    survey = surveys(:two)
    campaign = survey.campaign
    campaign_message = campaign.campaign_messages.first
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 10.days)
    assert_equal 0, campaign.emails.count

    campaign_email = CampaignManagement::CampaignEmail.create!(:subject => "subject", :source => "Source", :campaign_message => campaign_message, :abstract_object_id => task.id)
    assert_equal [campaign_email.id], campaign.emails.pluck(:id)
  end

  def test_ref_obj_id_presence
    campaign = CampaignManagement::SurveyCampaign.new(program_id: programs(:albers).id)
    campaign.save
    assert_equal ["can't be blank"], campaign.errors[:ref_obj_id]
  end

  def test_set_enabled_at
    s = programs(:albers).surveys.of_program_type.first
    Timecop.freeze(Time.now.change(usec: 0)) do
      campaign = s.create_campaign(program_id: s.program_id, title: "Something")
      assert_equal Time.now, campaign.enabled_at
    end
  end

  def test_campaign_email_tags
    tags = ChronusActionMailer::Base.mailer_attributes[:tags]
    sc_tags = EngagementSurvey.first.campaign.campaign_email_tags
    expected_tags = [tags[:engagement_survey_campaign_tags], tags[:global_tags], tags[:subprogram_tags]].inject(&:merge)
    assert_equal expected_tags, sc_tags

    mc_tags = MeetingFeedbackSurvey.first.campaign.campaign_email_tags
    expected_tags = [tags[:meeting_feedback_survey_campaign_tags], tags[:global_tags], tags[:subprogram_tags]].inject(&:merge)
    assert_equal expected_tags, mc_tags
  end

  def test_build_message
    campaign = CampaignManagement::SurveyCampaign.new(program_id: programs(:albers).id)
    assert_no_difference "CampaignManagement::SurveyCampaignMessage.count" do
      assert_no_difference "Mailer::Template.count" do
        campaign.build_message("subject", "body", 100)
      end
    end
    cm = campaign.campaign_messages.last
    template = cm.email_template
    assert_equal "subject", template.subject
    assert_equal "body", template.source
    assert_equal campaign.program_id, template.program_id
    assert template.belongs_to_cm
    assert_equal 100, cm.duration
  end

  def test_process
    survey = surveys(:two)
    campaign = survey.campaign

    Timecop.freeze do
      current_date = Time.now.utc.to_date
      task1 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: current_date - 1.days)
      task2 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: current_date - 2.days)
      task3 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: current_date + 2.days)

      assert_difference "CampaignManagement::SurveyCampaignStatus.count", 2 do
        assert_difference "CampaignManagement::SurveyCampaignMessageJob.count", 4 do
          campaign.process!
        end
      end
      assert_equal [task1.id, task2.id], CampaignManagement::SurveyCampaignStatus.last(2).collect(&:abstract_object_id)
      assert_equal [task1.due_date.to_i, task2.due_date.to_i], CampaignManagement::SurveyCampaignStatus.last(2).collect(&:started_at).collect(&:to_i)
      assert_equal [task1.id, task2.id, task1.id, task2.id], CampaignManagement::SurveyCampaignMessageJob.last(4).collect(&:abstract_object_id)
      task1.update_attribute(:due_date, 2.days.ago)
      task2.update_attribute(:due_date, 2.days.from_now)
      task3.update_attribute(:due_date, 6.days.ago)

      assert_difference "CampaignManagement::SurveyCampaignStatus.count", 0 do
        assert_difference "CampaignManagement::SurveyCampaignMessageJob.count", -1 do
          campaign.process!
        end
      end
      assert_equal [task1.id, task3.id], CampaignManagement::SurveyCampaignStatus.last(2).collect(&:abstract_object_id)
      assert_equal [task1.due_date.to_i, task3.due_date.to_i], CampaignManagement::SurveyCampaignStatus.last(2).collect(&:started_at).collect(&:to_i)
      assert_equal [task1.id, task1.id, task3.id], CampaignManagement::SurveyCampaignMessageJob.last(3).collect(&:abstract_object_id)

      assert_no_difference "CampaignManagement::SurveyCampaignStatus.count" do
        assert_no_difference "CampaignManagement::SurveyCampaignMessageJob.count" do
          campaign.reload.process!
        end
      end

      meeting_survey = programs(:albers).get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
      campaign = meeting_survey.campaign
      meeting = create_meeting(force_non_group_meeting: true)
      meeting.meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED, skip_meeting_update: true)
      assert_difference "CampaignManagement::SurveyCampaignStatus.count", 4 do
        assert_difference "CampaignManagement::SurveyCampaignMessageJob.count", 2 do
          campaign.reload.process!
        end
      end

      meeting.update_attributes(start_time: 3.days.ago, end_time: 3.days.ago + 30.minutes)
      assert_difference "CampaignManagement::SurveyCampaignStatus.count", 0 do
        assert_difference "CampaignManagement::SurveyCampaignMessageJob.count", -1 do
          campaign.reload.process!
        end
      end

      assert_no_difference "CampaignManagement::SurveyCampaignStatus.count" do
        assert_no_difference "CampaignManagement::SurveyCampaignMessageJob.count" do
          campaign.reload.process!
        end
      end
    end
  end

  def test_for_engagement_survey
    survey = surveys(:two)
    campaign = survey.campaign
    assert campaign.for_engagement_survey?

    Survey.any_instance.stubs(:engagement_survey?).returns(false)
    assert_false campaign.for_engagement_survey?
  end

  def test_abstract_object_klass
    survey = surveys(:two)
    campaign = survey.campaign
    assert_equal MentoringModel::Task, campaign.abstract_object_klass

    Survey.any_instance.stubs(:engagement_survey?).returns(false)
    assert_equal MemberMeeting, campaign.abstract_object_klass
  end
end