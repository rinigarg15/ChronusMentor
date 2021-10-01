require_relative './../test_helper.rb'

class ProfilePicturesControllerTest < ActionController::TestCase
  ##############################################################################
  # EDIT
  ##############################################################################

  def test_edit_profile_picture
    current_user_is :f_mentor

    create_profile_picture(members(:f_mentor))
    profile_picture = members(:f_mentor).profile_picture
    get :edit, params: { :member_id => members(:f_mentor)}
    assert_response :success
    assert_template 'edit'
    assert_select 'html'
    assert_equal profile_picture, assigns(:profile_picture)
    assert_equal users(:f_mentor), assigns(:profile_user)
  end

  def test_edit_profile_picture_from_home
    current_user_is :f_mentor

    create_profile_picture(members(:f_mentor))
    get :edit, params: { :member_id => members(:f_mentor), :src => 'home'}
    assert_response :success
    assert_template 'edit'
    assert_select 'html'
  end

  def test_edit_profile_picture_allowed_for_admin
    current_user_is :f_admin

    create_profile_picture(members(:f_mentor))
    profile_picture = members(:f_mentor).profile_picture
    get :edit, params: { :member_id => members(:f_mentor)}
    assert_response :success
    assert_template 'edit'
    assert_select 'html'
    assert_equal profile_picture, assigns(:profile_picture)
    assert_equal users(:f_mentor), assigns(:profile_user)
  end

  def test_edit_profile_picture_not_allowed_case
    current_user_is :rahim
    assert !users(:rahim).is_admin?
    create_profile_picture(members(:f_mentor))

    assert_permission_denied do
      get :edit, params: { :member_id => members(:f_mentor)}
    end
  end

  def test_edit_profile_picture_when_no_picture
    current_user_is :f_mentor

    # No profile picture yet.
    assert_nil members(:f_mentor).profile_picture
    get :edit, params: { :member_id => members(:f_mentor)}
    assert_response :success
    assert_template 'edit'
    assert_select 'html'
    assert_not_nil assigns(:profile_picture)
    assert assigns(:profile_picture).new_record?
    assert_equal users(:f_mentor), assigns(:profile_user)
  end

  def test_no_edit_link_when_picutre_is_nil
    current_user_is :f_mentor

    # No profile picture yet.
    assert_nil members(:f_mentor).profile_picture
    get :edit, params: { :member_id => members(:f_mentor)}
    assert_response :success
    assert_template 'edit'
    assert_select 'a', :text => "Edit this photo", :count => 0
  end

  ##############################################################################
  # UPDATE
  ##############################################################################

  def test_update_picture_success_when_nil
    current_user_is :f_mentor

    # No picture.
    assert_nil members(:f_mentor).profile_picture

    assert_nothing_raised do
      post :update, params: { :member_id => members(:f_mentor).id, :profile_picture => {
        :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
      }
    end

    assert_redirected_to crop_member_profile_picture_path(members(:f_mentor))

    members(:f_mentor).reload
    assert_not_nil members(:f_mentor).profile_picture
    assert_match(/test_pic.png/, members(:f_mentor).profile_picture.image_file_name)
  end

  def test_update_picture_success
    current_user_is :f_mentor

    # Make sure user has some picture.
    create_profile_picture(members(:f_mentor))
    members(:f_mentor).profile_picture.reload
    assert_match(/test_pic.png/, members(:f_mentor).profile_picture.image_file_name)

    Paperclip::Cropper.any_instance.expects(:crop_command).at_least(8)
    assert_nothing_raised do
      post :update, params: { :member_id => members(:f_mentor), :profile_picture => {
        :image => fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')}
      }
    end
    #default crop params assertions
    assert_equal 200, assigns(:profile_picture).crop_w
    assert_equal 200, assigns(:profile_picture).crop_h
    assert_equal 0, assigns(:profile_picture).crop_x
    assert_equal 0, assigns(:profile_picture).crop_y
    assert_equal 0, assigns(:profile_picture).rotate
    assert_redirected_to crop_member_profile_picture_path(members(:f_mentor))

    members(:f_mentor).profile_picture.reload
    assert_match(/pic_2.png/, members(:f_mentor).profile_picture.image_file_name)
  end

  def test_update_not_applicable_picture_success
    current_user_is :f_mentor
    member = members(:f_mentor)
    # Make sure user has some picture.
    ProfilePicture.create(:member => member, :image => nil, :not_applicable => true)
    member.profile_picture.reload
    assert_blank member.profile_picture.image_file_name
    assert member.profile_picture.not_applicable

    assert_nothing_raised do
      post :update, params: { :member_id => member, :profile_picture => {
        :image => fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')}
      }
    end

    assert_redirected_to crop_member_profile_picture_path(member)

    member.profile_picture.reload
    assert_match(/pic_2.png/, member.profile_picture.image_file_name)
    assert_false member.profile_picture.not_applicable
  end

  def test_update_picture_success_for_admin
    current_user_is :f_admin

    # Make sure user has some picture.
    create_profile_picture(members(:f_mentor))
    members(:f_mentor).profile_picture.reload
    assert_match(/test_pic.png/, members(:f_mentor).profile_picture.image_file_name)

    assert_nothing_raised do
      post :update, params: { :member_id => members(:f_mentor), :profile_picture => {
        :image => fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')}
      }
    end

    assert_redirected_to crop_member_profile_picture_path(members(:f_mentor))

    members(:f_mentor).profile_picture.reload
    assert_match(/pic_2.png/, members(:f_mentor).profile_picture.image_file_name)
  end

  def test_update_profile_picture_not_allowed_case
    current_user_is :rahim
    assert !users(:rahim).is_admin?
    create_profile_picture(members(:f_mentor))

    assert_permission_denied do
      post :update, params: { :member_id => members(:f_mentor), :profile_picture => {
        :image => fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')}
      }
    end
  end

  def test_update_picture_from_url_success
    current_user_is :f_admin

    # Make sure user has some picture.
    create_profile_picture(members(:f_mentor))
    members(:f_mentor).profile_picture.reload
    assert_match(/test_pic.png/, members(:f_mentor).profile_picture.image_file_name)
    image_data = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    ProfilePicture.any_instance.expects(:get_remote_image_data).at_least(1).returns(image_data)

    assert_nothing_raised do
      post :update, params: { :member_id => members(:f_mentor), :profile_picture => {
        :image_url => 'http://mentor.chronus.com/images/edit.gif'}
      }
    end

    assert_redirected_to crop_member_profile_picture_path(members(:f_mentor))

    members(:f_mentor).profile_picture.reload
    assert_match(/pic_2.png/, members(:f_mentor).profile_picture.image_file_name)
  end

  # Failure when image data is malformed.
  def test_update_picture_failure_invalid_format
    current_user_is :f_mentor

    # Make sure user has some picture.
    create_profile_picture(members(:f_mentor))

    members(:f_mentor).profile_picture.save
    assert_match(/test_pic.png/, members(:f_mentor).profile_picture.image_file_name)
    assert members(:f_mentor).profile_picture.image

    assert_nothing_raised do
      post :update, params: { :member_id => members(:f_mentor).id, :profile_picture => {
        :image => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')}
      }
    end

    assert_response :success
    assert_template 'edit'
    assert_equal "There were some problems while updating the picture. Please try again with a different picture.", flash[:error]

    # No change to picture
    assert_match(/test_pic.png/, members(:f_mentor).profile_picture.reload.image_file_name)
  end

  # Failure when image url is malformed.
  def test_update_picture_failure
    current_user_is :f_mentor

    # Make sure user has some picture.
    create_profile_picture(members(:f_mentor))

    members(:f_mentor).profile_picture.save
    assert_match(/test_pic.png/, members(:f_mentor).profile_picture.image_file_name)
    assert members(:f_mentor).profile_picture.image

    assert_nothing_raised do
      post :update, params: { :member_id => members(:f_mentor).id,
          :profile_picture => {:image_url => 'invalid_url'}
        }
    end

    assert_response :success
    assert_template 'edit'
    assert_equal "There were some problems while updating the picture. Please try again with a different picture.", flash[:error]

    # No change to picture
    assert_match(/test_pic.png/, members(:f_mentor).profile_picture.reload.image_file_name)
  end

  def test_update_crop_image
    current_user_is :f_mentor
    create_profile_picture(members(:f_mentor))

    members(:f_mentor).profile_picture.save
    assert_match(/test_pic.png/, members(:f_mentor).profile_picture.image_file_name)
    assert members(:f_mentor).profile_picture.image

    Paperclip::Cropper.any_instance.expects(:crop_command).at_least(4)
    assert_nothing_raised do
      post :update, params: { :member_id => members(:f_mentor).id,
          :profile_picture => {:crop_x => 0, :crop_y => 0, :crop_w => 10, :crop_h => 10}
        }
    end
    assert_equal "10", assigns(:profile_picture).crop_w
    assert_equal "10", assigns(:profile_picture).crop_h
    assert_equal "0", assigns(:profile_picture).crop_x
    assert_equal "0", assigns(:profile_picture).crop_y
    assert_equal 0, assigns(:profile_picture).rotate

    assert_redirected_to edit_member_path(members(:f_mentor), ei_src: EngagementIndex::Src::EditProfile::PROFILE_PICTURE)
    assert_equal "The picture has been successfully updated" , flash[:notice]
  end

  def test_update_crop_image_with_horizontally_long_image
    current_user_is :f_mentor
    create_profile_picture(members(:f_mentor), image: fixture_file_upload(File.join('files', 'test_horizontal.jpg'), 'image/jpg'))

    members(:f_mentor).profile_picture.save
    assert_nothing_raised do
      post :update, params: { :member_id => members(:f_mentor).id,
          :profile_picture => {:crop_x => 0, :crop_y => 0, :crop_w => 750, :crop_h => 500}
        }
    end
    assert_equal "75x75", members(:f_mentor).profile_picture.image_geometry(:large).inspect
  end

  def test_update_crop_image_with_vertically_long_image
    current_user_is :f_mentor
    create_profile_picture(members(:f_mentor), image: fixture_file_upload(File.join('files', 'test_vertical.jpg'), 'image/jpg'))

    members(:f_mentor).profile_picture.save
    assert_nothing_raised do
      post :update, params: { :member_id => members(:f_mentor).id,
          :profile_picture => {:crop_x => 0, :crop_y => 0, :crop_w => 600, :crop_h => 746}
        }
    end
    assert_equal "75x75", members(:f_mentor).profile_picture.image_geometry(:large).inspect
  end


  ##############################################################################
  # CROP
  ##############################################################################

  def test_crop_profile_picture
    current_user_is :f_mentor

    create_profile_picture(members(:f_mentor))
    profile_picture = members(:f_mentor).profile_picture
    get :crop, params: { :member_id => members(:f_mentor)}
    assert_response :success
    assert_select 'a.cjs-profile-pic-rotate', 2
    assert_select 'i.fa.fa-rotate-left'
    assert_select 'i.fa.fa-rotate-right'
    assert_template 'crop'
    assert_select 'html'
    assert_equal profile_picture, assigns(:profile_picture)
    assert_equal users(:f_mentor), assigns(:profile_user)
  end
end
