require_relative './../test_helper.rb'

class ProfilePictureTest < ActiveSupport::TestCase
  def test_user_is_required
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :member do
      ProfilePicture.create!(
        :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    end
  end

  def test_picture_create
    member = members(:f_mentor)
    assert_nil member.profile_picture

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :image do
      assert_no_difference 'ProfilePicture.count' do
        ProfilePicture.create!(:member => member, :image => nil)
      end
    end
    
    assert_difference 'ProfilePicture.count' do
      ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    end

    member.reload
    assert_not_nil member.profile_picture
    assert_equal 'test_pic.png', member.profile_picture.image_file_name

    # Not applicable
    member = members(:f_student)
    assert_nil member.profile_picture
    assert_difference 'ProfilePicture.count' do
      ProfilePicture.create(:member => member, :image => nil, :not_applicable => true)
    end

    member.reload
    assert_not_nil member.profile_picture
    assert_nil member.profile_picture.image_file_name
  end

  def test_picture_image_url
    member = members(:f_mentor)
    assert_nil member.profile_picture

    assert_difference 'ProfilePicture.count' do
      ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    end

    member.reload
    assert_not_nil member.profile_picture
    assert_equal 'test_pic.png', member.profile_picture.image_file_name

    assert_match /small\/test_pic.png/, member.profile_picture.image.url(:small)
    assert_match /medium\/test_pic.png/, member.profile_picture.image.url(:medium)
    assert_match /large\/test_pic.png/, member.profile_picture.image.url(:large)
    assert_match /retina\/test_pic.png/, member.profile_picture.image.url(:retina)

    #By Default the url should get large image
    assert_match /large\/test_pic.png/, member.profile_picture.image.url
  end

  def test_picture_update_with_url
    member = members(:f_mentor)
    assert_nil member.profile_picture
    image_data = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    ProfilePicture.any_instance.expects(:get_remote_image_data).returns(image_data)

    # The image_url need not be proper since we have mocked
    # ProfilePicture#get_remote_image_data
    assert_difference 'ProfilePicture.count' do
      @profile_pic = ProfilePicture.create(
        :member => member,
        :image_url => 'some_url')
    end

    assert_equal @profile_pic, member.reload.profile_picture
    assert_equal 'pic_2.png', @profile_pic.image_file_name
  end

  def test_picture_update_with_url_failure
    user = users(:f_mentor)
    assert_nil user.member.profile_picture

    assert_nothing_raised do
      assert_no_difference 'ProfilePicture.count' do
        @profile_pic = ProfilePicture.create(
          :member => user.member,
          :image_url => 'some_url')
      end
    end

    assert_equal ["Unable to get the image from the url. Please check the url again."], @profile_pic.errors[:base]
  end

  def test_clear_remote_url_when_updated_with_data
    users(:f_mentor).member.build_profile_picture

    url = 'https://chronus-mentor-assets.s3.amazonaws.com/v2/images/body-bg.jpg'
    # The picture's origin is from a remote url.
    @profile_pic = users(:f_mentor).member.profile_picture
    @profile_pic.image_url = url
    @profile_pic.save!
    @profile_pic.reload

    assert_equal url, @profile_pic.image_remote_url
    assert_nothing_raised do
      assert_no_difference 'ProfilePicture.count' do
        @profile_pic.image = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
        @profile_pic.save!
      end
    end

#    # remote url should have been cleared. Rails3
#    @profile_pic.reload
#    assert_nil @profile_pic.image_remote_url
#    assert_equal 'pic_2.png', @profile_pic.image_file_name
  end

  def test_cropping_false_when_blank
    member = members(:f_mentor)
    assert_nil member.profile_picture

    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    assert !profile_picture.cropping?
  end

  def test_cropping_false_when_some_blank_or_when_crop_w_or_crop_h_is_zero
    member = members(:f_mentor)
    assert_nil member.profile_picture

    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'), :crop_w => 10, :crop_h => 10, :rotate => 0)
    assert !profile_picture.cropping?
    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'), :crop_x => 10, :crop_y => 10, :crop_w => 0, :crop_h => 0, :rotate => 0)
    assert_false profile_picture.cropping?
    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'), :crop_x => 10, :crop_y => 10, :crop_w => 10, :crop_h => 10)
    assert_false profile_picture.cropping?
  end

  def test_cropping_true_when_not_blank
    member = members(:f_mentor)
    assert_nil member.profile_picture

    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'), :crop_x => 0, :crop_y => 0, :crop_w => 10, :crop_h => 10, :rotate => 0)
    assert profile_picture.cropping?
  end

  def test_geometry
    member = members(:f_mentor)
    assert_nil member.profile_picture

    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    assert_equal "200x200", profile_picture.image_geometry(:original).inspect
    assert_equal "75x75", profile_picture.image_geometry(:large).inspect
  end

  def test_geometry_horizontal
    member = members(:f_mentor)
    assert_nil member.profile_picture
    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_horizontal.jpg'), 'image/jpg'), :crop_x => 0, :crop_y => 0, :crop_w => 750, :crop_h => 500)
    assert_equal "75x75", profile_picture.image_geometry(:large).inspect
    assert_equal "35x35", profile_picture.image_geometry(:small).inspect
    assert_equal "50x50", profile_picture.image_geometry(:medium).inspect
    assert_equal "150x150", profile_picture.image_geometry(:retina).inspect
  end

  def test_geometry_vertical
    member = members(:f_mentor)
    assert_nil member.profile_picture
    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_vertical.jpg'), 'image/jpg'), :crop_x => 0, :crop_y => 0, :crop_w => 600, :crop_h => 746)
    assert_equal "75x75", profile_picture.image_geometry(:large).inspect
    assert_equal "35x35", profile_picture.image_geometry(:small).inspect
    assert_equal "50x50", profile_picture.image_geometry(:medium).inspect
    assert_equal "150x150", profile_picture.image_geometry(:retina).inspect
  end

  def test_reprocess_image
    member = members(:f_mentor)
    assert_nil member.profile_picture
    profile_picture = nil
    t1 = Time.new(2000)
    Timecop.freeze(t1) { profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')) }
    assert profile_picture.image.url(:small).match(/.*small.*#{t1.to_i}/)
    assert profile_picture.image.url(:medium).match(/.*medium.*#{t1.to_i}/)
    assert profile_picture.image.url(:large).match(/.*large.*#{t1.to_i}/)
    assert profile_picture.image.url(:retina).match(/.*retina.*#{t1.to_i}/)
    t2 = Time.new(2010)
    Timecop.freeze(t2) { profile_picture.reprocess_image }
    assert profile_picture.image.url(:small).match(/.*small.*#{t2.to_i}/)
    assert profile_picture.image.url(:medium).match(/.*medium.*#{t2.to_i}/)
    assert profile_picture.image.url(:large).match(/.*large.*#{t2.to_i}/)
    assert profile_picture.image.url(:retina).match(/.*retina.*#{t2.to_i}/)
    profile_picture.update_attributes({:crop_x => 0, :crop_y => 0, :crop_w => 10, :crop_h => 10})
  end

  def test_get_width
    member = members(:f_mentor)
    assert_nil member.profile_picture
    ProfilePicture.expects(:es_reindex).once
    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    assert_equal 200, profile_picture.get_width
  end

  def test_es_reindex
    member = members(:f_mentor)
    assert_nil member.profile_picture

    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))

    ProfilePicture.expects(:es_reindex).twice
    profile_picture.image_file_name = "test_pic_updated.png"
    profile_picture.save!

    profile_picture.destroy
  end

#  def test_thumbnail_orientation
#    member = members(:f_mentor)
#    assert_nil member.profile_picture
#    original_file = File.join('files', 'test_iphone_pic.jpg')
#    fixture_large_thumbnail = File.join(self.class.fixture_path, 'files', 'test_iphone_pic_large_thumbnail.jpg')
#    profile_picture = ProfilePicture.create(:member => member, :image => fixture_file_upload(original_file, 'image/jpeg'))
#    def orientataion(image_path)
#      EXIFR::JPEG.new(image_path).exif.fields[:orientation]
#    end
#    assert orientataion(fixture_large_thumbnail) == orientataion(profile_picture.image.path(:large))
#  end
end
