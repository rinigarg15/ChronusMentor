require_relative './../test_helper'

class SurveyCampaignMessageJobTest < ActiveSupport::TestCase
  def setup
    super
    @survey = surveys(:two)
    @task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: @survey.id, required: true, due_date: Date.today - 9.days)
    @campaign = @survey.campaign
    @campaign_message = @campaign.campaign_messages.first
    @job = CampaignManagement::SurveyCampaignMessageJob.create!(abstract_object_id: @task.id, abstract_object_type: MentoringModel::Task.name, campaign_message_id: @campaign_message.id, run_at: 5.minutes.ago)
    @msurvey = programs(:albers).get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
    @mcampaign = @msurvey.campaign
    @mcampaign_message = @mcampaign.campaign_messages.first
    @meeting = create_meeting
    @mm = @meeting.member_meetings.first
    @mm_job = CampaignManagement::SurveyCampaignMessageJob.create!(abstract_object_id: @mm.id, abstract_object_type: MemberMeeting.name, campaign_message_id: @mcampaign_message.id, run_at: 5.minutes.ago)
  end

  def test_belongs
    assert_equal @task, @job.abstract_object
    assert_equal @campaign_message, @job.campaign_message

    assert_equal @mm, @mm_job.abstract_object
  end

  def test_validations
    job = CampaignManagement::SurveyCampaignMessageJob.new(abstract_object_id: nil, campaign_message_id: CampaignManagement::SurveyCampaignMessage.first.id, run_at: nil)

    assert_false job.valid?
    assert job.errors.has_key?(:abstract_object_id)
    assert_false job.errors.has_key?(:abstract_object_type)
    assert_false job.errors.has_key?(:campaign_message)
    assert job.errors.has_key?(:run_at)
  end

  def test_can_send_email
    @job.abstract_object = @task
    @task.stubs(:can_send_campaign_email?).returns(false)
    assert_false @job.can_send_email?

    @task.stubs(:can_send_campaign_email?).returns(true)
    assert @job.can_send_email?

    @task.destroy
    assert_false @job.reload.can_send_email?

    @mm_job.abstract_object = @mm
    @mm.stubs(:can_send_campaign_email?).returns(true)
    assert @mm_job.can_send_email?

    @mm.stubs(:can_send_campaign_email?).returns(false)
    assert_false @mm_job.can_send_email?
  end

  def test_deliver_email
    ce = CampaignManagement::CampaignEmail.create!(:subject => 'sub', :source => 'body', :campaign_message => @campaign_message, :abstract_object_id => @task.id)
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      CampaignManagement::SurveyCampaignMessageJob.deliver_email(@task.id, users(:f_admin).id, ce.id, @survey)
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal "sub", mail.subject
    assert_match /body/, mail.text_part.body.decoded
    assert_equal [users(:f_admin).email], mail.to

    CampaignManagement::SurveyCampaign.any_instance.stubs(:abstract_object_klass).returns(MemberMeeting)
    Push::Base.expects(:queued_notify).with(PushNotification::Type::MEETING_FEEDBACK_REQUEST, @mm, user_id: users(:f_admin).id, current_occurrence_time: @meeting.occurrences.first, content: "sub").once
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      CampaignManagement::SurveyCampaignMessageJob.deliver_email(@mm.id, users(:f_admin).id, ce.id, @survey)
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal "sub", mail.subject
    assert_match /body/, mail.text_part.body.decoded
    assert_equal [users(:f_admin).email], mail.to
  end

  def test_create_personalized_message
    Language.stubs(:for_member).returns(:de)
    mt = programs(:albers).customized_terms.find_by(term_type: CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    mt.translations.create!(locale: "de", term: "de-Mentoring Connection", term_downcase: "de-mentoring connection", pluralized_term: "de-Mentoring Connections", pluralized_term_downcase: "de-mentoring connections", articleized_term: "de-a Mentoring Connection", articleized_term_downcase: "de-a mentoring connection")

    assert_difference "CampaignManagement::CampaignEmail.count", 1 do
      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        @job.create_personalized_message
      end
    end

    ce = CampaignManagement::CampaignEmail.last
    assert_equal @task.id, ce.abstract_object_id
    assert_equal @campaign_message.id, ce.campaign_message_id

    mail = ActionMailer::Base.deliveries.last
    assert_equal [@task.user.email], mail.to

    assert_match /Ťĥíš íš áɳ áůťóɱáťéď éɱáíł/, mail.text_part.body.decoded
    assert_match /Hi Good unique/, mail.text_part.body.decoded
    assert_match "p/albers/surveys/#{@survey.id}/edit_answers?src=2&task_id=#{@task.id}", mail.text_part.body.decoded
    assert_match "button-large", mail.html_part.body.decoded
    assert_equal "How is your de-mentoring connection?", mail.subject

    @mm_job.abstract_object = @mm
    @mm_job.stubs(:can_send_email?).returns(true)
    assert_difference "CampaignManagement::CampaignEmail.count", 1 do
      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        @mm_job.create_personalized_message
      end
    end

    ce = CampaignManagement::CampaignEmail.last
    mail = ActionMailer::Base.deliveries.last
    assert_equal [@mm.user.email], mail.to
    assert_equal @mm.id, ce.abstract_object_id
    assert_equal @mcampaign_message.id, ce.campaign_message_id
    assert_match /Ťĥíš íš áɳ áůťóɱáťéď éɱáíł/, mail.text_part.body.decoded
    assert_match /Hi Good unique/, mail.text_part.body.decoded
    assert_match "p/albers/surveys/#{@msurvey.id}/participate?meeting_occurrence_time=", mail.text_part.body.decoded
    assert_match "&member_meeting_id=#{@mm.id}&src=2", mail.text_part.body.decoded
    assert_equal "The meeting time has passed. Your input is needed!", mail.subject
  end

  def test_set_abstract_object_type
    job = CampaignManagement::SurveyCampaignMessageJob.create(campaign_message_id: @campaign_message.id)
    assert_equal MentoringModel::Task.name, job.abstract_object_type

    job = CampaignManagement::SurveyCampaignMessageJob.create(campaign_message_id: @mcampaign_message.id)
    assert_equal MemberMeeting.name, job.abstract_object_type
  end
end
