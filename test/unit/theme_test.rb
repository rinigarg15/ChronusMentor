require_relative './../test_helper.rb'

class ThemeTest < ActiveSupport::TestCase

  #To test that css and name are required fields
  def test_css_file_and_name_are_required
    assert_multiple_errors([{:field => :css}, {:field => :name}]) do
      theme = Theme.new({:program => programs(:org_primary)})
      theme.temp_path = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css').path
      theme.save!
    end
  end

  #To test the creation of a row in themes table
  def test_create_success
    assert_difference 'Theme.count' do
      @ss = create_theme()
    end
    assert @ss.css?
    assert_equal 'test_file.css', @ss.css_file_name
  end

  #To test the creation of default theme
  def test_should_create_default_theme_without_css
    Theme.delete_all
    assert_difference 'Theme.count' do
      Theme.create!(name: Theme::DEFAULT)
    end
  end

  #To test the creation of global theme
  def test_should_create_global_theme
    css_file = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
    assert_difference 'Theme.count' do
      theme = Theme.new(:name => 'test_theme', :css => css_file )
      theme.temp_path = css_file.path
      theme.save!
    end
    assert Theme.global.include?(Theme.last)
  end

  #To test the creation of a theme specific to program
  def test_should_create_theme
    assert_difference 'Theme.count' do
      create_theme()
    end
    assert  programs(:org_primary).themes.include?(Theme.last)
  end

  # To test the validation on the content type
  def test_create_failure_due_to_bad_content_type
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :css do
      create_theme({:css => fixture_file_upload(
            File.join('files',  'test_pic.png'), 'image/png')})
    end
  end

  # To test that no other theme can be created with css null except the theme with name default
  def test_css_is_null_only_for_default_theme
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :css do
      theme = Theme.new(:name => 'theme')
      theme.temp_path = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css').path
      theme.save!
    end
  end

  def test_is_global
    ss_private = create_theme(:name => "Private Theme")
    ss_global = create_theme(:program=>nil)
    assert !ss_private.is_global?
    assert ss_global.is_global?
  end

  def test_available_themes
    assert_equal_unordered [themes(:themes_1), themes(:wcag_theme)], Theme.available_themes(programs(:org_primary))
    assert_equal_unordered [themes(:themes_1), themes(:wcag_theme)], Theme.available_themes(programs(:albers))

    ss_private = create_theme()
    ss_global = create_theme(:program => nil, name: "Global Theme")

    assert_equal_unordered [themes(:themes_1), themes(:wcag_theme), ss_global, ss_private], Theme.available_themes(programs(:org_primary))
    assert_equal_unordered [themes(:themes_1), themes(:wcag_theme), ss_global, ss_private], Theme.available_themes(programs(:albers))

    ss_prog_private = create_theme(:program => programs(:albers))
    assert_equal_unordered [themes(:themes_1), themes(:wcag_theme), ss_global, ss_private], Theme.available_themes(programs(:org_primary))
    assert_equal_unordered [themes(:themes_1), themes(:wcag_theme), ss_global, ss_private, ss_prog_private], Theme.available_themes(programs(:albers))
  end

  def test_validate_theme_var_list
    theme = Theme.new
    invalid_vars_list = "---\nbody-bg: ! '#ffffff'\n"
    ThemeVarListExtractorService.any_instance.stubs(:get_vars_list).returns(invalid_vars_list)
    theme.set_vars_list
    assert_false theme.valid?
  end

  def test_has_vars_list
    t = themes(:wcag_theme)
    assert_false t.has_vars_list?
  end

  def test_vars
    t = themes(:wcag_theme)
    assert t.vars.empty?

    t2 = create_theme()
    assert t2.vars.is_a?(Hash)
    assert_false t2.vars.empty?
  end

  def test_uniqueness_validation_for_name
    theme = themes(:wcag_theme)
    assert theme.valid?
    theme = Theme.new(name: "Default")
    assert_false theme.valid?
    expected_hash = {:name => ["has already been taken"]}
    assert_equal expected_hash, theme.errors.messages

    # no uniqueness validation for private themes
    theme = Theme.new(name: "Default", program_id: programs(:albers).id)
    assert theme.valid?
  end
end

