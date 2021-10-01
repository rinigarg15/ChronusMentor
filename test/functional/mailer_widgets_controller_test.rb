require_relative './../test_helper.rb'

class MailerWidgetsControllerTest < ActionController::TestCase

  def test_authorization
    current_member_is :f_mentor

    assert_permission_denied do
      get :edit, params: { :id => WidgetSignature.widget_attributes[:uid]}
    end
  end

  def test_authorization_subprogram
    current_user_is :ram

    assert_false users(:ram).member.admin?

    get :edit, params: { :id => WidgetSignature.widget_attributes[:uid]}
    assert_response :success
  end

  def test_edit
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]

    get :edit, params: { :id => uid}
    assert_response :success
    assert_equal uid, assigns(:uid)
    assert_equal_hash WidgetSignature.widget_attributes, assigns(:widget_hash)
    assert assigns(:all_tags)
    assert_false assigns(:enable_update)
    assert assigns(:mailer_widget).new_record?
    assert_equal uid, assigns(:mailer_widget).uid
    assert_equal programs(:org_primary), assigns(:mailer_widget).program
    assert_equal WidgetSignature.default_template, assigns(:mailer_widget).source
  end

  def test_edit_with_super_user
    login_as_super_user
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]

    get :edit, params: { :id => uid}
    assert_response :success
    assert assigns(:enable_update)
  end

  def test_edit_with_customize_emails_enabled
    p = programs(:org_primary)
    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, true)
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]

    get :edit, params: { :id => uid}
    assert_response :success
    assert assigns(:enable_update)
  end

  def test_edit_existing
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]
    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely")
    swidget = Mailer::Widget.create!(:program => programs(:albers), :uid => uid, :source => "Thank you,")

    get :edit, params: { :id => uid}
    assert_response :success
    assert_equal uid, assigns(:uid)
    assert_equal_hash WidgetSignature.widget_attributes, assigns(:widget_hash)
    assert assigns(:all_tags)
    assert_false assigns(:mailer_widget).new_record?
    assert_equal widget.id, assigns(:mailer_widget).id
    assert_equal uid, assigns(:mailer_widget).uid
    assert_equal "Yours sincerely", assigns(:mailer_widget).source
  end

  def test_edit_existing_subprogram
    current_user_is :f_admin

    uid = WidgetSignature.widget_attributes[:uid]
    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely")
    swidget = Mailer::Widget.create!(:program => programs(:albers), :uid => uid, :source => "Thank you,")

    get :edit, params: { :id => uid}
    assert_response :success
    assert_equal uid, assigns(:uid)
    assert_equal_hash WidgetSignature.widget_attributes, assigns(:widget_hash)
    assert assigns(:all_tags)
    assert_false assigns(:mailer_widget).new_record?

    assert_equal swidget.id, assigns(:mailer_widget).id

    assert_equal uid, assigns(:mailer_widget).uid
    assert_equal "Thank you,", assigns(:mailer_widget).source
  end

  def test_create_failure
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]

    assert_no_difference "Mailer::Widget.count" do
      post :create, params: { :mailer_widget => {:uid => uid, :source => "{{invalid_tag}}"}}
    end

    assert_false assigns(:mailer_widget).valid?
    assert_response :success
    assert_equal_hash WidgetSignature.widget_attributes, assigns(:widget_hash)
    assert assigns(:all_tags)
  end

  def test_create_success_in_default_locale
    programs(:org_primary).organization_languages.last.destroy
    programs(:org_primary).languages.first.update_column(:language_name, "fr-CA")

    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]

    assert_difference "Mailer::Widget.count" do
      post :create, params: { :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}"}}
    end

    widget = Mailer::Widget.last
    assert_equal programs(:org_primary), widget.program
    assert_redirected_to mailer_templates_path()
    assert_equal "Yours sincerely<br/> {{program_name}}", widget.source
    assert_equal "The widget has been successfully updated", flash[:notice]
    assert_equal 2, widget.translations.count
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_equal WidgetSignature.default_template, widget.source
    end
  end

  def test_create_success_in_other_locale
    programs(:org_primary).organization_languages.last.destroy
    programs(:org_primary).languages.first.update_column(:language_name, "fr-CA")

    default_signature_en = WidgetSignature.default_template
    Language.set_for_member(members(:f_admin), :"fr-CA")
    current_member_is :f_admin

    uid = WidgetSignature.widget_attributes[:uid]
    assert_difference "Mailer::Widget.count" do
      post :create, params: { :mailer_widget => {:uid => uid, :source => "in french {{program_name}}"}}
    end

    widget = Mailer::Widget.last
    assert_equal programs(:org_primary), widget.program
    assert_redirected_to mailer_templates_path()

    assert_equal "flash_message.mailer_template_flash.widget_update_success".translate(:locale => "fr-CA"), flash[:notice]
    assert_equal 2, widget.translations.count
    assert_equal "in french {{program_name}}", widget.translation_for("fr-CA").source
    assert_equal default_signature_en, widget.translation_for("en").source
  end

  def test_create_success_with_vulnerable_content_with_version_v1
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      assert_difference "Mailer::Widget.count" do
        post :create, params: { :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}<script>alert(10);</script>"}}
      end
    end
  end

  def test_create_success_with_vulnerable_content_with_version_v2
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      assert_difference "Mailer::Widget.count" do
        post :create, params: { :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}<script>alert(10);</script>"}}
      end
    end
  end

  def test_create_success_subprogram
    programs(:albers).organization.organization_languages.destroy_all
    current_user_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]

    assert_difference "Mailer::Widget.count" do
      post :create, params: { :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}"}}
    end

    assert_equal "Yours sincerely<br/> {{program_name}}", Mailer::Widget.last.source
    assert_equal programs(:albers), Mailer::Widget.last.program
    assert_redirected_to mailer_templates_path()
    assert_equal "The widget has been successfully updated", flash[:notice]
  end

  def test_update_failure
    login_as_super_user
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]
    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely")

    assert_no_difference "Mailer::Widget.count" do
      post :update, params: { :id => widget.id, :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{invalid_tag}}"}}
    end

    assert_false assigns(:mailer_widget).valid?
    assert_response :success
    assert_equal_hash WidgetSignature.widget_attributes, assigns(:widget_hash)
    assert assigns(:all_tags)
  end

  def test_update_failure_with_feature_enabled
    p = programs(:org_primary)
    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, true)
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]
    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely")

    assert_no_difference "Mailer::Widget.count" do
      post :update, params: { :id => widget.id, :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{invalid_tag}}"}}
    end

    assert_false assigns(:mailer_widget).valid?
    assert_response :success
    assert_equal_hash WidgetSignature.widget_attributes, assigns(:widget_hash)
    assert assigns(:all_tags)
  end

  def test_update_success
    programs(:org_primary).organization_languages.last.destroy
    programs(:org_primary).languages.first.update_column(:language_name, "fr-CA")

    login_as_super_user    
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]
    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely")
    Globalize.with_locale("fr-CA") do
      widget.update_attributes(source: "Yours sincerely fr-CA")
    end

    assert_no_difference "Mailer::Widget.count" do
      post :update, params: { :id => widget.id, :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}"}}
    end
    assert_redirected_to mailer_templates_path()
    assert_equal "The widget has been successfully updated", flash[:notice]
    assert_equal 2, widget.translations.count
    assert_equal "Yours sincerely<br/> {{program_name}}", widget.reload.source
    assert_equal "Yours sincerely<br/> {{program_name}}", widget.translation_for("en").source
    assert_equal "Yours sincerely fr-CA", widget.translation_for("fr-CA").source
  end

  def test_update_success_in_other_locale
    programs(:org_primary).organization_languages.last.destroy
    programs(:org_primary).languages.first.update_column(:language_name, "fr-CA")
    uid = WidgetSignature.widget_attributes[:uid]
    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely")
    Globalize.with_locale("fr-CA") do
      widget.update_attributes(source: "Yours sincerely fr-CA")
    end

    login_as_super_user    
    Language.set_for_member(members(:f_admin), :"fr-CA")
    current_member_is :f_admin

    I18n.backend.store_translations("fr-CA", {tab_constants: {sub_tabs: {executive_dashboard: "Executive Dashboard fr-CA"}}})
    assert_no_difference "Mailer::Widget.count" do
      post :update, params: { :id => widget.id, :mailer_widget => {:uid => uid, :source => "Yours sincerely new fr-CA"}}
    end
    assert_redirected_to mailer_templates_path()
    assert_equal "flash_message.mailer_template_flash.widget_update_success".translate(:locale => "fr-CA"), flash[:notice]
    assert_equal 2, widget.reload.translations.count
    assert_equal "Yours sincerely new fr-CA", widget.reload.translation_for("fr-CA").source
    assert_equal "Yours sincerely", widget.translation_for("en").source
  end

  def test_update_success_with_vulnerable_content_with_version_v1
    login_as_super_user    
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]
    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely")
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      assert_no_difference "Mailer::Widget.count" do
        post :update, params: { :id => widget.id, :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}<script>alert(10);</script>"}}
      end
    end
  end

  def test_update_success_with_vulnerable_content_with_version_v2
    login_as_super_user    
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]
    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely")
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      assert_no_difference "Mailer::Widget.count" do
        post :update, params: { :id => widget.id, :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}<script>alert(10);</script>"}}
      end
    end
  end

  def test_update_success_with_feature_enabled
    programs(:org_primary).organization_languages.destroy_all
    p = programs(:org_primary)
    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, true)
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]
    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely")

    assert_no_difference "Mailer::Widget.count" do
      post :update, params: { :id => widget.id, :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}"}}
    end
    assert_equal "Yours sincerely<br/> {{program_name}}", widget.reload.source
    assert_redirected_to mailer_templates_path()
    assert_equal "The widget has been successfully updated", flash[:notice]
  end

  def test_super_user_required_for_update
    current_member_is :f_admin
    uid = WidgetSignature.widget_attributes[:uid]
    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely")

    assert_permission_denied do
      post :update, params: { :id => widget.id, :mailer_widget => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}"}}
    end
  end
end
