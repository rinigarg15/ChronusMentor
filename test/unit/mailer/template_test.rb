require_relative './../../test_helper.rb'

class Mailer::TemplateTest < ActiveSupport::TestCase
  def test_validations
    new_mailer = Mailer::Template.new()
    assert_false new_mailer.valid?
    assert_equal ["can't be blank"], new_mailer.errors[:uid]
    assert_equal ["can't be blank"], new_mailer.errors[:program_id]

    announcement_mailer_uid = AnnouncementNotification.mailer_attributes[:uid]
    admin_weekly_status_mailer_uid = AdminWeeklyStatus.mailer_attributes[:uid]

    mailer = Mailer::Template.create!(:program => programs(:org_primary), :uid => admin_weekly_status_mailer_uid)
    new_mailer = Mailer::Template.new(:program => programs(:org_primary), :uid => admin_weekly_status_mailer_uid)
    assert_false new_mailer.valid?
    assert_equal ["has already been taken"], new_mailer.errors[:uid]

    new_mailer = Mailer::Template.new(program: programs(:org_primary), uid: announcement_mailer_uid)
    assert_false new_mailer.is_a_campaign_message_template?
    assert ChronusActionMailer::Base.always_enabled?(new_mailer.uid)
    new_mailer.enabled = false
    assert_false new_mailer.valid?
    assert_equal ["is not included in the list"], new_mailer.errors[:enabled]

    another_new_mailer = Mailer::Template.new(:program => programs(:org_anna_univ), :uid => admin_weekly_status_mailer_uid)
    assert_false another_new_mailer.is_a_campaign_message_template?
    assert_false ChronusActionMailer::Base.always_enabled?(another_new_mailer.uid)
    another_new_mailer.enabled = false
    assert another_new_mailer.valid?

    mailer_template = Mailer::Template.new(:program => programs(:albers), source: "test", subject: "test")
    mailer_template.save
    cm_campaign_messages(:campaign_message_1).email_template = mailer_template
    cm_campaign_messages(:campaign_message_1).save

    assert mailer_template.is_a_campaign_message_template?
    mailer_template.enabled = false
    assert mailer_template.valid?

    mailer_template.source = ""
    mailer_template.subject = ""
    assert_false mailer_template.valid?
    assert_equal ["can't be blank"], mailer_template.errors[:source]
    assert_equal ["can't be blank"], mailer_template.errors[:subject]
    mailer_template.campaign_message_id = nil
    mailer_template.source = ""
    mailer_template.subject = ""
    assert mailer_template.valid?
  end

  def test_belongs_to_campaign_message
    mailer_template = Mailer::Template.new(:program => programs(:albers), source: "test", subject: "test")
    mailer_template.save
    cm_campaign_messages(:campaign_message_1).email_template = mailer_template
    cm_campaign_messages(:campaign_message_1).save!
    assert_equal mailer_template, cm_campaign_messages(:campaign_message_1).email_template
  end

  def test_validation_belongs_to_campaign_message
    mailer_template = Mailer::Template.new(:program => programs(:albers), source: "test", subject: "test")
    mailer_template.campaign_message = cm_campaign_messages(:campaign_message_1)
    assert mailer_template.valid?

    mailer_template = Mailer::Template.new(:program => programs(:albers), source: "test", subject: "test")
    mailer_template.belongs_to_cm = true
    assert mailer_template.valid?
  end

  def test_is_valid_on_disabling_calendar
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    template = program.mailer_templates.last
    assert_nil template.is_valid_on_disabling_calendar
    assert template.is_valid_on_disabling_calendar?
    [:source, :subject].each do |attribute|
      ["number_of_pending_meeting_requests", "meeting_request_acceptance_rate", "meeting_request_average_response_time"].each do |tag|
        template.update_attribute(attribute, "some text {{#{tag}}}")
        assert_false template.is_valid_on_disabling_calendar?
        assert template.valid?
      end
      template.update_attribute(attribute, "some text")
      assert template.is_valid_on_disabling_calendar?
    end
    assert_nil template.is_valid_on_disabling_calendar
  end

  def test_validate_source_tags
    mailer = Mailer::Template.new(:program => programs(:org_primary), :uid => AdminWeeklyStatus.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    #Global tags
    mailer.source = "{{program_name}} {{widget_signature}}"
    mailer.subject = "{{since_time}} {{current_time}}"
    assert mailer.valid?
    #Specific tags
    mailer.source = "{{program_name}} {{invalid_tag}} {{widget_invalid}}"
    mailer.subject = "{{invalid_tag}} {{widget_signature}}"
    assert_false mailer.valid?
    assert_equal ["contains invalid tags - {{invalid_tag}}", "contains invalid widgets - {{widget_invalid}}"], mailer.errors[:source]
    assert_equal ["contains invalid tags - {{invalid_tag}}", "cannot contain widgets - {{widget_signature}}"], mailer.errors[:subject]
  end

  def test_validate_source_tags_for_syntax_error
    mailer = Mailer::Template.new(:program => programs(:org_primary), :uid => AdminWeeklyStatus.mailer_attributes[:uid])
    
    #Global tags
    mailer.source = "{{<b>widget_signature</b>}}"
    assert_false mailer.valid?
    assert_equal ["contains invalid syntax, donot apply any styles within flower braces of the tag"], mailer.errors[:source]

    #Specific tags
    mailer.source = "{{program_name}}"
    mailer.subject = "{{<b>subprogram_name</b>}}"
    assert_false mailer.valid?
    assert_equal ["contains invalid syntax, donot apply any styles to the tags in subject"], mailer.errors[:subject]
  end

  def test_validate_customize_tags_in_db_and_not_in_source
    mailer_template = Mailer::Template.new(:program => programs(:org_primary), :uid => MentorRequestRejected.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    mailer_template.subject = "{{customized_mentor_term}}, {{customized_meeting_term_articleized}}"
    mailer_template.source = "{{customized_admin_term_articleized}}"
    assert mailer_template.valid?
    assert mailer_template.save
  end

  def test_validate_source_and_subject_tags_should_have_valid_syntax
    campaign_message_email_template = cm_campaign_messages(:campaign_message_1).email_template
    campaign_message_email_template.update_attributes(:subject => "Welcome {{user_name}}", :source => "Dear {{user_lastname}}")
    assert campaign_message_email_template.valid?
    #syntax error
    campaign_message_email_template.update_attributes(:subject => "Welcome {{user_name}", :source => "Dear {{user_lastname}}")
    assert_false campaign_message_email_template.valid?
    campaign_message_email_template.update_attributes(:subject => "Welcome {{user_name}}", :source => "Dear {{user_lastname}")
    assert_false campaign_message_email_template.valid?
  end

  def test_validate_source_and_subject_tags_should_have_valid_tags
    campaign_message_email_template = cm_campaign_messages(:campaign_message_1).email_template
    campaign_message_email_template.update_attributes(:subject => "Welcome {{user_name}}", :source => "Dear {{user_lastname}}")
    assert campaign_message_email_template.valid?
    #invalid tag
    campaign_message_email_template.update_attributes(:subject => "Welcome {{user_name}}, have {{invalid_subject_tag}}", :source => "Dear {{invalid_source_tag}}")
    assert_false campaign_message_email_template.valid?
    assert_equal ["contains invalid tags - {{invalid_source_tag}}"], campaign_message_email_template.errors[:source]
    assert_equal ["contains invalid tags - {{invalid_subject_tag}}"], campaign_message_email_template.errors[:subject]
  end

  def test_is_campaign_message_template_should_respond_as_expected
    template = cm_campaign_messages(:campaign_message_1).email_template
    assert template.is_a_campaign_message_template?

    template = Mailer::Template.new(:subject => "Test subject", :source => "Test source")
    assert_false template.is_a_campaign_message_template?

    template.belongs_to_cm = true
    assert template.is_a_campaign_message_template?
  end

  def test_is_campaign_message_template_being_created_now_should_respond_as_expected
    template = Mailer::Template.new(:subject => "Test subject", :source => "Test source")
    assert_false template.is_campaign_message_template_being_created_now?

    template.belongs_to_cm = true
    assert template.is_campaign_message_template_being_created_now?
  end

  def test_get_valid_tags_and_widgets_should_not_call_get_supported_tags_and_widgets_for_newly_created_campaign_message
    template = Mailer::Template.new(:subject => "Test subject", :source => "Test source")
    template.expects(:is_a_campaign_message_template?).returns(true)
    template.expects(:is_campaign_message_template_being_created_now?).returns(true)
    template.expects(:campaign_message).never
    template.send(:source_and_subject_tags)
  end

  def test_get_valid_tags_and_widgets_should_try_to_get_tags_info_for_campaign_message_templates
    template = Mailer::Template.new(:subject => "Test subject", :source => "Test source")
    template.expects(:is_a_campaign_message_template?).returns(true)
    template.expects(:is_campaign_message_template_being_created_now?).returns(false)
    template.campaign_message_id = cm_campaign_messages(:campaign_message_1).id
    
    CampaignManagement::UserCampaign.any_instance.expects(:get_supported_tags_and_widgets).once
    template.send(:source_and_subject_tags)
  end

  def test_validate_tags_and_widgets_through_campaign
    template = Mailer::Template.new(:subject => "Test subject", :source => "Test source")
    CampaignManagement::UserCampaign.any_instance.expects(:get_supported_tags_and_widgets).returns([['a', 'b'], []])
    template.expects(:validate_tags_and_widgets_in_subject_and_source).with(['a', 'b'], []).returns
    template.validate_tags_and_widgets_through_campaign(cm_campaigns(:active_campaign_1).id)
  end

  def test_program_invitaiton_campaign_email_should_always_be_enabled
    uid  = ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]
    assert ChronusActionMailer::Base.always_enabled?(uid)
  end

  def test_enabled_scope
    program = programs(:albers)
    t1 = program.mailer_templates.create(enabled: true, uid: AdminWeeklyStatus.mailer_attributes[:uid])
    t2 = program.mailer_templates.create(enabled: false, uid: DigestV2.mailer_attributes[:uid])

    ids = program.mailer_templates.enabled.pluck(:id)
    assert ids.include?(t1.id)
    assert_false ids.include?(t2.id)
  end

  def test_disabled_scope
    program = programs(:albers)
    t1 = program.mailer_templates.create(enabled: true, uid: AdminWeeklyStatus.mailer_attributes[:uid])
    t2 = program.mailer_templates.create(enabled: false, uid: DigestV2.mailer_attributes[:uid])

    ids = program.mailer_templates.disabled.pluck(:id)
    assert ids.include?(t2.id)
    assert_false ids.include?(t1.id)
  end

  def test_non_campaign_mails_scope
    program = programs(:albers)
    assert program.mailer_templates.pluck(:campaign_message_id).reject{|i| i.nil?}.present?
    assert_false program.mailer_templates.non_campaign_mails.pluck(:campaign_message_id).reject{|i| i.nil?}.present?
  end

  def test_validate_copied_content
    mailer = Mailer::Template.new(program: programs(:org_primary), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: 1000)
    assert_false mailer.valid?

    mailer = Mailer::Template.new(program: programs(:org_primary), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH)
    assert mailer.valid?

    mailer = Mailer::Template.new(program: programs(:org_primary), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::SUBJECT)
    assert mailer.valid?

    mailer = Mailer::Template.new(program: programs(:org_primary), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::SOURCE)
    assert mailer.valid?

    mailer = Mailer::Template.new(program: programs(:org_primary), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: nil)
    assert mailer.valid?
  end

  def test_scope_subject_copied
    mailer1 = Mailer::Template.create!(program: programs(:org_primary), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: nil)
    mailer2 = Mailer::Template.create!(program: programs(:org_primary), uid: UserActivationNotification.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH)
    mailer3 = Mailer::Template.create!(program: programs(:org_primary), uid: DigestV2.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::SUBJECT)
    mailer4 = Mailer::Template.create!(program: programs(:org_primary), uid: UserSuspensionNotification.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::SOURCE)

    mt_ids = Mailer::Template.subject_copied.pluck(:id)
    assert_false mt_ids.include?(mailer1.id)
    assert mt_ids.include?(mailer2.id)
    assert mt_ids.include?(mailer3.id)
    assert_false mt_ids.include?(mailer4.id)
  end

  def test_scope_source_copied
    mailer1 = Mailer::Template.create!(program: programs(:org_primary), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: nil)
    mailer2 = Mailer::Template.create!(program: programs(:org_primary), uid: UserActivationNotification.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH)
    mailer3 = Mailer::Template.create!(program: programs(:org_primary), uid: DigestV2.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::SUBJECT)
    mailer4 = Mailer::Template.create!(program: programs(:org_primary), uid: UserSuspensionNotification.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::SOURCE)

    mt_ids = Mailer::Template.source_copied.pluck(:id)
    assert_false mt_ids.include?(mailer1.id)
    assert mt_ids.include?(mailer2.id)
    assert_false mt_ids.include?(mailer3.id)
    assert mt_ids.include?(mailer4.id)
  end

  def test_scope_both_copied
    mailer1 = Mailer::Template.create!(program: programs(:org_primary), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: nil)
    mailer2 = Mailer::Template.create!(program: programs(:org_primary), uid: UserActivationNotification.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH)
    mailer3 = Mailer::Template.create!(program: programs(:org_primary), uid: DigestV2.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::SUBJECT)
    mailer4 = Mailer::Template.create!(program: programs(:org_primary), uid: UserSuspensionNotification.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::SOURCE)

    mt_ids = Mailer::Template.both_copied.pluck(:id)
    assert_false mt_ids.include?(mailer1.id)
    assert mt_ids.include?(mailer2.id)
    assert_false mt_ids.include?(mailer3.id)
    assert_false mt_ids.include?(mailer4.id)
  end

  def test_subject_copied
    mailer = Mailer::Template.create!(program: programs(:org_primary), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: nil)
    assert_false mailer.subject_copied?

    mailer.update_attribute(:copied_content, Mailer::Template::CopiedContent::BOTH)
    assert mailer.subject_copied?

    mailer.update_attribute(:copied_content, Mailer::Template::CopiedContent::SUBJECT)
    assert mailer.subject_copied?

    mailer.update_attribute(:copied_content, Mailer::Template::CopiedContent::SOURCE)
    assert_false mailer.subject_copied?
  end

  def test_source_copied
    mailer = Mailer::Template.create!(program: programs(:org_primary), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: nil)
    assert_false mailer.source_copied?

    mailer.update_attribute(:copied_content, Mailer::Template::CopiedContent::BOTH)
    assert mailer.source_copied?

    mailer.update_attribute(:copied_content, Mailer::Template::CopiedContent::SUBJECT)
    assert_false mailer.source_copied?

    mailer.update_attribute(:copied_content, Mailer::Template::CopiedContent::SOURCE)
    assert mailer.source_copied?
  end

  def test_update_subject_source_params_if_unchanged
    params = {:mailer_template => {:subject => "Subject", :source => "Source"}, :has_subject_changed => "true", :has_source_changed => "true"}
    Mailer::Template.update_subject_source_params_if_unchanged(params, members(:f_admin))
    assert params[:mailer_template].has_key?(:source)
    assert params[:mailer_template].has_key?(:subject)
    assert_equal params[:mailer_template][:content_changer_member_id], members(:f_admin).id
    assert params[:mailer_template].has_key?(:content_updated_at)

    params = {:mailer_template => {:subject => "Subject", :source => "Source"}, :has_subject_changed => "true", :has_source_changed => "false"}
    Mailer::Template.update_subject_source_params_if_unchanged(params, members(:f_admin))
    assert_false params[:mailer_template].has_key?(:source)
    assert params[:mailer_template].has_key?(:subject)
    assert_equal params[:mailer_template][:content_changer_member_id], members(:f_admin).id
    assert params[:mailer_template].has_key?(:content_updated_at)

    params = {:mailer_template => {:subject => "Subject", :source => "Source"}, :has_subject_changed => "false", :has_source_changed => "true"}
    Mailer::Template.update_subject_source_params_if_unchanged(params, members(:f_admin))
    assert params[:mailer_template].has_key?(:source)
    assert_false params[:mailer_template].has_key?(:subject)

    params = {:mailer_template => {:enabled => false}, :has_subject_changed => "false", :has_source_changed => "true"}
    Mailer::Template.update_subject_source_params_if_unchanged(params, members(:f_admin))
    assert_false params[:mailer_template].has_key?(:subject)
    assert_false params[:mailer_template].has_key?(:content_changer_member_id)
    assert_false params[:mailer_template].has_key?(:content_updated_at)
  end

  def test_add_copied_content_param
    params = {mailer_template: {}}
    assert_equal Mailer::Template.add_copied_content_param(params), params

    params = {mailer_template: {subject: 'something'}}
    assert_equal Mailer::Template.add_copied_content_param(params), {mailer_template: {subject: 'something', copied_content: nil}}

    params = {mailer_template: {source: 'something else'}}
    assert_equal Mailer::Template.add_copied_content_param(params), {mailer_template: {source: 'something else', copied_content: nil}}
  end

  def test_clear_subject_and_content
    program = programs(:albers)
    assert_difference "Mailer::Template.count", 1 do
      assert_difference "Mailer::Template::Translation.count", 1 do
        program.mailer_templates.create!(uid: UserSuspensionNotification.mailer_attributes[:uid], source: "Some Source", subject: "Some Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)
      end
    end
    mt = Mailer::Template.last

    assert_no_difference "Mailer::Template.count" do
      assert_difference "Mailer::Template::Translation.count", -1 do
        mt.clear_subject_and_content(members(:f_admin))
      end
    end

    assert_blank mt.source
    assert_blank mt.subject
    assert_equal members(:f_admin).id, mt.content_changer_member_id
    assert_not_nil mt.content_updated_at
  end

  def test_reset_content_for
    assert_difference "Mailer::Template.count", 7 do
      assert_difference "Mailer::Template::Translation.count", 4 do
        Mailer::Template.create!(program: programs(:albers), uid: AdminWeeklyStatus.mailer_attributes[:uid], copied_content: nil, subject: "Something", source: "Something", enabled: true, :content_changer_member_id => 1, :content_updated_at => Time.now)
        @mailer2 = Mailer::Template.create!(program: programs(:albers), uid: UserSuspensionNotification.mailer_attributes[:uid], copied_content: nil, subject: "Something", source: "Something", enabled: false, :content_changer_member_id => 1, :content_updated_at => Time.now)
        Mailer::Template.create!(program: programs(:albers), uid: UserActivationNotification.mailer_attributes[:uid], copied_content: nil, enabled: true, :content_changer_member_id => 1, :content_updated_at => Time.now)

        Mailer::Template.create!(program: programs(:albers), uid: MentorRequestRejected.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH, subject: "Something", source: "Something", enabled: true, :content_changer_member_id => 1, :content_updated_at => Time.now)
        @mailer6 = Mailer::Template.create!(program: programs(:albers), uid: MentorRequestAccepted.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH, subject: "Something", source: "Something", enabled: false, :content_changer_member_id => 1, :content_updated_at => Time.now)
        Mailer::Template.create!(program: programs(:albers), uid: MembershipRequestAccepted.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH, enabled: true, :content_changer_member_id => 1, :content_updated_at => Time.now)
        Mailer::Template.create!(program: programs(:albers), uid: ProjectRequestRejected.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH, enabled: false, :content_changer_member_id => 1, :content_updated_at => Time.now)
      end
    end

    assert_difference "Mailer::Template.count", -4 do
      assert_difference "Mailer::Template::Translation.count", -4 do
        Mailer::Template.reset_content_for(programs(:albers).mailer_templates.non_campaign_mails)
      end
    end

    assert_blank @mailer2.reload.subject
    assert_blank @mailer2.reload.source
    assert @mailer2.translations.empty?

    assert_blank @mailer6.reload.subject
    assert_blank @mailer6.reload.source
    assert @mailer6.translations.empty?
  end
  
  def test_add_translation_for_existing_mailer_templates
    program = programs(:albers)
    org = program.organization

    t1 = Mailer::Template.create!(:program => program, :uid => ProgramReportAlert.mailer_attributes[:uid], :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)
    t2 = Mailer::Template.create!(:program => org, :uid => MemberSuspensionNotification.mailer_attributes[:uid], :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)

    language = Language.first
    language.update_attribute(:language_name, "es")
    all_mailer_templates = org.mailer_templates

    org.programs.each {|program| all_mailer_templates = all_mailer_templates + program.mailer_templates}
    all_mailer_templates = all_mailer_templates.select{|template| template.campaign_message_id.nil?}
    all_mailer_templates.collect(&:translations).flatten.select{|translation| translation.locale == :"es"}.each{|t| t.destroy}
    Mailer::Template.add_translation_for_existing_mailer_templates(org, language)
    GlobalizationUtils.run_in_locale("es") do
      (all_mailer_templates.first(2) + [t1, t2]).uniq.each do |mailer_template|
        if mailer_template.reload.translation_for(:en, false).nil?
          assert_equal 0, mailer_template.translations.count
        else
          email_hash = ChronusActionMailer::Base.get_descendant(mailer_template.reload.uid).mailer_attributes
          assert_equal email_hash[:subject].call, mailer_template.subject
          assert_equal ChronusActionMailer::Base.default_email_content_from_path(email_hash[:view_path]), mailer_template.source
        end
      end
    end
  end

  def test_change_and_save_templates
    template_class = MeetingRequestStatusAcceptedNotificationToSelf
    default_subject = template_class.mailer_attributes[:subject].call
    default_source = template_class.default_email_content_from_path(template_class.mailer_attributes[:view_path])
    Mailer::Template.create!(uid: template_class.mailer_attributes[:uid], program_id: programs(:albers).id, enabled: false)
    mailer_template = Mailer::Template.where(:uid => template_class.mailer_attributes[:uid]).first
    mailer_template.update_attributes(:source => "some source", :subject => "some subject", :content_changer_member_id => 1, :content_updated_at => Time.now)
    Mailer::Template.where(:uid => template_class.mailer_attributes[:uid]).update_all(:content_changer_member_id => 1, :content_updated_at => Time.now)
    assert_not_equal mailer_template.source, default_source
    assert_not_equal mailer_template.subject, default_subject
    Mailer::Template.change_and_save_templates(template_class)
    mailer_template.reload
    assert_equal mailer_template.source, default_source
    assert_equal mailer_template.subject, default_subject
  end

  def test_content_customized
    program = programs(:albers)
    uid = NewArticleNotification.mailer_attributes[:uid]
    email = ChronusActionMailer::Base.get_descendant(uid)

    mailer_template = program.mailer_templates.find_by(uid: uid)
    mailer_template.subject = "subject"
    mailer_template.source = "content"
    mailer_template.save!
    assert Mailer::Template.content_customized?(mailer_template.program, email)

    mailer_template.subject = "subject"
    mailer_template.save!
    assert_not_equal mailer_template.subject.gsub(/\s+/, ""), email.mailer_attributes[:subject].call.gsub(/\s+/, "")
    assert Mailer::Template.content_customized?(mailer_template.program, email)

    mailer_template.subject = email.mailer_attributes[:subject].call
    mailer_template.source = "content"
    mailer_template.save!
    assert_not_equal mailer_template.source.gsub(/\s+/, ""), email.default_email_content_from_path(email.mailer_attributes[:view_path]).gsub(/\s+/, "")
    assert Mailer::Template.content_customized?(mailer_template.program, email)

    mailer_template.subject = nil
    mailer_template.source = "content"
    mailer_template.save!
    assert_false mailer_template.subject.present?
    assert Mailer::Template.content_customized?(mailer_template.program, email)

    mailer_template.subject = "subject"
    mailer_template.source = nil
    mailer_template.save!
    assert_false mailer_template.source.present?
    assert Mailer::Template.content_customized?(mailer_template.program, email)

    mailer_template.subject = nil
    mailer_template.save!
    assert_false mailer_template.source.present?
    assert_false mailer_template.subject.present?
    assert_false Mailer::Template.content_customized?(mailer_template.program, email)
  end


  def test_enable_mailer_templates_for_uids
    program = programs(:albers)
    email_klasses = [MeetingEditNotification, MeetingEditNotificationToSelf]
    uids = email_klasses.map{|klass| klass.mailer_attributes[:uid]}

    assert_false program.mailer_templates.where(uid: uids).present?

    mt = program.mailer_templates.create!(uid: uids[0], enabled: false)
    Mailer::Template.enable_mailer_templates_for_uids(program, uids)
    assert mt.reload.enabled
    assert_nil program.mailer_templates.find_by(uid: uids[1])
  end

  def test_find_or_initialize_mailer_template_with_default_content
    mailer_template = Mailer::Template.find_or_initialize_mailer_template_with_default_content(programs(:albers), AutoEmailNotification)
    assert_equal "2xw1lphb", mailer_template.uid
    assert_equal "{{message_subject}} - {{mentoring_connection_name}}", mailer_template.subject
    assert_equal "Hi {{receiver_first_name}},<br/><br/>{{message_content}} <br /> <br /> To contact the {{customized_admin_term}}, reply to this e-mail or click <a href='{{url_contact_admin}}'>here</a>.<br/><br/>{{widget_signature}}", mailer_template.source
    assert mailer_template.new_record?
  end
end
