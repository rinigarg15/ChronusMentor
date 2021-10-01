class ThemeVarListExtractorService

  include ChronusThemeParser

  def initialize(theme)
    @theme = theme
  end

  def get_vars_list
    self.parser = CssParser::Parser.new
    self.parser.load_uri!(css_file_path)
    self.parse_values
    self.config_values.to_yaml.gsub(/--- \n/, "")
  end

  def css_file_path
    @theme.temp_path.present? ? @theme.temp_path : @theme.css.url
  end
end