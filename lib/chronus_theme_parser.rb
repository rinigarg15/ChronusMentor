module ChronusThemeParser
  extend ActiveSupport::Concern

  included do
    attr_accessor :parser, :config_values
  end

  def get_property(css_properties, property)
    css_properties.each do |css|
      css = css.split("\;")
      css.each do |prop|
        prop = prop.strip
        prop_name = prop.split(':')[0]
        prop_value = prop.split(':')[1..-1].join(':')
        return prop_value.strip if(prop_name == property)
      end
    end
    return nil
  end

  def parse_values
    self.config_values ||= {}
    self.parse_button_colors
    self.parse_header_colors
  end

  def parse_button_colors
    css = self.parser.find_by_selector(".theme-btn-bg")
    value = self.get_property(css, 'background-color')
    self.config_values['$button-bg-color'] = value

    css = self.parser.find_by_selector(".theme-btn-font-color") 
    value = self.get_property(css, 'color')
    self.config_values['$button-font-color'] = value
  end

  def parse_header_colors
    css = self.parser.find_by_selector(".theme-bg")
    value = self.get_property(css, 'background-color')
    self.config_values['$header-bg-color'] = value

    css = self.parser.find_by_selector(".theme-font-color")
    value = self.get_property(css, 'color')
    self.config_values['$header-font-color'] = value
  end

end