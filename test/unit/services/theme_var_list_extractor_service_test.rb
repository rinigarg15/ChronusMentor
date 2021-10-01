require_relative './../../test_helper.rb'

class ThemeVarListExtractorServiceTest < ActiveSupport::TestCase

  def test_css_file_path
    theme = Theme.first
    service_object_1 = ThemeVarListExtractorService.new(theme)
    assert_equal service_object_1.instance_variable_get("@theme"), theme
    assert_equal service_object_1.css_file_path, theme.css.url

    theme.temp_path = "test_temp_path"
    service_object_2 = ThemeVarListExtractorService.new(theme)
    assert_equal service_object_2.instance_variable_get("@theme"), theme
    assert_equal service_object_2.css_file_path, theme.temp_path
  end

  def test_get_vars_list
    theme = create_theme
    original_vars_list = theme.vars_list
    service_object = ThemeVarListExtractorService.new(theme)
    assert_equal service_object.get_vars_list, original_vars_list
  end
end