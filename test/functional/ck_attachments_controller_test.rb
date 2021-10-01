require_relative './../test_helper.rb'

class CkAttachmentsControllerTest < ActionController::TestCase

  def test_show_requires_logged_in_organization
    asset = create_ckasset
    asset.update_attributes(login_required: true)

    current_organization_is :org_primary
    get :show, params: { id: asset.id}
    assert_response :redirect
    assert_redirected_to new_session_path
    assert_equal "Please login to access the requested page", flash[:notice]
    assert_equal "http://test.host/ck_attachments/#{asset.id}", session[:ck_attachment_url]
  end

  def test_should_not_redirect_to_pending_profile
    asset = create_ckasset
    organization = asset.organization
    organization.security_setting.sanitization_version = "v1"
    organization.save!

    current_user_is :pending_user
    @controller.expects(:open).returns(File.open(File.join(Rails.root, 'test/fixtures/files/some_file.txt')))
    get :show, params: { id: asset.id}
    assert_response :success
  end

  def test_should_not_redirect_to_terms_and_conditions_not_accepted
    asset = create_ckasset
    organization = asset.organization
    organization.security_setting.sanitization_version = "v1"
    organization.save!
    member = users(:f_admin).member
    member.terms_and_conditions_accepted = nil
    member.save!

    current_user_is :f_admin
    @controller.expects(:open).returns(File.open(File.join(Rails.root, 'test/fixtures/files/some_file.txt')))
    get :show, params: { id: asset.id}
    assert_response :success
  end

  def test_show_organization_and_id_mismatch
    asset = create_ckasset

    current_user_is :foster_admin
    assert_nothing_raised do
      get :show, params: { id: asset.id }
    end
    assert_template nil
  end

  def test_show_success
    asset = create_ckasset
    organization = asset.organization
    organization.security_setting.sanitization_version = "v1"
    organization.save!

    current_user_is :f_admin
    @controller.expects(:open).returns(File.open(File.join(Rails.root, 'test/fixtures/files/some_file.txt')))
    get :show, params: { id: asset.id }
    assert_response :success
  end

  def test_show_redirect_to_url_when_security_setting_is_v2
    asset = create_ckasset
    organization = asset.organization
    organization.security_setting.sanitization_version = "v2"
    organization.save!

    current_user_is :f_admin
    get :show, params: { id: asset.id }
    assert_response :redirect
  end

  def test_show_non_existing_attachment
    asset = Ckeditor::AttachmentFile.new(program_id: programs(:org_primary).id, data_file_name: "non_existing")
    asset.save(validate: false)

    current_user_is :f_admin
    get :show, params: { id: asset.id }
    assert_response :success
    assert_template nil
  end

  def test_show_for_android
    asset = create_ckasset

    @controller.stubs(:is_android_app?).returns(true)
    current_user_is :f_admin
    get :show, xhr: true, params: { id: asset.id }
    assert_response :success
    assert_equal "text/javascript", response.content_type
    assert_equal "cordovaFileHelper.handleDownloadPermission('#{asset.filename}', '#{asset.url}')\;", response.body
  end
end