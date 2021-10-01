require_relative './../test_helper.rb'

class ProgramAssetTest < ActiveSupport::TestCase

  def test_create_update_success
    program = programs(:albers)
    assert_difference 'ProgramAsset.count' do
      assert_nothing_raised do
        program.create_program_asset
      end
    end
    program_asset = program.program_asset
    assert_equal program_asset.program_id, program.id
    assert_false program.does_logo_exist?
    assert_false program.does_banner_exist?

    program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program_asset.save!
    program.reload
    assert program.does_logo_exist?
    assert_false program.does_banner_exist?
  end

  def test_logo_url
    program = programs(:albers)
    organization = program.organization
    organization_asset = organization.create_program_asset
    assert_false organization.does_logo_exist?
    assert_false program.does_logo_exist?

    organization_asset.logo = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    organization_asset.save!
    assert organization.does_logo_exist?
    assert_false program.does_logo_exist?
    assert_match "pic_2.png", organization.logo_url

    program_asset = program.create_program_asset
    program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program_asset.save!
    assert program.does_logo_exist?
    assert "test_pic.png", program.logo_url
  end

  def test_logo_url_with_fallback
    program = programs(:albers)
    organization = program.organization
    organization_asset = organization.create_program_asset
    organization_asset.logo = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    organization_asset.save!
    assert_nil program.logo_url
    assert_match "pic_2.png", program.logo_url_with_fallback
  end

  def test_banner_url
    program = programs(:albers)
    organization = program.organization
    organization_asset = organization.create_program_asset
    assert_false organization.does_banner_exist?
    assert_false program.does_banner_exist?

    organization_asset.banner = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    organization_asset.save!
    assert organization.does_banner_exist?
    assert_false program.does_banner_exist?
    assert_match "pic_2.png", organization.banner_url

    program_asset = program.create_program_asset
    program_asset.banner = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program_asset.save!
    assert program.does_banner_exist?
    assert "test_pic.png", program.banner_url
  end

  def test_logo_or_banner_url
    program = programs(:albers)
    organization = program.organization
    program.create_program_asset
    organization_asset = organization.create_program_asset
    organization_asset.banner = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    organization_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    organization_asset.save!

    assert_match "test_pic.png", organization.logo_or_banner_url
    assert_match "test_pic.png", program.logo_or_banner_url
    assert_match "pic_2.png", organization.logo_or_banner_url([:banner, :logo], false)
    assert_match "pic_2.png", program.logo_or_banner_url([:banner, :logo])

    # With type
    content = organization.logo_or_banner_url([:logo, :banner], true)
    assert_match "test_pic.png", content[0]
    assert_equal :logo, content[1]
    content = program.logo_or_banner_url([:banner, :logo], true)
    assert_match "pic_2.png", content[0]
    assert_equal :banner, content[1]
  end

  def test_logo_or_banner_url_with_program_level_assets
    program = programs(:albers)
    organization = program.organization
    program_asset = program.create_program_asset
    organization_asset = organization.create_program_asset
    program_asset.banner = fixture_file_upload(File.join('files', 'test_horizontal.jpg'), 'image/jpeg')
    program_asset.logo = fixture_file_upload(File.join('files', 'test_vertical.jpg'), 'image/jpeg')
    program_asset.save!
    organization_asset.banner = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    organization_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    organization_asset.save!

    assert_match "test_pic.png", organization.logo_or_banner_url
    assert_match "test_pic.png", organization.logo_or_banner_url([:logo, :banner])
    assert_match "pic_2.png", organization.logo_or_banner_url([:banner, :logo])
    assert_match "test_vertical.jpg", program.logo_or_banner_url
    assert_match "test_horizontal.jpg", program.logo_or_banner_url([:banner, :logo])
  end

  def test_can_render_mobile_logo_mobile_logo_url
    org = programs(:org_primary)
    program = programs(:albers)
    # Mobile logo not present at all
    org_pa = org.create_program_asset
    assert_false org.banner.exists?
    assert_nil program.program_asset
    assert_false org.can_render_mobile_logo?
    assert_false program.can_render_mobile_logo?
    assert_nil org.mobile_logo_url
    assert_nil program.mobile_logo_url

    # Mobile logo present at org
    org_pa.mobile_logo = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
    org_pa.save!
    program_asset = program.create_program_asset
    assert org.mobile_logo.exists?
    assert_false program.mobile_logo.exists?
    assert org.can_render_mobile_logo?
    assert program.reload.can_render_mobile_logo?
    assert_match /pic_2\.png/, org.mobile_logo_url
    assert_match /pic_2\.png/, program.mobile_logo_url

    # Mobile logo present at prog and org
    program_asset.mobile_logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program_asset.save!
    assert org.mobile_logo.exists?
    assert program.reload.mobile_logo.exists?
    assert org.can_render_mobile_logo?
    assert program.can_render_mobile_logo?
    assert_match /pic_2\.png/, org.mobile_logo_url
    assert_match /test_pic\.png/, program.mobile_logo_url

    # Mobile logo present at prog but not at org
    org_pa.mobile_logo = nil
    org_pa.save!
    assert_false org.mobile_logo.exists?
    assert program.mobile_logo.exists?
    assert_false org.can_render_mobile_logo?
    assert program.can_render_mobile_logo?
    assert_nil org.mobile_logo_url
    assert_match /test_pic\.png/, program.mobile_logo_url
  end

  def test_translatable_fields
    name_attributes = ["logo_file_name", "banner_file_name"]
    type_attributes = ["logo_content_type", "banner_content_type"]
    size_attributes = ["logo_file_size", "banner_file_size"]
    program = programs(:albers)
    program.create_program_asset
    program_asset = program.program_asset

    Globalize.with_locale(:en) do
      name_attributes.each do |attribute|
        program_asset.send(attribute+"=", "english")
      end
      type_attributes.each do |attribute|
        program_asset.send(attribute+"=", "image/jpg")
      end
      size_attributes.each do |attribute|
        program_asset.send(attribute+"=", 100)
      end
      program_asset.save!
    end

    Globalize.with_locale(:en) do
      name_attributes.each do |attribute|
        assert_equal "english", program_asset.send(attribute)
      end
      type_attributes.each do |attribute|
        assert_equal "image/jpg", program_asset.send(attribute)
      end
      size_attributes.each do |attribute|
        assert_equal 100, program_asset.send(attribute)
      end
    end

    Globalize.with_locale("fr-CA") do
      name_attributes.each do |attribute|
        program_asset.send(attribute+"=", "french")
      end
      type_attributes.each do |attribute|
        program_asset.send(attribute+"=", "image/jpeg")
      end
      size_attributes.each do |attribute|
        program_asset.send(attribute+"=", 200)
      end
      program_asset.save!
    end

    Globalize.with_locale("fr-CA") do
      name_attributes.each do |attribute|
        assert_equal "french", program_asset.send(attribute)
      end
      type_attributes.each do |attribute|
        assert_equal "image/jpeg", program_asset.send(attribute)
      end
      size_attributes.each do |attribute|
        assert_equal 200, program_asset.send(attribute)
      end
    end
  end

  def test_after_save_callbacks_logo
    program = programs(:albers)
    run_in_another_locale("fr-CA") do
      ProgramAsset.create!(program_id: program.id, logo: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    end
    french_path = I18n.with_locale("fr-CA") do
      program.logo.path
    end
    english_path = program.logo.path
    assert_not_equal french_path, english_path
    assert File.exist?(english_path)
    assert File.exist?(french_path)
  end

  def test_after_save_callbacks_banner
    program = programs(:albers)
    run_in_another_locale("fr-CA") do
      ProgramAsset.create!(program_id: program.id, banner: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    end
    french_path = I18n.with_locale("fr-CA") do
      program.banner.path
    end
    english_path = program.banner.path
    assert_not_equal french_path, english_path
    assert File.exist?(english_path)
    assert File.exist?(french_path)
  end
end