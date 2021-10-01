require_relative './../../test_helper.rb'

class MentoringModel::FacilitationTemplateTest < ActiveSupport::TestCase
  def test_validations
    assert_multiple_errors([{:field => :mentoring_model_id}, {:field => :subject}, {:field => :message}]) do
      MentoringModel::FacilitationTemplate.create!
    end
  end

  def test_translated_fields
    facilitation_template = create_mentoring_model_facilitation_template
    Globalize.with_locale(:en) do
      facilitation_template.subject = "english subject"
      facilitation_template.message = "english message"
      facilitation_template.save!
    end
    Globalize.with_locale(:"fr-CA") do
      facilitation_template.subject = "french subject"
      facilitation_template.message = "french message"
      facilitation_template.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english subject", facilitation_template.subject
      assert_equal "english message", facilitation_template.message
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french subject", facilitation_template.subject
      assert_equal "french message", facilitation_template.message
    end
  end

  def test_program_delegation
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    facilitation_template = create_mentoring_model_facilitation_template
    assert_equal mentoring_model, facilitation_template.mentoring_model
    assert_equal mentoring_model.program, facilitation_template.program
  end

  def test_deliver_to_eligible_recipients
    program = programs(:albers)
    group = groups(:mygroup)
    admin_member = program.admin_users.first.member
    facilitation_template = create_mentoring_model_facilitation_template
    facilitation_template2 = create_mentoring_model_facilitation_template(specific_date: Date.today.to_s, send_on: nil)

    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      facilitation_template.deliver_to_eligible_recipients(group, admin_member)
      facilitation_template2.deliver_to_eligible_recipients(group, admin_member)
    end
    assert_equal program.get_roles([RoleConstants::MENTOR_NAME]), facilitation_template.roles
    mail = ActionMailer::Base.deliveries.last(2)
    assert_equal group.mentors.map(&:email), mail[0].to
    assert_equal "facilitation template subject - #{group.name}", mail[0].subject
    assert_match "facilitation template message", get_html_part_from(mail[0])
    assert_equal group.mentors.map(&:email), mail[1].to
    assert_equal "facilitation template subject - #{group.name}", mail[1].subject
    assert_match "facilitation template message", get_html_part_from(mail[1])
  end

  # def test_deliver_to_eligible_recipients_in_correct_locale
  #   program = programs(:albers)
  #   group = groups(:mygroup)
  #   mentor = group.mentors.first
  #   student = group.students.first
  #   Language.first.update_attribute(:language_name, "fr-CA")
  #   member_language = mentor.member.build_member_language
  #   member_language.language = Language.first
  #   member_language.save!    

  #   admin_member = program.admin_users.first.member
  #   facilitation_template = create_mentoring_model_facilitation_template
  #   facilitation_template.update_attributes(message: "english message", subject: "english subject")
  #   facilitation_template.roles = program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
  #   facilitation_template.save!

  #   Globalize.with_locale(:"fr-CA") { facilitation_template.update_attributes(message: "french message", subject: "french subject") }

  #   assert_difference "ActionMailer::Base.deliveries.size", 2 do
  #     facilitation_template.deliver_to_eligible_recipients(group, admin_member)
  #   end
  #   assert_equal program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]), facilitation_template.roles
  #   mail = ActionMailer::Base.deliveries.last(2)

  #   assert_equal group.students.map(&:email), mail[0].to
  #   assert_equal "english subject - #{group.name}", mail[0].subject
  #   assert_match "english message", get_html_part_from(mail[0])

  #   assert_equal group.mentors.map(&:email), mail[1].to
  #   assert_equal "french subject - #{group.name}", mail[1].subject
  #   assert_match "french message", get_html_part_from(mail[1])
  # end

  def test_deliver_to_eligible_recipients_should_not_resend
    program = programs(:albers)
    group = groups(:mygroup)
    admin_member = program.admin_users.first.member
    facilitation_template_1 = create_mentoring_model_facilitation_template
    facilitation_template_2 = create_mentoring_model_facilitation_template(send_on: 0)
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      facilitation_template_1.deliver_to_eligible_recipients(group, admin_member)
      facilitation_template_2.deliver_to_eligible_recipients(group, admin_member)
    end
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      facilitation_template_1.deliver_to_eligible_recipients(group, admin_member)
      facilitation_template_2.deliver_to_eligible_recipients(group, admin_member)
    end
  end

  def test_deliver_to_eligible_recipients_should_be_program_level
    program = programs(:albers)
    group = groups(:mygroup)
    admin_member = program.admin_users.first.member
    mailer_template = Mailer::Template.new(:program => program, :uid => "2xw1lphb", :subject => "Program level", :content_changer_member_id => 1, :content_updated_at => Time.now)
    mailer_template.save
    programs(:pbe).build_and_save_user!({}, [RoleConstants::STUDENT_NAME], group.members.first.member)
    facilitation_template = create_mentoring_model_facilitation_template
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      facilitation_template.deliver_to_eligible_recipients(group, admin_member)
    end
    assert_equal "Program level", ActionMailer::Base.deliveries.last.subject
  end

  def test_deliver_to_eligible_recipients_fail_safe
    program = programs(:albers)
    group = groups(:mygroup)
    mentor_member = members(:f_mentor)
    admin_member = members(:f_admin)
    facilitation_template = create_mentoring_model_facilitation_template(send_on: 0, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    assert_difference "FacilitationDeliveryLog.count", 2 do
      assert_emails 2 do
        facilitation_template.deliver_to_eligible_recipients(group, admin_member)
      end
    end

    facilitation_template_2 = create_mentoring_model_facilitation_template(send_on: 0, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    mentor_member.first_name = "invalid123"
    mentor_member.save(validate: false)
    Airbrake.expects(:notify).once
    assert_difference "FacilitationDeliveryLog.count", 1 do
      assert_emails 1 do
        facilitation_template_2.deliver_to_eligible_recipients(group.reload, members(:f_admin))
      end
    end
  end

  def test_send_immediately_for_facilitation_messages
    program = programs(:albers)
    group = groups(:mygroup)
    mentoring_model = program.default_mentoring_model
    admin_member = program.admin_users.first.member
    facilitation_template_1 = create_mentoring_model_facilitation_template
    facilitation_template_2 = create_mentoring_model_facilitation_template(send_on: 0)
    assert_equal [facilitation_template_2], mentoring_model.mentoring_model_facilitation_templates.send_immediately
  end

  def test_send_all_members_mail
    program = programs(:albers)
    group = groups(:mygroup)
    admin_member = program.admin_users.first.member
    facilitation_template = create_mentoring_model_facilitation_template(roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      facilitation_template.deliver_to_eligible_recipients(group, admin_member)
    end
    assert_equal ["mkr@example.com", "robert@example.com"], ActionMailer::Base.deliveries.last(2).map{|mail| mail.to}.flatten
  end

  def test_prepare_message
    program = programs(:albers)
    group = groups(:mygroup)
    tasks = []
    admin_member = program.admin_users.first.member
    # Engagement survey
    survey = program.surveys.of_engagement_type.first
    mentoring_model = program.default_mentoring_model
    facilitation_template = create_mentoring_model_facilitation_template(mentoring_model: mentoring_model, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]), message: "Please take a survey: {{engagement_survey_link_#{survey.id}}}, Testing survey with survey link <a href=  '{{engagement_survey_link_#{survey.id}}}'>Test Survey</a>")
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      facilitation_template.deliver_to_eligible_recipients(group, admin_member)
    end
    proper_role_email = ActionMailer::Base.deliveries.last
    assert_match "Please take a survey: #{survey.name}", get_text_part_from(proper_role_email)
    assert_match "/p/albers/surveys/#{survey.id}/edit_answers?group_id=#{group.id}", get_text_part_from(proper_role_email)
    assert_match "Testing survey with survey link Test Survey", get_text_part_from(proper_role_email)
    assert_match /<a href=\".*?\/p\/albers\/surveys\/#{survey.id}\/edit_answers\?group_id=#{group.id}&amp;src=2\".*?\>Test Survey<\/a>/, get_html_part_from(proper_role_email)
  end

  def test_prepare_message_without_href_attribute
    program = programs(:albers)
    group = groups(:mygroup)
    tasks = []
    admin_member = program.admin_users.first.member
    # Engagement survey
    survey = program.surveys.of_engagement_type.first
    mentoring_model = program.default_mentoring_model
    facilitation_template = create_mentoring_model_facilitation_template(mentoring_model: mentoring_model, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]), message: "Please find the link here without href: <a name= 'test'>Test Survey</a>")
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      facilitation_template.deliver_to_eligible_recipients(group, admin_member)
    end
    proper_role_email = ActionMailer::Base.deliveries.last
    assert_match "Please find the link here without href", get_text_part_from(proper_role_email)
    assert_match /Test Survey/, get_html_part_from(proper_role_email)
  end

  def test_compute_due_dates
    program = programs(:albers)
    ft1  = create_mentoring_model_facilitation_template(send_on: 0, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    ft2  = create_mentoring_model_facilitation_template(specific_date: '2014-08-08',send_on: nil, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    ft3  = create_mentoring_model_facilitation_template(send_on: 7, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    MentoringModel::FacilitationTemplate.compute_due_dates([ft1,ft2,ft3])
    assert ft2.due_date < ft1.due_date
    assert ft1.due_date < ft3.due_date
  end

  def test_validation_specific_or_send_on
    program = programs(:albers)
    facilitation_template  = create_mentoring_model_facilitation_template(send_on: 0, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    assert_equal true, facilitation_template.valid?
    facilitation_template.send_on = nil
    assert_equal false, facilitation_template.valid?
    facilitation_template.specific_date = '2014-08-08'
    assert_equal true, facilitation_template.valid?
    assert facilitation_template.save
  end

  def test_valid_survey_ids_from_message
    program = programs(:albers)
    facilitation_template  = create_mentoring_model_facilitation_template(send_on: 0, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    facilitation_template.message = "{{engagement_survey_link_128}} Test for FM validity"
    assert_equal false, facilitation_template.valid?
    survey_id = program.surveys.of_engagement_type.first.id
    facilitation_template.message = "{{engagement_survey_link_#{survey_id}}} Test for FM validity"
    facilitation_template.save!
    assert_equal true, facilitation_template.valid?
  end

  def test_get_engagement_survey_ids_from_message
    program = programs(:albers)
    facilitation_template  = create_mentoring_model_facilitation_template(send_on: 0, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    facilitation_template.message = "{{engagement_survey_link_128}} Test for FM validity"
    assert_equal ["128"], facilitation_template.get_engagement_survey_ids_from_message
  end

  def test_skip_survey_validations_attr_accessor
    program = programs(:albers)
    facilitation_template  = create_mentoring_model_facilitation_template(send_on: 0, roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    facilitation_template.message = "{{engagement_survey_link_128}} Test for FM validity"
    assert_equal false, facilitation_template.valid?
    facilitation_template.skip_survey_validations = true
    assert facilitation_template.valid?
  end

  def test_tags_in_facilitation_email
    program = programs(:albers)
    group = groups(:mygroup)
    admin_member = program.admin_users.first.member
    facilitation_template = create_mentoring_model_facilitation_template(roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]),
      message: "Group Name : {{group_name}}, Connection Area Button : {{mentoring_area_button}}")
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      facilitation_template.deliver_to_eligible_recipients(group, admin_member)
    end
    last_facilitation_email = ActionMailer::Base.deliveries.last
    assert_match "Group Name : #{group.name}", get_text_part_from(last_facilitation_email)
    assert_match "Visit your #{program.return_custom_term_hash[:_mentoring_connection]} area", get_text_part_from(last_facilitation_email)
  end
end