require_relative './../test_helper.rb'

class MailerTemplatesControllerTest < ActionController::TestCase
  include UserMailerHelper

  def test_authorization
    current_member_is :f_mentor

    assert_permission_denied do
      get :edit, params: { :id => ForgotPassword.mailer_attributes[:uid]}
    end
  end

  def test_authorization_subprogram
    current_user_is :ram

    assert_false users(:ram).member.admin?

    get :edit, params: { :id => AdminWeeklyStatus.mailer_attributes[:uid]}
    assert_response :success
  end

  def test_category_mails_success
    current_user_is :f_admin

    program = programs(:albers)
    program.enable_feature(FeatureName::MODERATE_FORUMS, true)
    program.enable_feature(FeatureName::FORUMS, true)

    category = EmailCustomization::NewCategories::Type::COMMUNITY

    all_emails = ChronusActionMailer::Base.get_descendants.select{|e| e.mailer_attributes[:category] == category}.collect(&:mailer_attributes)

    all_emails.reject!{ |e| (Array(e[:feature]).present? && (Array(e[:feature]) - program.disabled_features).empty?) || e[:donot_list] || (e[:level]==EmailCustomization::Level::ORGANIZATION) }.select{ |email| !email[:program_settings].present? || email[:program_settings].call(program) }

    all_emails.sort_by!{|mailer_attribute| mailer_attribute[:listing_order]}

    email_rollout_service = EmailRolloutService.new(program, users(:f_admin))

    t1 = Mailer::Template.create!(:program => program, :uid => ContentFlaggedAdminNotification.mailer_attributes[:uid], :source => "Yours sincerely", :subject => "Subject", :enabled => false, :content_changer_member_id => 1, :content_updated_at => Time.now)
    t2 = Mailer::Template.create!(:program => program, :uid => ContentModerationAdminNotification.mailer_attributes[:uid], :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)

    all_emails.each do |email|
      email[:disabled] = program.email_template_disabled_for_activity?(ChronusActionMailer::Base.get_descendant(email[:uid]))
      email[:rollout] = !email[:skip_rollout] && email_rollout_service.rollout_applicable?(email[:uid])
      email[:content_customized] = Mailer::Template.content_customized?(program, ChronusActionMailer::Base.get_descendant(email[:uid]))
    end

    get :category_mails, params: { :category => category}

    assert_response :success

    assert_equal all_emails.collect{|e| e[:title]}, assigns(:emails_hash_list).collect{|e| e[:title]}
    assert_equal WidgetTag.get_descendants.collect(&:widget_attributes).sort_by{|h| h[:title].call}.reject!{|widget_attribute| widget_attribute[:uid] == WidgetStyles.widget_attributes[:uid]}.collect{|e| e[:title].call}, assigns(:widgets_hash_list).collect{|e| e[:title].call}

    assert_false assigns(:emails_hash_list).collect{|e| e[:uid]}.include?(MeetingCreationNotification.mailer_attributes[:uid])
    assert assigns(:emails_hash_list).collect{|e| e[:uid]}.include?(QaAnswerNotification.mailer_attributes[:uid])

    assert assigns(:emails_hash_list).collect{|e| e[:category]}.uniq.size > 0

    assert assigns(:emails_hash_list).collect{|e| e[:uid]}.include?(t1.uid)
    assert assigns(:emails_hash_list).collect{|e| e[:uid]}.include?(t2.uid)
    assert assigns(:emails_hash_list).collect{|e| e[:uid]}.include?(ArticleCommentNotification.mailer_attributes[:uid])

    assert_equal_unordered all_emails.select{|e| e[:content_customized]}.map{|h| h[:uid]}, [t1.uid, t2.uid]

    assert_equal_hash all_emails.group_by{|mailer_attribute| mailer_attribute[:subcategory]}, assigns(:emails_by_subcategory_hash)
  end

  def test_category_mails_with_feature_disabled_enabled
    current_user_is :f_admin

    programs(:org_primary).enable_feature(FeatureName::ARTICLES)
    programs(:org_primary).enable_feature(FeatureName::MODERATE_FORUMS, false)

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::COMMUNITY}
    assert_response :success

    assert assigns(:emails_hash_list).collect{|e| e[:uid]}.include?(ArticleCommentNotification.mailer_attributes[:uid])
    assert_false assigns(:emails_hash_list).collect{|e| e[:uid]}.include?(ContentModerationAdminNotification.mailer_attributes[:uid])
  end

  def test_category_mails
    current_member_is :f_admin

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::COMMUNITY}
    assert_response :success
  end

  def test_category_mails_should_not_list_templates_which_have_donot_list_set
    current_user_is :f_admin

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::DIGEST_AND_WEEKLY_UPDATES}
    assert_response :success
    emails_hash_list =  assigns(:emails_hash_list)
    assert ForgotPassword.mailer_attributes[:donot_list]
    assert emails_hash_list.select{|email| email[:uid] == ForgotPassword.mailer_attributes[:uid]}.empty?
    assert emails_hash_list.select{|email| email[:uid] == AdminWeeklyStatus.mailer_attributes[:uid]}.present?

    begin
      AdminWeeklyStatus.mailer_attributes[:donot_list] = true
      get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::DIGEST_AND_WEEKLY_UPDATES}
      assert_response :success
      emails_hash_list =  assigns(:emails_hash_list)
      assert emails_hash_list.select{|email| email[:uid] == AdminWeeklyStatus.mailer_attributes[:uid]}.empty?
    ensure
      AdminWeeklyStatus.mailer_attributes.delete(:donot_list)
    end

  end 

  def test_category_mails_with_super_user
    login_as_super_user
    current_member_is :f_admin

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT}
    assert_response :success
    assert assigns(:enable_update)
  end

  def test_category_mails_with_customize_emails_enabled
    p = programs(:org_primary)
    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, true)
    current_member_is :f_admin

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT}
    assert_response :success
    assert assigns(:enable_update)
  end

  def test_category_mails_display_email_in_program_mail_enabled
    current_user_is :f_admin

    mailer_attributes = UserActivationNotification.mailer_attributes.dup.merge({program_settings: Proc.new{|a| true}})
    ChronusActionMailer::Base.stubs(:get_descendants).returns([UserActivationNotification])
    UserActivationNotification.stubs(:mailer_attributes).returns(mailer_attributes)

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT}
    assert_equal [mailer_attributes[:uid]], assigns(:emails_hash_list).collect{|e| e[:uid]}
  end

  def test_category_mails_display_email_in_program_mail_disabled
    current_user_is :f_admin

    mailer_attributes = UserActivationNotification.mailer_attributes.dup.merge({program_settings: Proc.new{|a| false}})
    ChronusActionMailer::Base.stubs(:get_descendants).returns([UserActivationNotification])
    UserActivationNotification.stubs(:mailer_attributes).returns(mailer_attributes)

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT}
    assert_equal [], assigns(:emails_hash_list).collect{|e| e[:uid]}
  end

  def test_category_mails_display_email_in_program_mail_disabled_but_shown_at_org_level
    current_member_is :f_admin

    mailer_attributes = MemberActivationNotification.mailer_attributes.dup.merge({program_settings: Proc.new{|a| false}})
    ChronusActionMailer::Base.stubs(:get_descendants).returns([MemberActivationNotification])
    MemberActivationNotification.stubs(:mailer_attributes).returns(mailer_attributes)

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT}
    assert_equal [mailer_attributes[:uid]], assigns(:emails_hash_list).collect{|e| e[:uid]}
  end

  def test_edit
    current_user_is :f_admin
    uid = AdminWeeklyStatus.mailer_attributes[:uid]

    get :edit, params: { :id => uid}
    assert_response :success
    assert_equal uid, assigns(:uid)
    assert_equal AdminWeeklyStatus, assigns(:email)
    assert_equal_hash AdminWeeklyStatus.mailer_attributes, assigns(:email_hash)
    assert assigns(:all_tags)
    assert assigns(:widget_names)
    assert_false assigns(:enable_update)
    assert assigns(:mailer_template).new_record?
    assert_equal uid, assigns(:mailer_template).uid
    assert_equal programs(:albers), assigns(:mailer_template).program
    assert_equal AdminWeeklyStatus.mailer_attributes[:subject].call, assigns(:mailer_template).subject
    assert_equal ERB.new(ChronusActionMailer::Base.default_email_content_from_path(AdminWeeklyStatus.mailer_attributes[:view_path])).result, assigns(:mailer_template).source
  end

  def test_edit_failure_at_wrong_level
    current_member_is :f_admin
    uid = AdminWeeklyStatus.mailer_attributes[:uid]

    assert_raise(NoMethodError) do
      get :edit, params: { :id => uid}
    end
    assert_nil assigns(:correct_level)
  end

  def test_edit_with_super_user
    login_as_super_user
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]

    get :edit, params: { :id => uid}
    assert_response :success
    assert assigns(:enable_update)
  end

  def test_edit_with_customize_emails_enabled
    p = programs(:org_primary)
    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, true)
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]

    get :edit, params: { :id => uid}
    assert_response :success
    assert assigns(:enable_update)    
  end

  def test_edit_existing
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)

    get :edit, params: { :id => uid}
    assert_response :success
    assert_equal uid, assigns(:uid)
    assert_equal ForgotPassword, assigns(:email)
    assert_equal_hash ForgotPassword.mailer_attributes, assigns(:email_hash)
    assert assigns(:all_tags)
    assert assigns(:widget_names)
    assert_false assigns(:mailer_template).new_record?
    assert_equal template.id, assigns(:mailer_template).id
    assert_equal "Subject", assigns(:mailer_template).subject
    assert_equal "Yours sincerely", assigns(:mailer_template).source
  end

  def test_edit_existing_org_subprogram
    current_user_is :f_admin
    uid = AdminWeeklyStatus.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :enabled => false, :content_changer_member_id => 1, :content_updated_at => Time.now)

    get :edit, params: { :id => uid}
    assert_response :success
    assert_equal uid, assigns(:uid)
    assert_equal AdminWeeklyStatus, assigns(:email)
    assert_equal_hash AdminWeeklyStatus.mailer_attributes, assigns(:email_hash)
    assert assigns(:all_tags)
    assert assigns(:widget_names)
    assert assigns(:mailer_template).new_record?
    assert_equal uid, assigns(:mailer_template).uid
    assert_equal programs(:albers), assigns(:mailer_template).program
    assert_equal "Subject", assigns(:mailer_template).subject
    assert_equal "Yours sincerely", assigns(:mailer_template).source
    assert_false assigns(:mailer_template).enabled?
  end

  def test_edit_existing_subprogram
    current_user_is :f_admin
    uid = AdminWeeklyStatus.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :enabled => false, :content_changer_member_id => 1, :content_updated_at => Time.now)
    stemplate = Mailer::Template.create!(:program => programs(:albers), :uid => uid, :source => "my sincerely", :subject => "SSubject", :content_changer_member_id => 1, :content_updated_at => Time.now)

    get :edit, params: { :id => uid}
    assert_response :success
    assert_equal uid, assigns(:uid)
    assert_equal AdminWeeklyStatus, assigns(:email)
    assert_equal_hash AdminWeeklyStatus.mailer_attributes, assigns(:email_hash)
    assert assigns(:all_tags)
    assert assigns(:widget_names)
    assert_false assigns(:mailer_template).new_record?
    assert_equal stemplate.id, assigns(:mailer_template).id
    assert_equal "SSubject", assigns(:mailer_template).subject
    assert_equal "my sincerely", assigns(:mailer_template).source
  end

  def test_create_failure
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]

    assert_no_difference "Mailer::Template.count" do
      post :create, params: { :mailer_template => {:uid => uid, :source => "{{invalid_tag}}", :subject => "{{invalid_tag}}"}, :has_subject_changed => "true", :has_source_changed => "true"}
    end

    assert_false assigns(:mailer_template).valid?
    assert_response :success
    assert_equal_hash ForgotPassword.mailer_attributes, assigns(:email_hash)
    assert assigns(:all_tags)
    assert assigns(:widget_names)
  end

  def test_create_success
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy

    assert_difference "Mailer::Template.count" do
      post :create, params: { :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
    end

    template = Mailer::Template.last
    assert_equal "Yours sincerely<br/> {{program_name}}", template.source
    assert_equal "Subject {{program_name}}", template.subject
    assert_redirected_to edit_mailer_template_path(uid)
    assert_equal "The email has been successfully updated", flash[:notice]
    assert template.enabled?
  end

  def test_create_org_level_mail_at_program_level
    current_user_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]

    assert_difference "Mailer::Template.count" do
      post :create, params: { :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
    end

    assert_equal programs(:org_primary).id, Mailer::Template.last.program_id
  end

  def test_create_program_level_mail_at_org_level_failure
    current_member_is :f_admin
    uid = UserActivationNotification.mailer_attributes[:uid]

    assert_raise(NoMethodError) do
      assert_no_difference "Mailer::Template.count" do
        post :create, params: { :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
      end
    end
  end

  def test_create_success_url_should_not_escape_with_sanitize_allow_script_access
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]

    assert_difference "Mailer::Template.count" do
      post :create, params: { :mailer_template => {:uid => uid, :source => "<a href='{{program_name}}'>{{program_name}}</a>", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
    end

    template = Mailer::Template.last
    assert_equal "<a href='{{program_name}}'>{{program_name}}</a>", template.source
  end

  def test_create_success_with_vulnerable_content_with_version_v1
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      assert_difference "Mailer::Template.count" do
        post :create, params: { :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}<script>alert(10);<script>", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
      end
    end
  end

  def test_create_success_with_vulnerable_content_with_version_v2
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      assert_difference "Mailer::Template.count" do
        post :create, params: { :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}<script>alert(10);<script>", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
      end
    end
  end

  def test_update_failure
    login_as_super_user
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)

    assert_no_difference "Mailer::Template.count" do
      post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{invalid_tag}}", :subject => "{{invalid_tag}}"}, :has_subject_changed => "true", :has_source_changed => "true"}
    end

    assert_false assigns(:mailer_template).valid?
    assert_response :success
    assert_equal_hash ForgotPassword.mailer_attributes, assigns(:email_hash)
    assert assigns(:all_tags)
    assert assigns(:widget_names)
  end

  def test_update_failure_with_customize_emails_enabled
    p = programs(:org_primary)
    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, true)
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)

    assert_no_difference "Mailer::Template.count" do
      post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{invalid_tag}}", :subject => "{{invalid_tag}}"}, :has_subject_changed => "true", :has_source_changed => "true"}
    end

    assert_false assigns(:mailer_template).valid?
    assert_response :success
    assert_equal_hash ForgotPassword.mailer_attributes, assigns(:email_hash)
    assert assigns(:all_tags)
    assert assigns(:widget_names)
  end

  def test_update_success
    login_as_super_user
    current_member_is :f_admin
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)
    assert_equal template.translations.pluck(:locale), ["en"]

    assert_no_difference "Mailer::Template.count" do
      post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :source => "Sourcex", :subject => "Subjectx", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
    end

    assert_equal template.reload.translations.pluck(:locale), ["en", "fr-CA"]
    assert_equal "Sourcex", template.reload.source
    assert_equal "Subjectx", template.subject
    run_in_another_locale(:'fr-CA') do
      assert_equal ChronusActionMailer::Base.default_email_content_from_path(ForgotPassword.mailer_attributes[:view_path]), template.source
      assert_equal ForgotPassword.mailer_attributes[:subject].call, template.subject
    end

    assert_redirected_to edit_mailer_template_path(uid)
    assert_equal  "The email has been successfully updated", flash[:notice]
    assert template.enabled?
  end

  def test_update_content_changer_and_updation_time
    login_as_super_user
    current_user_is :f_admin
    mailer_template = Mailer::Template.non_campaign_mails.first

    post :update, params: { id: mailer_template.id, mailer_template: { uid: mailer_template.uid, source: "Sourcex", subject: "Subjectx", enabled: "true" }, has_subject_changed: "true", has_source_changed: "true"}

    mailer_template.reload
    changer, change_time = Mailer::Template.content_updater_and_updation_time(mailer_template.uid, mailer_template.program)
    assert_equal users(:f_admin).member, changer
    assert_equal mailer_template.content_updated_at, change_time
  end

  def test_update_program_level_mail_at_org_level_failure
    login_as_super_user
    current_member_is :f_admin
    uid = UserActivationNotification.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:albers), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)

    assert_raise(NoMethodError) do
      assert_no_difference "Mailer::Template.count" do
        post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}", :enabled => "true"}}
      end
    end
  end

  def test_update_org_level_mail_at_program_level
    login_as_super_user
    current_user_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)

    assert_no_difference "Mailer::Template.count" do
      post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
    end

    assert_equal "Subject {{program_name}}", Mailer::Template.last.subject
  end


  def test_update_success_with_vulnerable_content_with_version_v1
    login_as_super_user
    current_member_is :f_admin
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      assert_no_difference "Mailer::Template.count" do
        post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}<script>alert(10);</script>", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
      end
    end
  end

  def test_update_success_with_vulnerable_content_with_version_v2
    login_as_super_user
    current_member_is :f_admin
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      assert_no_difference "Mailer::Template.count" do
        post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}<script>alert(10);</script>", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
      end
    end
  end

  def test_update_success_with_customize_emails_enabled
    p = programs(:org_primary)    
    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, true)
    current_member_is :f_admin
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)
    assert_equal template.translations.pluck(:locale), ["en"]

    assert_no_difference "Mailer::Template.count" do
      post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
    end

    assert_equal template.reload.translations.pluck(:locale), ["en", "fr-CA"]
    assert_equal "Yours sincerely<br/> {{program_name}}", template.reload.source
    assert_equal "Subject {{program_name}}", template.subject
    run_in_another_locale(:'fr-CA') do
      assert_equal ChronusActionMailer::Base.default_email_content_from_path(ForgotPassword.mailer_attributes[:view_path]), template.source
      assert_equal ForgotPassword.mailer_attributes[:subject].call, template.subject
    end

    assert_redirected_to edit_mailer_template_path(uid)
    assert_equal  "The email has been successfully updated", flash[:notice]
    assert template.enabled?
  end

  def test_update_status_new
    login_as_super_user
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]

    assert_difference "Mailer::Template.count" do
      post :update_status, xhr: true, params: { :id => uid, :enabled => "true"}
    end

    template = Mailer::Template.last
    assert template.enabled?
    assert_equal uid, template.uid

    assert_equal ForgotPassword, assigns(:email)
    assert_equal_hash ForgotPassword.mailer_attributes, assigns(:email_hash)
  end

  def test_update_status_new_with_customize_emails_enabled
    p = programs(:org_primary)    
    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, true)
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]

    assert_difference "Mailer::Template.count" do
      post :update_status, xhr: true, params: { :id => uid, :enabled => "true"}
    end

    template = Mailer::Template.last
    assert template.enabled?
    assert_equal uid, template.uid

    assert_equal ForgotPassword, assigns(:email)
    assert_equal_hash ForgotPassword.mailer_attributes, assigns(:email_hash)
  end

  def test_update_status_existing
    login_as_super_user
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)
    assert template.enabled?

    assert_no_difference "Mailer::Template.count" do
      post :update_status, xhr: true, params: { :id => uid, :enabled => "true"}
    end

    assert template.reload.enabled?

    assert_equal ForgotPassword, assigns(:email)
    assert_equal_hash ForgotPassword.mailer_attributes, assigns(:email_hash)
  end

  def test_update_status_existing_with_customize_emails_enabled
    p = programs(:org_primary)
    p.enable_feature(FeatureName::CUSTOMIZE_EMAILS, true)
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)
    assert template.enabled?

    assert_no_difference "Mailer::Template.count" do
      post :update_status, xhr: true, params: { :id => uid, :enabled => "true"}
    end

    assert template.reload.enabled?

    assert_equal ForgotPassword, assigns(:email)
    assert_equal_hash ForgotPassword.mailer_attributes, assigns(:email_hash)
  end

  def test_update_status_program_level_mail_at_org_level_failure
    login_as_super_user
    current_member_is :f_admin
    uid = UserActivationNotification.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:albers), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :enabled => false, :content_changer_member_id => 1, :content_updated_at => Time.now)

    assert_raise(NoMethodError) do
      assert_no_difference "Mailer::Template.count" do
        post :update_status, xhr: true, params: { :id => uid, :enabled => "true"}
      end
    end
  end

  def test_update_status_org_level_mail_at_program_level
    login_as_super_user
    current_user_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)
    assert template.enabled?

    assert_no_difference "Mailer::Template.count" do
      post :update_status, xhr: true, params: { :id => uid, :enabled => "true"}
    end

    assert template.reload.enabled?
    assert_equal ForgotPassword, assigns(:email)
  end

  def test_preview_email_success
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]

    post :preview_email, xhr: true, params: { :id => uid, :mailer_template => {:source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}"}}
    assert_response :success

    email = ActionMailer::Base.deliveries.last

    assert_equal email.subject, "Subject #{programs(:org_primary).name}"
    assert_equal users(:f_admin).email, email.to.first
    assert_match /#{programs(:org_primary).name}/, get_text_part_from(email)
    assert_match /Yours sincerely/, get_text_part_from(email)
  end

  def test_preview_email_program_level_mail_at_org_level_failure
    current_member_is :f_admin
    uid = UserActivationNotification.mailer_attributes[:uid]

    assert_raise(NoMethodError) do
      post :preview_email, xhr: true, params: { :id => uid, :mailer_template => {:source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}"}}
    end
  end

  def test_preview_email_org_level_mail_at_program_level
    current_user_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]

    assert_no_difference "Mailer::Template.count" do
      post :preview_email, xhr: true, params: { :id => uid, :mailer_template => {:source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}"}}
    end

    assert_equal programs(:org_primary).id, assigns(:mailer_template).program_id
  end

  def test_preview_email_for_donot_list
    current_user_is :f_admin
    uid = AutoEmailNotification.mailer_attributes[:uid]

    post :preview_email, xhr: true, params: { id: uid, mailer_template: {source: "Hi {{receiver_first_name}},{{message_content}}", subject: "{{message_subject}} - {{mentoring_connection_name}}"}}
    assert_response :success

    email = ActionMailer::Base.deliveries.last

    assert_equal "Mentoring Relationship - Smith and Doe", email.subject
    assert_equal users(:f_admin).email, email.to.first
    assert_match /Hi John,This message is to help facilitate your\nrelationship./, get_text_part_from(email)
  end

  def test_super_login_required_for_update_and_update_status
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "Yours sincerely", :subject => "Subject", :content_changer_member_id => 1, :content_updated_at => Time.now)

    assert_permission_denied do
      post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "true"}
    end

    assert_permission_denied do
      post :update_status, xhr: true, params: { :id => uid, :enabled => "false"}
    end
  end


  def test_subprogram_tags_should_not_show_mentoring_reference_for_promotion_notification_email
    login_as_super_user
    current_user_is :f_admin
    uid = PromotionNotification.mailer_attributes[:uid]
    get :edit, params: { :id => uid}
    assert_response :success
    all_tags = assigns(:all_tags)
    assert_equal all_tags[:subprogram_name][:example].call(programs(:albers)), "Albers Mentor Program"
    assert_equal all_tags[:subprogram_name][:example].call(programs(:primary_portal)), "Primary Career Portal"
  end

  def test_subprogram_tags_should_not_show_mentoring_reference_for_demotion_notification_email
    login_as_super_user
    current_user_is :f_admin
    uid = DemotionNotification.mailer_attributes[:uid]
    get :edit, params: { :id => uid}
    assert_response :success
    all_tags = assigns(:all_tags)
    assert_equal all_tags[:subprogram_name][:example].call(programs(:albers)), "Albers Mentor Program"
    assert_equal all_tags[:subprogram_name][:example].call(programs(:primary_portal)), "Primary Career Portal"
  end

  def test_get_tags_from_email_should_give_campaign_tags_if_template_belongs_to_campaign
    login_as_super_user
    current_user_is :f_admin
    uid = ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]
    template = programs(:albers).mailer_templates.find_by(uid: uid)

    campaign_message = CampaignManagement::ProgramInvitationCampaignMessage.first
    Mailer::Template.any_instance.expects(:campaign_message_id).returns(campaign_message.id)
    Mailer::Template.any_instance.expects(:campaign_message).returns(campaign_message)
    get :edit, params: { :id => uid}
    assert_response :success
    all_tags = assigns(:all_tags)
    assert_equal 8, all_tags.count
    assert_equal_unordered ["invitor_name", "role_name", "as_role_name_articleized", "url_invitation", "invitation_expiry_date", "subprogram_or_program_name", "url_subprogram_or_program", "url_contact_admin"], all_tags.keys.collect(&:to_s)

    Mailer::Template.any_instance.expects(:campaign_message_id).returns(nil)
    get :edit, params: { :id => uid}
    assert_response :success
    all_tags = assigns(:all_tags)
    assert_equal 11, all_tags.count
    assert_equal_unordered ["receiver_name", "program_name", "url_program", "current_time", "receiver_first_name", "receiver_last_name", "subprogram_name", "url_subprogram", "subprogram_or_program_name", "url_subprogram_or_program", "url_program_login"], all_tags.keys.collect(&:to_s)
  end

  def test_edit_in_different_language
    locale = "fr-CA"
    Language.last.update_column(:language_name, locale)
    member = members(:f_admin)
    Language.set_for_member(member, locale)

    login_as_super_user
    current_member_is member
    I18n.stubs(:raise_translation_missing_exception).returns([])
    get :edit, params: { :id => ThreeSixtySurveyAssesseeNotification.mailer_attributes[:uid]}

    assert_response :success
  end

  def test_category_mails_rollout_set_for_mails
    current_user_is :f_admin
    ma = AdminWeeklyStatus.mailer_attributes
    uid = ma[:uid]

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::DIGEST_AND_WEEKLY_UPDATES}
    assert_response :success
    emails = assigns(:emails_hash_list)
    e1 = emails.find{|e| e[:uid] == uid}
    assert_false e1[:rollout]

    EmailRolloutService.any_instance.stubs(:rollout_applicable?).returns(true)

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::DIGEST_AND_WEEKLY_UPDATES}
    assert_response :success
    emails = assigns(:emails_hash_list)
    e2 = emails.find{|e| e[:uid] == uid}
    assert e2[:rollout]

    AdminWeeklyStatus.stubs(:mailer_attributes).returns(ma.merge!({skip_rollout: true}))
    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::DIGEST_AND_WEEKLY_UPDATES}
    assert_response :success
    emails = assigns(:emails_hash_list)
    e3 = emails.find{|e| e[:uid] == uid}
    assert_false e3[:rollout]
  end

  def test_create_subject_source_when_not_changed
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy

    assert_difference "Mailer::Template.count" do
      post :create, params: { :mailer_template => {:uid => uid, :source => "Yours sincerely<br/> {{program_name}}", :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "false", :has_source_changed => "false"}
    end

    template = Mailer::Template.last
    assert_nil template.source
    assert_nil template.subject
    assert_equal 0, template.translations.count
    assert_redirected_to edit_mailer_template_path(uid)
    assert_equal "The email has been successfully updated", flash[:notice]
    assert template.enabled?
  end

  def test_create_subject_source_when_not_changed_in_other_locale
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy

    Language.set_for_member(members(:f_admin), "fr-CA")

    assert_difference "Mailer::Template.count" do
      post :create, params: { :mailer_template => {:uid => uid, :source => "french Yours sincerely<br/> {{program_name}}", :subject => "french Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "false", :has_source_changed => "false"}
    end

    template = Mailer::Template.last
    assert_nil template.source
    assert_nil template.subject
    assert_equal 0, template.translations.count
    assert_redirected_to edit_mailer_template_path(uid)
    assert template.enabled?
  end

  def test_create_when_only_subject_changed
    current_member_is :f_admin
    org_name = members(:f_admin).organization.name
    uid = ForgotPassword.mailer_attributes[:uid]
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy

    assert_difference "Mailer::Template.count" do
      post :create, params: { :mailer_template => {:uid => uid, :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "false"}
    end

    template = Mailer::Template.last
    GlobalizationUtils.run_in_locale("en") do
      assert_equal ChronusActionMailer::Base.default_email_content_from_path(ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:view_path]), template.reload.translations.find_by(locale: "en").source
      assert_equal "Subject {{program_name}}", template.subject
    end
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_equal ChronusActionMailer::Base.default_email_content_from_path(ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:view_path]), template.reload.translations.find_by(locale: "fr-CA").source
      assert_equal ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:subject].call, template.reload.translations.find_by(locale: "fr-CA").subject
    end
    assert_redirected_to edit_mailer_template_path(uid)
    assert_equal "The email has been successfully updated", flash[:notice]
    assert template.enabled?
  end

  def test_create_when_only_subject_changed_in_other_locale
    current_member_is :f_admin
    org_name = members(:f_admin).organization.name
    uid = ForgotPassword.mailer_attributes[:uid]
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy

    Language.set_for_member(members(:f_admin), "fr-CA")

    assert_difference "Mailer::Template.count" do
      post :create, params: { :mailer_template => {:uid => uid, :subject => "Subject {{program_name}}", :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "false"}
    end

    template = Mailer::Template.last
    GlobalizationUtils.run_in_locale("en") do
      assert_equal ChronusActionMailer::Base.default_email_content_from_path(ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:view_path]), template.reload.translations.find_by(locale: "en").source
      assert_equal ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:subject].call, template.reload.translations.find_by(locale: "en").subject
    end
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_equal ChronusActionMailer::Base.default_email_content_from_path(ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:view_path]), template.reload.translations.find_by(locale: "fr-CA").source
      assert_equal "Subject {{program_name}}", template.subject
    end
    assert_redirected_to edit_mailer_template_path(uid)
    assert template.enabled?
  end

  def test_create_when_only_source_changed
    current_member_is :f_admin
    org_name = members(:f_admin).organization.name
    uid = ForgotPassword.mailer_attributes[:uid]
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy

    assert_difference "Mailer::Template.count" do
      post :create, params: { :mailer_template => {:uid => uid, :source => "Source of this mail", :enabled => "true"}, :has_subject_changed => "false", :has_source_changed => "true"}
    end
    template = Mailer::Template.last
    GlobalizationUtils.run_in_locale("en") do
      assert_equal ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:subject].call, template.reload.translations.find_by(locale: "en").subject
      assert_equal "Source of this mail", template.source
    end
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_equal ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:subject].call, template.reload.translations.find_by(locale: "fr-CA").subject
      assert_equal ChronusActionMailer::Base.default_email_content_from_path(ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:view_path]), template.source
    end
    assert_redirected_to edit_mailer_template_path(uid)
    assert_equal "The email has been successfully updated", flash[:notice]
    assert template.enabled?
  end

  def test_create_when_only_source_changed_in_other_locale
    current_member_is :f_admin
    org_name = members(:f_admin).organization.name
    uid = ForgotPassword.mailer_attributes[:uid]
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy

    Language.set_for_member(members(:f_admin), "fr-CA")

    assert_difference "Mailer::Template.count" do
      post :create, params: { :mailer_template => {:uid => uid, :source => "Source of this mail", :enabled => "true"}, :has_subject_changed => "false", :has_source_changed => "true"}
    end
    template = Mailer::Template.last
    GlobalizationUtils.run_in_locale("en") do
      assert_equal ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:subject].call, template.reload.translations.find_by(locale: "en").subject
      assert_equal ChronusActionMailer::Base.default_email_content_from_path(ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:view_path]), template.reload.translations.find_by(locale: "en").source
    end
    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_equal ChronusActionMailer::Base.get_descendant(uid).mailer_attributes[:subject].call, template.reload.translations.find_by(locale: "fr-CA").subject
      assert_equal "Source of this mail", template.reload.translations.find_by(locale: "fr-CA").source
    end
    assert_redirected_to edit_mailer_template_path(uid)
    assert template.enabled?
  end

  def test_update_subject_source_when_not_changed
    login_as_super_user
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :es}.update_column(:language_name, :"fr-CA")
    programs(:org_primary).languages.find{|l| l.language_name.to_sym == :de}.destroy
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :source => "XYZ", :subject => "Loop", :content_changer_member_id => 1, :content_updated_at => Time.now)
    assert_no_difference "Mailer::Template.count" do
      post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :source => "XYZ1", :subject => "Loop2", :enabled => "true"}, :has_subject_changed => "false", :has_source_changed => "false"}
    end
    assert_equal "XYZ", template.reload.source
    assert_equal "Loop", template.subject
    assert_redirected_to edit_mailer_template_path(uid)
    assert_equal  "The email has been successfully updated", flash[:notice]
    assert template.enabled?
  end

  def test_category_mails_for_standalone
    current_user_is :foster_admin
    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::DIGEST_AND_WEEKLY_UPDATES}
    assert_response :success
    emails_hash_list = assigns(:emails_hash_list)

    assert_false emails_hash_list.find{|e| e[:uid] == AdminWeeklyStatus.mailer_attributes[:uid]}[:disabled]
    programs(:foster).mailer_templates.create(enabled: false, uid: AdminWeeklyStatus.mailer_attributes[:uid])

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::DIGEST_AND_WEEKLY_UPDATES}
    assert_response :success
    emails_hash_list = assigns(:emails_hash_list)

    assert emails_hash_list.find{|e| e[:uid] == AdminWeeklyStatus.mailer_attributes[:uid]}[:disabled]
  end

  def test_email_source_or_subject_update_removes_copied_content_value
    login_as_super_user
    current_member_is :f_admin
    uid = ForgotPassword.mailer_attributes[:uid]
    template = Mailer::Template.create!(:program => programs(:org_primary), :uid => uid, :subject => "Something", :source => nil, :copied_content => Mailer::Template::CopiedContent::BOTH, :content_changer_member_id => 1, :content_updated_at => Time.now)
    
    assert_no_difference "Mailer::Template.count" do
      post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :subject => "Something else", :source => nil, :enabled => "true"}, :has_subject_changed => "true", :has_source_changed => "false"}
    end
    assert_nil template.reload.copied_content

    template.update_attribute(:copied_content, Mailer::Template::CopiedContent::BOTH)

    assert_no_difference "Mailer::Template.count" do
      post :update, params: { :id => template.id, :mailer_template => {:uid => uid, :subject => "Something else", :source => "Something", :enabled => "true"}, :has_subject_changed => "false", :has_source_changed => "true"}
    end
    assert_nil template.reload.copied_content
  end

  def test_category_mails_should_only_list_mentoring_ralated_emails
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    Program.any_instance.stubs(:has_allowing_join_with_criteria?).returns(true)

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT}
    assert_response :success
    emails_hash_list = assigns(:emails_hash_list)

    allowed_emails = [MentorAddedNotification, WelcomeMessageToAdmin, ResendSignupInstructions, WelcomeMessageToMentor, MembershipRequestNotAccepted, UserWithSetOfRolesAddedNotification, DemotionNotification, CompleteSignupNewMemberNotification, CompleteSignupSuspendedMemberNotification, ManagerNotification, NotEligibleToJoinNotification, InviteNotification, WelcomeMessageToMentee, UserSuspensionNotification, CompleteSignupExistingMemberNotification, PromotionNotification, UserActivationNotification, AdminAddedDirectlyNotification, MenteeAddedNotification, MembershipRequestAccepted, MembershipRequestSentNotification]
    
    allowed_emails.each do |email|
      assert emails_hash_list.find{|e| e[:mailer_name].camelize == email.to_s}.present?
    end
  end

  def test_category_mails_should_not_list_career_development_email_for_mentoring
    current_user_is :nch_admin
    
    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT}
    assert_response :success
    emails_hash_list = assigns(:emails_hash_list)
    
    not_allowed_emails = [PortalMemberWithSetOfRolesAddedNotification, PortalMemberWithSetOfRolesAddedNotificationToReviewProfile]
    not_allowed_emails.each do |email|
      assert_false emails_hash_list.find{|e| e[:mailer_name].camelize == email.to_s}.present?
    end

  end

  def test_category_emails_should_not_list_mentoring_related_emails_for_portal
    current_user_is :portal_admin

    programs(:primary_portal).enable_feature(FeatureName::CALENDAR)

    Program.any_instance.stubs(:allows_apply_to_join_for_a_role?).returns(true)

    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT}
    assert_response :success
    emails_hash_list = assigns(:emails_hash_list)

    not_allowed_emails = [WelcomeMessageToMentee, WelcomeMessageToMentor, MentorAddedNotification, MenteeAddedNotification]
    
    not_allowed_emails.each do |email|
      assert_false emails_hash_list.find{|e| e[:mailer_name].camelize == email}.present?
    end

    allowed_emails = [CompleteSignupExistingMemberNotification, UserActivationNotification, AdminAddedDirectlyNotification, PortalMemberWithSetOfRolesAddedNotification, PortalMemberWithSetOfRolesAddedNotificationToReviewProfile]

    allowed_emails.each do |email|
      assert emails_hash_list.find{|e| e[:mailer_name].camelize == email.to_s}.present?
    end
  end

  def test_category_mails_should_show_membership_request_related_emails
    current_user_is :portal_admin
    program = programs(:primary_portal)
    employee = program.get_role(RoleConstants::EMPLOYEE_NAME)
    employee.update_attribute(:membership_request, true)
  
    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS}
    assert_response :success
    emails_hash_list = assigns(:emails_hash_list)

    assert emails_hash_list.find{|e| e[:mailer_name].classify == "MembershipRequestsExport"}.present?
  end

  def test_category_mails_should_show_update_descriptions
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT}
    assert_response :success
    emails_hash_list = assigns(:emails_hash_list)
    
    
    meeting_creation_notification_email = emails_hash_list.find{|e| e[:mailer_name].classify == "MeetingCreationNotificationToOwner"}
    assert_equal "When a meeting is created, this email is sent to the owner confirming the details of the meeting.", meeting_creation_notification_email[:description].call(programs(:albers))

    meeting_creation_notification_email = emails_hash_list.find{|e| e[:mailer_name].classify  == "MeetingCreationNotification"}
    assert_equal "When a user sets up a meeting in a mentoring connection, this email is sent to the other invitees.", meeting_creation_notification_email[:description].call(programs(:albers))

    meeting_edit_notification_email = emails_hash_list.find{|e| e[:mailer_name].classify  == "MeetingEditNotification"}
    assert_equal "This email is sent to all the attendees of the meeting when someone updates the meeting information.", meeting_edit_notification_email[:description].call(programs(:albers))
  end

  def test_category_mails_should_show_updated_descriptions_for_portal
    current_user_is :portal_admin
    program = programs(:primary_portal) 
    get :category_mails, params: { :category => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT}
    assert_response :success
    emails_hash_list = assigns(:emails_hash_list)
    
    protal_member_added_email = emails_hash_list.find{|e| e[:mailer_name].classify == "PortalMemberWithSetOfRolesAddedNotificationToReviewProfile"}

    assert_equal "Sent to a user when he/she is added to the program and are invited to review and publish their profile.", protal_member_added_email[:description].call(program)
    assert_equal "Invitation to user added to program with new role and unpublished profile", protal_member_added_email[:title].call(program)

    promotion_notification = emails_hash_list.find{|e| e[:mailer_name].classify == "PromotionNotification"}
    assert_equal "An existing user may be given an additional role (as an example, a mentor may also be asked to be an administrator). When that happens, this email is sent to the user with a descriptive message from the administrator.", promotion_notification[:description].call(program) 
  end

  def test_mentor_mentee_admin_names_in_mentor_request_related_test_emails
    current_user_is :f_admin
    program = programs(:org_primary).programs.first
    uids = ['i8e2kysg', 't278s0b7', '9g6rmlz', 'wio5lqz6', 'jdy6ndzb', 'j88s0r82', 'qfeyv0or', 'au2ahh7v', 'e7wlwot0', 'aysy1t7x', 'eon9xzdt']
    template = program.mailer_templates.create(uid: uids[0]) #Mentoring request pending acceptance reminder
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}, Mentee name: {{mentor_request_creator_name}}, Content: {{mentor_request_reminder_notification_content}}, Message: {{message_from_mentee}}", :subject => "mentor_request_reminder_notification"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Mentee name: William Brown, Content: William Brown, Message: I want you to mentor me. - William Brown/, email

    template.update_attributes!(uid: uids[1]) #Mentor Request Notification
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}, Mentee name: {{mentee_name}}, Message: {{message_to_recipient}}", :subject => "new_mentor_request"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Mentee name: William Brown, Message: I think we would be a good match. I would like to get some guidance from you to expand my horizons into Marketing\? - William Brown/, email

    template.update_attributes!(uid: uids[2]) #Mentee Requests Withdrawal Notification for Mentor
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}, Mentee name: {{mentee_name}}, Message: {{message_from_mentee}}", :subject => "mentor_request_withdrawn"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Mentee name: William Brown, Message: Sorry mentor, but I have already been offered mentoring by someone else. Thank you. - William Brown/, email

    template.update_attributes!(uid: uids[3]) #Mentor Request Export
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}", :subject => "mentor_requests_export"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith/, email

    template.update_attributes!(uid: uids[4]) #Mentor Request Closed Notification For Mentee
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}, Mentor name: {{recipient_name}}, Message: {{message_from_admin}}, Message: {{message_from_admin_as_quote}}, Admin: {{admin_name}}", :subject => "mentor_request_closed_for_sender"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Mentor name: William Brown, Message: Sorry. The request is invalid., Message: Sorry. The request is invalid. - Administrator, Admin: Administrator/, email

    template.update_attributes!(uid: uids[5]) #Mentor request acceptance notification
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}, Mentor name: {{mentor_name}}, Group: {{group_name}}", :subject => "mentor_request_accepted"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Mentor name: William Brown, Group: Brown and Smith/, email

    template.update_attributes!(uid: uids[6]) #Mentor Request Closed Notification For Mentor
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}, Sender name: {{sender_name}}, Message: {{message_from_admin}}, Message: {{message_from_admin_as_quote}}", :subject => "mentor_request_closed_for_recipient"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Sender name: William Brown, Message: Sorry. The request is invalid., Message: Sorry. The request is invalid. - Administrator/, email

    template.update_attributes!(uid: uids[7]) #Mentee Requests Rejected Notification from Mentor
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}, Mentor name: {{mentor_name}}, Message: {{message_from_mentor}}", :subject => "mentor_request_rejected"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Mentor name: William Brown, Message: Sorry. I have already reached my limit. - William Brown/, email

    template.update_attributes!(uid: uids[8]) #Mentor Request Expired Notification For Mentee
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}, Recipient name: {{recipient_name}}", :subject => "mentor_request_expired_to_sender"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Recipient name: Wi Albers Mentor Program Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Recipient name: William Brown/, email

    #Preferred mentoring request emails
    template.update_attributes!(uid: uids[9]) #Mentee requests mentor email to administrator
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}, Mentee name: {{mentee_name}}, Message to Admin: {{message_to_admin}}", :subject => "new_mentor_request_to_admin"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Mentee name: William Brown, Message to Admin: I am looking to expand my horizons into Marketing, please help me in finding the right match. - William Brown/, email

    template.update_attributes!(uid: uids[10]) #Mentee Requests Withdrawal Notification for Administrator
    post :preview_email, xhr: true, params: { :root =>  program.root, :id => template.uid, :mailer_template => {:source => "Receiver name: {{receiver_name}}, Receiver first name: {{receiver_first_name}}, Receiver last name: {{receiver_last_name}}, Mentee name: {{mentee_name}}, Message from mentee: {{message_from_mentee}}", :subject => "mentor_request_withdrawn_to_admin"}}
    email = ActionController::Base.helpers.strip_tags(get_html_part_from(ActionMailer::Base.deliveries.last)).squish
    assert_match /Receiver name: John Smith, Receiver first name: John, Receiver last name: Smith, Mentee name: William Brown, Message from mentee: Sorry admin, but I have already been offered mentoring by someone else. Thank you. - William Brown/, email
  end

  def test_index_failure
    current_user_is :f_mentor

    assert_permission_denied do
      get :index
    end
  end

  def test_index_success
    current_user_is :f_admin
    EmailRolloutService.any_instance.stubs(:show_rollout_update_all?).returns(true)

    get :index
    assert assigns(:show_rollout_update_all)
    catogories_list = assigns(:email_catogories_list)
    assert_equal 5, catogories_list.size
    assert_equal_unordered ["Enrollment and user management", "General administration", "Community features", "Matching and engagement", "Digests and weekly updates"], catogories_list.collect{|c| c[:name]}
    digest_email = catogories_list.find{|c| c[:name] == "Digests and weekly updates"}
    me_email = catogories_list.find{|c| c[:name] == "Matching and engagement"}
    assert_equal 2, digest_email[:count]
    assert_equal 12, me_email[:count]
  end

  def test_index_with_calender_feature
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR_SYNC, false)

    get :index
    catogories_list = assigns(:email_catogories_list)
    assert_equal 5, catogories_list.size
    assert_equal_unordered ["Enrollment and user management", "General administration", "Community features", "Matching and engagement", "Digests and weekly updates"], catogories_list.collect{|c| c[:name]}
    digest_email = catogories_list.find{|c| c[:name] == "Digests and weekly updates"}
    me_email = catogories_list.find{|c| c[:name] == "Matching and engagement"}
    assert_equal 2, digest_email[:count]
    assert_equal 24, me_email[:count]
  end

  def test_index_success_org_level
    current_member_is :f_admin
    EmailRolloutService.any_instance.stubs(:show_rollout_update_all?).returns(true)

    get :index
    assert assigns(:show_rollout_update_all)
    catogories_list = assigns(:email_catogories_list)
    assert_equal 3, catogories_list.size
    assert_equal_unordered ["Enrollment and user management", "General administration", "Community features"], catogories_list.collect{|c| c[:name]}
    ae_email = catogories_list.find{|c| c[:name] == "General administration"}
    assert_equal 2, ae_email[:count]
  end

  def test_index_success_org_level_with_360_feature
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    EmailRolloutService.any_instance.stubs(:show_rollout_update_all?).returns(true)

    get :index
    assert assigns(:show_rollout_update_all)
    catogories_list = assigns(:email_catogories_list)
    assert_equal 4, catogories_list.size
    assert_equal_unordered ["Enrollment and user management", "General administration", "Community features", "360 Degree Survey"], catogories_list.collect{|c| c[:name]}
    ae_email = catogories_list.find{|c| c[:name] == "General administration"}
    ts_email = catogories_list.find{|c| c[:name] == "360 Degree Survey"}
    assert_equal 2, ae_email[:count]
    assert_equal 2, ts_email[:count]
  end

  def test_index_donot_list
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    begin
      ThreeSixtySurveyAssesseeNotification.mailer_attributes[:donot_list] = true
      get :index
      catogories_list = assigns(:email_catogories_list)
      assert_equal 4, catogories_list.size
      assert_equal_unordered ["Enrollment and user management", "General administration", "Community features", "360 Degree Survey"], catogories_list.collect{|c| c[:name]}
      ts_email = catogories_list.find{|c| c[:name] == "360 Degree Survey"}
      assert_equal 1, ts_email[:count]
    ensure
      ThreeSixtySurveyAssesseeNotification.mailer_attributes.delete(:donot_list)
    end

    begin
      ThreeSixtySurveyAssesseeNotification.mailer_attributes[:donot_list] = true
      ThreeSixtySurveyReviewerNotification.mailer_attributes[:donot_list] = true
      get :index
      # assert_equal 3, catogories_list.size
      catogories_list = assigns(:email_catogories_list)
      assert_equal_unordered ["Enrollment and user management", "General administration", "Community features"], catogories_list.collect{|c| c[:name]}
    ensure
      ThreeSixtySurveyAssesseeNotification.mailer_attributes.delete(:donot_list)
      ThreeSixtySurveyReviewerNotification.mailer_attributes.delete(:donot_list)
    end
  end
end
