require_relative './../test_helper.rb'

class ContactAdminSettingTest < ActiveSupport::TestCase

  def test_validate_uniqueness_of_program
    assert_difference "ContactAdminSetting.count", 1 do
      ContactAdminSetting.create!(program: programs(:albers), content: "Hello")
    end

    assert programs(:albers).reload.contact_admin_setting.present?
    assert_no_difference "ContactAdminSetting.count" do
      c = ContactAdminSetting.create(program: programs(:albers), content: "Hello")
      assert_false c.valid?
      assert_equal ["has already been taken"], c.errors[:program_id]
    end
  end

  def test_globalized_columns
    contact_admin_setting = ContactAdminSetting.create!(program: programs(:albers), label_name: "label_en", contact_url: "url_en", content: "content_en")
    Globalize.with_locale(:"fr-CA") do
      contact_admin_setting.label_name = "label_fr"
      contact_admin_setting.contact_url = "url_fr"
      contact_admin_setting.content = "content_fr"
      contact_admin_setting.save!
    end
    Globalize.with_locale(:"en") do
      assert_equal "label_en", contact_admin_setting.label_name
      assert_equal "content_en", contact_admin_setting.content
      assert_equal "url_fr", contact_admin_setting.contact_url
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "label_fr", contact_admin_setting.label_name
      assert_equal "content_fr", contact_admin_setting.content
      assert_equal "url_fr", contact_admin_setting.contact_url
    end
  end

  def test_check_new_places_used_contact_admin_url
    # contact_admin_url should not be used directly in code and get_contact_admin_path must be used.
    actual_content = `grep -R "contact_admin_url(" #{Rails.root}/app #{Rails.root}/lib #{Rails.root}/vendor | sort | sed 's/#{Rails.root.to_s.gsub('/', '\/')}/ /'`
    expected_content = "/app/helpers/application_helper.rb:    contact_url = (contact_admin_setting && contact_admin_setting.contact_url.presence) || contact_admin_url(options[:url_params])"
    assert_equal expected_content, actual_content.strip
  end

end
