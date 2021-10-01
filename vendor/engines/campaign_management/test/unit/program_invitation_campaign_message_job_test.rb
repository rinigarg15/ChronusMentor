# encoding: utf-8
require_relative './../test_helper'

class ProgramInvitationCampaignMessageJobTest < ActiveSupport::TestCase

  def setup
    super
    program_invitation = program_invitations(:mentor)
    #this @job is first remainder job, as first email was sent immediately
    @job = program_invitation.campaign_jobs.first
    @job.update_attributes(run_at: 5.minutes.ago)
  end

  def test_presence_validations
    job = CampaignManagement::ProgramInvitationCampaignMessageJob.new(program_invitation: nil, campaign_message: nil, run_at: nil)

    assert_false job.valid?
    assert_equal ["can't be blank"], job.errors[:program_invitation]
    assert_equal ["can't be blank"], job.errors[:campaign_message]
    assert_equal ["can't be blank"], job.errors[:run_at]
  end

  def test_create_personalized_message_should_create_email_and_return_true_incase_of_success
    assert_difference "CampaignManagement::CampaignEmail.count", 1 do
      assert_difference "ActionMailer::Base.deliveries.count", 1 do
        assert @job.create_personalized_message
      end
    end
    message = CampaignManagement::CampaignEmail.last
    assert_equal "You have a pending invitation to join Albers Mentor Program", message.subject
    assert_match "A couple of weeks ago I invited you to participate in Albers Mentor Program as a mentor. As of today, I have not heard back from you.", message.source
  end

  def test_create_personalized_message_in_prefered_locale
    @job.program_invitation.program.organization.enable_feature(FeatureName::MOBILE_VIEW, false)
    @job.program_invitation.update_attributes(locale: :de)
    assert_difference "CampaignManagement::CampaignEmail.count", 1 do
      assert_difference "ActionMailer::Base.deliveries.count", 1 do
        assert @job.create_personalized_message
      end
    end

    # checking full mail response here, because we need to check about 5 links that should contain target locale info, campaign tags, language of mail etc
    assert_equal "Hello,\n\nA couple of weeks ago I invited you to participate in Albers\nMentor Program [[ áš ]] a ment\n\nAlbers Mentor Program ( https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/?set_locale=de )\n\nHello,\n\nA couple of weeks ago I invited you to participate in Albers\nMentor Program [[ áš ]] a mentor. As of today, I have not heard\nback from you.\n\nThis is a reminder that your invitation will expire in about 15\ndays.\n\nClick here ( https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/registrations/new?invite_code=#{@job.program_invitation.code}&set_locale=de ) to accept the invitation and sign up for Albers Mentor Program.\nOnce you do that, you can fill out your profile (which we use to\nmatch you up with other participants with similar interests and\ngoals) and participate in the program activities.\n\nI look forward to your participation! If you have any questions,\nplease contact me here ( https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/contact_admin?set_locale=de ).\n\n[[ Łóǧó ]]\n\n[[ Ťĥíš íš áɳ áůťóɱáťéď éɱáíł -\nƿłéášé ďóɳ'ť řéƿłý. ]] [[ [[ Čóɳťáčť Administrator ]] ( https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/contact_admin?set_locale=de&src=email ) ƒóř áɳý ƣůéšťíóɳš. ]]", get_text_part_from(ActionMailer::Base.deliveries.last)
  end

  def test_deliver_email
    campaign_message = @job.campaign_message
    email_template = campaign_message.email_template
    program_invitation = @job.program_invitation
    email = program_invitation.sent_to
    mail_locale = :de
    GlobalizationUtils.run_in_locale(mail_locale) do
      mail = ProgramInvitationCampaignEmailNotification.replace_tags(program_invitation, email_template)
      campaign_email = CampaignManagement::CampaignEmail.create!(:subject => mail[:subject].to_s, :source => mail.body.raw_source.to_s, :campaign_message => campaign_message, :abstract_object_id => program_invitation.id)
      assert_difference "ActionMailer::Base.deliveries.count", 1 do
        CampaignManagement::ProgramInvitationCampaignMessageJob.deliver_email(mail_locale, program_invitation.id, campaign_email.id)
      end
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal "You have a pending invitation to join Albers Mentor Program", mail.subject
    assert_equal ["no-reply@chronus.com"], mail.from
    assert_equal "no-reply@chronus.com", mail.sender
    assert get_html_part_from(mail).match("Čóɳťáčť Administrator").present?
  end

  def test_create_personalized_message_should_raise_airbrake_and_return_false_incase_of_failure
    ProgramInvitationCampaignEmailNotification.expects(:replace_tags).raises
    Airbrake.expects(:notify).returns

    assert_no_difference "CampaignManagement::CampaignEmail.count" do
      assert_no_difference "ActionMailer::Base.deliveries.count" do
        assert_false @job.create_personalized_message
      end
    end
  end

  def test_create_personalized_message_should_replace_tags_as_expected
    template = @job.campaign_message.email_template
    template.source  = "You have been added {{as_role_name_articleized}} by {{invitor_name}}. <a href='{{url_invitation}}'>Click here</a> to accept the invitation. It will expire on {{invitation_expiry_date}}"
    template.save!

    ProgramInvitation.any_instance.expects(:code).returns('ABCDEF')
    ProgramInvitation.any_instance.expects(:expires_on).returns(Time.new(2020, 1, 1))

    assert_difference "CampaignManagement::CampaignEmail.count", 1 do
      assert_difference "ActionMailer::Base.deliveries.count", 1 do
        assert @job.create_personalized_message
      end
    end
    message = CampaignManagement::CampaignEmail.last
    assert_equal "You have a pending invitation to join Albers Mentor Program", message.subject
    assert_match "You have been added as a mentor by Freakin Admin (Administrator).", message.source
  end

  def test_create_personalized_message_should_replace_tags_as_expected_for_program_invitation_campaign_tags
    program = programs(:albers)
    template = @job.campaign_message.email_template
    template.subject = "You are invited to {{subprogram_or_program_name}}"
    template.source  = "You have been added as a {{role_name}} to {{subprogram_or_program_name}}. Further queries contact {{url_contact_admin}}. To visit click {{url_subprogram_or_program}}"
    template.save!

    assert_difference "CampaignManagement::CampaignEmail.count", 1 do
      assert_difference "ActionMailer::Base.deliveries.count", 1 do
        assert @job.create_personalized_message
      end
    end
    message = CampaignManagement::CampaignEmail.last
    assert_equal "You are invited to Albers Mentor Program", message.subject
    assert_match /You have been added as a mentor to #{program.name}/, message.source
    assert_match "https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/contact_admin", message.source
    assert_match "<a href=\"https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/?set_locale=en\">https://#{EMAIL_HOST_SUBDOMAIN}.#{DEFAULT_HOST_NAME}/p/albers/?set_locale=en</a>", message.source
  end

  def test_utf_chars_encoding_in_placeholders_in_the_email
    program = programs(:albers)
    program.name = "Naisa Mentor-Protégé Program"
    program.save!
    campaign_message = program.program_invitation_campaign.campaign_messages.first
    campaign_message.email_template.update_attributes(:subject => "Invitation", :source => "Hello, Join {{subprogram_or_program_name}}")
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
        assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          program.program_invitations.create!(:sent_to => "aaaaa@abc.com", :program => program, :user => users(:f_admin_pbe), :role_names => [RoleConstants::STUDENT_NAME], :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE)
        end
      end
    end

    message = CampaignManagement::CampaignEmail.last
    assert_equal "Invitation", message.subject
    assert_equal "Hello, Join Naisa Mentor-Protégé Program<style>\n</style>", message.source
  end

  def test_create_personalized_message_must_not_deliver_invite_mail_for_existing_program_users
    program_invitation = program_invitations(:mentor)
    program_invitation.sent_to = "robert@example.com"
    program_invitation.save
    #this @job is first reminder job, as first email was sent immediately
    job = program_invitation.campaign_jobs.first
    assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', -2 do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', -1 do
        assert_no_difference "CampaignManagement::CampaignEmail.count" do
          assert_no_difference "ActionMailer::Base.deliveries.count" do
            assert job.create_personalized_message
          end
        end
      end
    end
  end

  def test_set_abstract_object_type
    job = CampaignManagement::ProgramInvitationCampaignMessageJob.create
    assert_equal ProgramInvitation.name, job.abstract_object_type
  end

  def test_process_job_without_invitor
    program = programs(:albers)
    program.name = "Albers & Mentor Program"
    program.save!
    campaign_message = program.program_invitation_campaign.campaign_messages.first
    campaign_message.email_template.update_attributes(subject: "Invitation to join {{subprogram_or_program_name}}", source: "{{invitor_name}}, Hello, Join")
    ProgramInvitation.any_instance.stubs(:is_sender_admin?).returns(true)

    assert_emails 1 do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
        assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          program.program_invitations.create!(
            sent_to: "aaa@abc.com",
            user: nil,
            program: program,
            role_names: [RoleConstants::STUDENT_NAME],
            role_type: ProgramInvitation::RoleType::ASSIGN_ROLE
          )
        end
      end
    end
    message = CampaignManagement::CampaignEmail.last
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Administrator via Albers & Mentor Program <no-reply@chronus.com>", mail[:From].value
    assert_equal "Invitation to join Albers & Mentor Program", mail.subject
    assert_match "Administrator, Hello, Join", message.source
  end
end
