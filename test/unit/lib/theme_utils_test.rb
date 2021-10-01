require_relative './../../test_helper.rb'

class ThemeUtilsTest < ActiveSupport::TestCase

  def test_generate_scss_variables_file
    begin
      theme_colors_map = JSON.parse(File.read("#{Rails.root}/test/fixtures/files/wcag_theme_variables.json"))
      scss_variables_file_path = ThemeUtils.generate_scss_variables_file(theme_colors_map)
      scss_variables = File.read(scss_variables_file_path)

      theme_colors_map.each_with_index do |element_with_color, index|
        assert_equal "$#{element_with_color[0]}: #{element_with_color[1]};\n", scss_variables.lines[index]
      end
      assert_equal "@include v5-theme-color;\n", scss_variables.lines.last
    ensure
      File.delete(scss_variables_file_path) if File.exist?(scss_variables_file_path)
    end
  end

  def test_generate_wcag_theme
    begin
      theme_colors_map = JSON.parse(File.read("#{Rails.root}/test/fixtures/files/wcag_theme_variables.json"))
      theme_file = ThemeUtils.generate_theme(theme_colors_map, true)
      assert_equal themes(:wcag_theme).css.content, File.read(theme_file)
    ensure
      File.delete(theme_file) if File.exist?(theme_file)
    end
  end

  def test_generate_non_wcag_theme
    begin
      theme_colors_map = JSON.parse(File.read("#{Rails.root}/test/fixtures/files/non_wcag_theme_variables.json"))
      theme_file = ThemeUtils.generate_theme(theme_colors_map)
      assert_equal themes(:themes_1).css.content, File.read(theme_file)
    ensure
      File.delete(theme_file) if File.exist?(theme_file)
    end
  end

end