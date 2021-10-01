require_relative './../test_helper.rb'

class RolloutEmailsControllerTest < ActionController::TestCase
  def test_authorization
    program = programs(:albers)
    mt = program.mailer_templates.create!(uid: AdminWeeklyStatus.mailer_attributes[:uid])

    current_member_is :f_mentor

    assert_permission_denied do
      post :rollout_popup, xhr: true, params: { :id => mt.uid, :edit_page => "true"}
    end

    assert_permission_denied do
      put :update_all
    end

    assert_permission_denied do
      post :rollout_keep_current_content, params: { :id => mt.uid}
    end

    assert_permission_denied do
      post :rollout_switch_to_default_content, xhr: true, params: { :id => mt.uid}
    end

    assert_permission_denied do
      put :dismiss_rollout_flash_by_admin
    end

    assert_permission_denied do
      post :rollout_dismiss_popup_by_admin, xhr: true, params: { :id => mt.uid}
    end
  end

  def test_rollout_popup
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    mailer_template = program.mailer_templates.where(:uid => ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]).first
    email = ChronusActionMailer::Base.get_descendant(mailer_template.uid)

    post :rollout_popup, xhr: true, params: { :id => mailer_template.uid, :edit_page => "true"}

    assert_response :success
    assert_equal "true", assigns(:edit_page)
    assert_equal mailer_template, assigns(:mailer_template)
    assert_equal mailer_template.source, assigns(:old_source)
    assert_equal mailer_template.subject, assigns(:old_subject)
    assert_equal email.mailer_attributes[:subject].call, assigns(:new_subject)
    assert_equal email, assigns(:email)
    assert_equal email.default_email_content_from_path(email.mailer_attributes[:view_path]), assigns(:new_source)
  end

  def test_rollout_popup_with_subject_and_source_not_present
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    mailer_template = program.mailer_templates.where(:uid => NewArticleNotification.mailer_attributes[:uid]).first
    mailer_template.subject = nil
    mailer_template.source = nil
    mailer_template.save!
    email = ChronusActionMailer::Base.get_descendant(mailer_template.uid)

    post :rollout_popup, xhr: true, params: { :id => mailer_template.uid, :edit_page => "true"}

    assert_response :success
    assert_equal "true", assigns(:edit_page)
    assert_equal mailer_template, assigns(:mailer_template)
    assert_nil mailer_template.source
    assert_nil mailer_template.subject
    assert_not_equal mailer_template.source, assigns(:old_source)
    assert_not_equal mailer_template.subject, assigns(:old_subject)
    assert_equal assigns(:old_source), assigns(:new_source)
    assert_equal assigns(:old_subject), assigns(:new_subject)
    assert_equal email.mailer_attributes[:subject].call, assigns(:new_subject)
    assert_equal email, assigns(:email)
    assert_equal email.default_email_content_from_path(email.mailer_attributes[:view_path]), assigns(:new_source)
  end

  def test_update_all
    current_user_is :f_admin
    program = programs(:albers)
    program.mailer_templates.destroy_all
    t0 = program.organization.mailer_templates.create!(enabled: true, source: 'org level', subject: 'org level', uid: MemberSuspensionNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    t1 = program.mailer_templates.create(enabled: false, source: 'Old', subject: 'Old', uid: UserActivationNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    t2 = program.mailer_templates.create(enabled: true, source: 'Old', subject: 'Old', uid: UserSuspensionNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    t3 = program.mailer_templates.create(enabled: true, source: 'Old', subject: 'Old', uid: MembershipRequestNotAccepted.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH, :content_changer_member_id => 1, :content_updated_at => Time.now)
    t0.translations.create!(subject: 'Old Fr', source: 'Old Fr', locale: "fr-CA")
    t1.translations.create!(subject: 'Old Fr', source: 'Old Fr', locale: "fr-CA")
    t2.translations.create!(subject: 'Old Fr', source: 'Old Fr', locale: "fr-CA")

    assert_difference "Mailer::Template::Translation.count", -5 do
      assert_difference "Mailer::Template.count", -2 do
        assert_difference "RolloutEmail.count", 1 do
          put :update_all
        end
      end
    end
    assert_equal "You have successfully updated all your emails to the new content", flash[:notice]
    t1.reload
    assert_blank t1.subject
    assert_blank t1.source

    t0.reload
    assert_equal "org level", t0.subject
    assert_equal "org level", t0.source

    re = RolloutEmail.last
    assert_equal re.action_type, RolloutEmail::ActionType::UPDATE_ALL
  end

  def test_update_all_standalone
    current_user_is :foster_admin
    program = programs(:foster)
    program.mailer_templates.destroy_all
    t0 = program.organization.mailer_templates.create!(enabled: true, source: 'org level', subject: 'org level', uid: MemberSuspensionNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    t1 = program.mailer_templates.create(enabled: false, source: 'Old', subject: 'Old', uid: UserActivationNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    t2 = program.mailer_templates.create(enabled: true, source: 'Old', subject: 'Old', uid: UserSuspensionNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    t3 = program.mailer_templates.create(enabled: true, source: 'Old', subject: 'Old', uid: MembershipRequestNotAccepted.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH, :content_changer_member_id => 1, :content_updated_at => Time.now)
    t0.translations.create!(subject: 'Old Fr', source: 'Old Fr', locale: "fr-CA")
    t1.translations.create!(subject: 'Old Fr', source: 'Old Fr', locale: "fr-CA")
    t2.translations.create!(subject: 'Old Fr', source: 'Old Fr', locale: "fr-CA")

    assert_difference "Mailer::Template::Translation.count", -7 do
      assert_difference "Mailer::Template.count", -3 do
        put :update_all
      end
    end
    assert_equal "You have successfully updated all your emails to the new content", flash[:notice]
    t1.reload
    assert_blank t1.subject
    assert_blank t1.source
  end

  def test_update_all_non_customized
    current_user_is :f_admin
    program = programs(:albers)
    program.mailer_templates.destroy_all
    t1 = program.mailer_templates.create(enabled: false, source: 'Old', subject: 'Old', uid: UserActivationNotification.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH, :content_changer_member_id => 1, :content_updated_at => Time.now)
    t2 = program.mailer_templates.create(enabled: true, source: 'Old', subject: 'Old', uid: UserSuspensionNotification.mailer_attributes[:uid], :content_changer_member_id => 1, :content_updated_at => Time.now)
    t3 = program.mailer_templates.create(enabled: true, source: 'Old', subject: 'Old', uid: MembershipRequestNotAccepted.mailer_attributes[:uid], copied_content: Mailer::Template::CopiedContent::BOTH, :content_changer_member_id => 1, :content_updated_at => Time.now)
    t1.translations.create!(subject: 'Old Fr', source: 'Old Fr', locale: "fr-CA")
    t2.translations.create!(subject: 'Old Fr', source: 'Old Fr', locale: "fr-CA")

    assert_difference "Mailer::Template::Translation.count", -3 do
      assert_difference "Mailer::Template.count", -1 do
        assert_difference "RolloutEmail.count", 1 do
          put :update_all, params: { non_customized: true}
        end
      end
    end
    assert_equal "You have successfully updated all the emails you have not previously customized to the new content", flash[:notice]
    t1.reload
    assert_blank t1.subject
    assert_blank t1.source

    re = RolloutEmail.last
    assert_equal re.action_type, RolloutEmail::ActionType::UPDATE_ALL_NON_CUSTOMIZED
  end

  def test_rollout_keep_current_content_from_edit_page
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    mailer_template = program.mailer_templates.where(:uid => ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]).first

    assert_difference "RolloutEmail.count", +1 do
      post :rollout_keep_current_content, xhr: true, params: { :id => mailer_template.uid}
      assert_response :success
      assert_blank response.body
    end

    re = RolloutEmail.last
    assert_equal re.action_type, RolloutEmail::ActionType::KEEP_CURRENT_CONTENT
  end

  def test_rollout_keep_current_content_from_index_page
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    mailer_template = program.mailer_templates.where(:uid => ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]).first

    assert_difference "RolloutEmail.count", +1 do
      post :rollout_keep_current_content, params: { :id => mailer_template.uid}
      assert_redirected_to edit_mailer_template_path(mailer_template.uid)
    end
  end

  def test_rollout_switch_to_default_content_with_enabled_mail
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    uid = ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]
    mailer_template = program.mailer_templates.where(:uid => uid).first
    assert mailer_template.enabled

    assert_difference "RolloutEmail.count", +1 do
      assert_difference "Mailer::Template.count", -1 do
        post :rollout_switch_to_default_content, xhr: true, params: { :id => mailer_template.uid}
      end
    end
    
    assert_equal mailer_template, assigns(:mailer_template)
    assert_equal mailer_template.uid, assigns(:uid)
    assert_redirected_to edit_mailer_template_path(uid)

    re = RolloutEmail.last
    assert_equal re.action_type, RolloutEmail::ActionType::SWITCH_TO_DEFAULT_CONTENT
  end

  def test_rollout_switch_to_default_content_with_disabled_mail
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    uid = NewArticleNotification.mailer_attributes[:uid]
    mailer_template = program.mailer_templates.where(:uid => uid).first
    mailer_template.enabled = false
    mailer_template.source = "test"
    mailer_template.subject = "test"
    mailer_template.save
    assert_not_equal mailer_template.subject, nil
    assert_not_equal mailer_template.source, nil

    assert_false mailer_template.enabled

    assert_difference "RolloutEmail.count", +1 do
      post :rollout_switch_to_default_content, xhr: true, params: { :id => mailer_template.uid}
    end
    
    mailer_template.reload
    assert_blank mailer_template.subject
    assert_blank mailer_template.source
    assert_equal mailer_template, assigns(:mailer_template)
    assert_equal mailer_template.uid, assigns(:uid)
    assert_redirected_to edit_mailer_template_path(uid)
  end

  def test_dismiss_rollout_flash_by_admin
    current_user_is :f_admin

    assert_equal [], users(:f_admin).dismissed_rollout_emails
    assert_equal [], members(:f_admin).dismissed_rollout_emails

    assert_difference "RolloutEmail.count", 1 do
      put :dismiss_rollout_flash_by_admin, xhr: true
    end

    assert_nil users(:f_admin).reload.dismissed_rollout_emails.last.email_id
    assert_equal [], members(:f_admin).reload.dismissed_rollout_emails
  end

  def test_dismiss_rollout_flash_by_admin_for_standalone
    current_user_is :foster_admin

    assert_equal [], users(:foster_admin).dismissed_rollout_emails
    assert_equal [], members(:foster_admin).dismissed_rollout_emails

    assert_difference "RolloutEmail.count", 2 do
      put :dismiss_rollout_flash_by_admin, xhr: true
    end

    assert_nil users(:foster_admin).reload.dismissed_rollout_emails.last.email_id
    assert_nil members(:foster_admin).reload.dismissed_rollout_emails.last.email_id
  end

  def test_rollout_dismiss_popup_by_admin
    current_user_is :f_admin
    login_as_super_user

    uid = UserSuspensionNotification.mailer_attributes[:uid]

    assert_difference "RolloutEmail.count", +1 do
      post :rollout_dismiss_popup_by_admin, xhr: true, params: { :id => uid}
    end

    assert_redirected_to edit_mailer_template_path(uid)

    assert_equal uid, users(:f_admin).reload.dismissed_rollout_emails.last.email_id
    assert_equal [], members(:f_admin).reload.dismissed_rollout_emails
  end

  def test_rollout_dismiss_popup_by_admin_for_standalone
    current_user_is :foster_admin

    assert_equal [], users(:foster_admin).dismissed_rollout_emails
    assert_equal [], members(:foster_admin).dismissed_rollout_emails

    uid = MemberSuspensionNotification.mailer_attributes[:uid]

    assert_difference "RolloutEmail.count", 1 do
      post :rollout_dismiss_popup_by_admin, xhr: true, params: { :id => uid}
    end

    assert_redirected_to edit_mailer_template_path(uid)

    assert_equal [], users(:foster_admin).reload.dismissed_rollout_emails
    assert_equal uid, members(:foster_admin).reload.dismissed_rollout_emails.last.email_id
  end
end